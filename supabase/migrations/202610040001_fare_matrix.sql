-- 1. Create fare_matrix table
CREATE TABLE public.fare_matrix (
    id uuid primary key default gen_random_uuid(),
    vehicle_type text not null unique,
    base_fare numeric(10,2) not null check (base_fare >= 0),
    per_km_rate numeric(10,2) not null check (per_km_rate >= 0),
    per_minute_rate numeric(10,2) not null default 0 check (per_minute_rate >= 0),
    minimum_fare numeric(10,2) not null check (minimum_fare >= 0),
    booking_fee numeric(10,2) not null default 0 check (booking_fee >= 0),
    surge_multiplier numeric(4,2) not null default 1.00 check (surge_multiplier >= 1),
    commission_percent numeric(5,2) not null default 12 check (commission_percent between 0 and 100),
    is_active boolean not null default true,
    updated_at timestamptz not null default now(),
    updated_by uuid references auth.users(id)
);

-- 2. Create fare_matrix_history table (audit log)
CREATE TABLE public.fare_matrix_history (
    id uuid primary key default gen_random_uuid(),
    vehicle_type text not null,
    old_values jsonb,
    new_values jsonb,
    changed_by uuid references auth.users(id),
    changed_at timestamptz default now()
);

-- 3. Trigger to auto-set updated_at and updated_by
CREATE OR REPLACE FUNCTION public.handle_fare_matrix_update()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    IF auth.uid() IS NOT NULL THEN
        NEW.updated_by = auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_fare_matrix_update_trigger
    BEFORE UPDATE ON public.fare_matrix
    FOR EACH ROW EXECUTE FUNCTION public.handle_fare_matrix_update();

-- 4. Trigger to populate fare_matrix_history
CREATE OR REPLACE FUNCTION public.log_fare_matrix_history()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.fare_matrix_history (vehicle_type, old_values, new_values, changed_by)
    VALUES (
        NEW.vehicle_type,
        to_jsonb(OLD),
        to_jsonb(NEW),
        auth.uid()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_fare_matrix_history_trigger
    AFTER UPDATE ON public.fare_matrix
    FOR EACH ROW EXECUTE FUNCTION public.log_fare_matrix_history();

-- 5. Seed default rows
INSERT INTO public.fare_matrix (vehicle_type, base_fare, per_km_rate, per_minute_rate, minimum_fare, booking_fee, surge_multiplier, commission_percent)
VALUES
    ('tricycle', 15.00, 5.00, 0.00, 15.00, 0.00, 1.00, 12.00),
    ('habal', 20.00, 8.00, 0.00, 20.00, 0.00, 1.00, 12.00)
ON CONFLICT (vehicle_type) DO NOTHING;

-- 6. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.fare_matrix;

-- 7. Add fare_locked to rides table
ALTER TABLE public.rides ADD COLUMN fare_locked jsonb;

-- 8. Enable RLS
ALTER TABLE public.fare_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fare_matrix_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fare_matrix_select_all" ON public.fare_matrix
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "fare_matrix_insert_admin" ON public.fare_matrix
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "fare_matrix_update_admin" ON public.fare_matrix
    FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "fare_matrix_delete_admin" ON public.fare_matrix
    FOR DELETE TO authenticated USING (public.is_admin());

CREATE POLICY "fare_matrix_history_select_admin" ON public.fare_matrix_history
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "fare_matrix_history_insert_admin" ON public.fare_matrix_history
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

-- 9. Update request_ride_with_id to use fare_matrix
CREATE OR REPLACE FUNCTION public.request_ride_with_id(
  client_ride_id text,
  requested_driver uuid,
  requested_vehicle public.vehicle_type,
  passenger_name text,
  passenger_phone text,
  pickup_address text,
  pickup_latitude double precision,
  pickup_longitude double precision,
  pickup_province text,
  destination_address text,
  destination_latitude double precision,
  destination_longitude double precision,
  destination_province text,
  distance_km numeric,
  duration_minutes integer,
  payment_method text default 'cash'
)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  config public.fare_matrix%rowtype;
  calculated_fare numeric;
  platform_commission numeric;
  result public.rides%rowtype;
  locked_driver_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF distance_km < 0 OR duration_minutes < 0 THEN RAISE EXCEPTION 'invalid route metrics'; END IF;
  IF pickup_latitude NOT BETWEEN -90 AND 90 OR destination_latitude NOT BETWEEN -90 AND 90
    OR pickup_longitude NOT BETWEEN -180 AND 180 OR destination_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid coordinates';
  END IF;
  IF payment_method NOT IN ('cash', 'gcash', 'maya', 'card') THEN
    RAISE EXCEPTION 'unsupported payment method';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.rides r
    WHERE r.passenger_id = auth.uid()
      AND r.status IN ('searching', 'accepted', 'arrived', 'started')
  ) THEN
    RAISE EXCEPTION 'passenger already has an active ride';
  END IF;

  SELECT * INTO config
  FROM public.fare_matrix
  WHERE vehicle_type = requested_vehicle::text;
  IF NOT FOUND THEN RAISE EXCEPTION 'fare matrix missing for vehicle type'; END IF;

  calculated_fare := GREATEST(
    config.minimum_fare,
    (config.base_fare + distance_km * config.per_km_rate + duration_minutes * config.per_minute_rate) * config.surge_multiplier
  ) + config.booking_fee;
  
  -- Round to nearest 2 decimals
  calculated_fare := ROUND(calculated_fare, 2);
  
  platform_commission := ROUND(calculated_fare * config.commission_percent / 100, 2);

  IF requested_driver IS NOT NULL THEN
    SELECT d.user_id INTO locked_driver_id
    FROM public.drivers d
    WHERE d.user_id = requested_driver
      AND d.vehicle_type = requested_vehicle
      AND d.is_online
      AND d.is_available
      AND d.application_status IN ('approved', 'active')
    FOR UPDATE;

    IF locked_driver_id IS NULL THEN
      RAISE EXCEPTION 'Driver is no longer online or available. Please choose another driver.';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.rides r
      WHERE r.driver_id = requested_driver
        AND r.status IN ('searching', 'accepted', 'arrived', 'started')
    ) THEN
      RAISE EXCEPTION 'Driver already has an active ride. Please choose another driver.';
    END IF;
  END IF;

  INSERT INTO public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status, fare_locked
  ) VALUES (
    client_ride_id, auth.uid(), requested_driver, passenger_name, passenger_phone, requested_vehicle,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, calculated_fare, platform_commission,
    calculated_fare - platform_commission, payment_method, 'searching',
    to_jsonb(config)
  ) RETURNING * INTO result;

  RETURN result;
END;
$$;

-- 10. Update request_ride to use fare_matrix
CREATE OR REPLACE FUNCTION public.request_ride(
  requested_driver uuid,
  requested_vehicle public.vehicle_type,
  passenger_name text,
  passenger_phone text,
  pickup_address text,
  pickup_latitude double precision,
  pickup_longitude double precision,
  pickup_province text,
  destination_address text,
  destination_latitude double precision,
  destination_longitude double precision,
  destination_province text,
  distance_km numeric,
  duration_minutes integer,
  payment_method text default 'cash'
)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  config public.fare_matrix%rowtype;
  calculated_fare numeric;
  platform_commission numeric;
  result public.rides%rowtype;
  locked_driver_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF distance_km < 0 OR duration_minutes < 0 THEN RAISE EXCEPTION 'invalid route metrics'; END IF;
  IF pickup_latitude NOT BETWEEN -90 AND 90 OR destination_latitude NOT BETWEEN -90 AND 90
    OR pickup_longitude NOT BETWEEN -180 AND 180 OR destination_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid coordinates';
  END IF;
  IF payment_method NOT IN ('cash', 'gcash', 'maya', 'card') THEN
    RAISE EXCEPTION 'unsupported payment method';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.rides r
    WHERE r.passenger_id = auth.uid()
      AND r.status IN ('searching', 'accepted', 'arrived', 'started')
  ) THEN
    RAISE EXCEPTION 'passenger already has an active ride';
  END IF;

  SELECT * INTO config
  FROM public.fare_matrix
  WHERE vehicle_type = requested_vehicle::text;
  IF NOT FOUND THEN RAISE EXCEPTION 'fare matrix missing for vehicle type'; END IF;

  calculated_fare := GREATEST(
    config.minimum_fare,
    (config.base_fare + distance_km * config.per_km_rate + duration_minutes * config.per_minute_rate) * config.surge_multiplier
  ) + config.booking_fee;
  
  -- Round to nearest 2 decimals
  calculated_fare := ROUND(calculated_fare, 2);
  
  platform_commission := ROUND(calculated_fare * config.commission_percent / 100, 2);

  IF requested_driver IS NOT NULL THEN
    SELECT d.user_id INTO locked_driver_id
    FROM public.drivers d
    WHERE d.user_id = requested_driver
      AND d.vehicle_type = requested_vehicle
      AND d.is_online
      AND d.is_available
      AND d.application_status IN ('approved', 'active')
    FOR UPDATE;

    IF locked_driver_id IS NULL THEN
      RAISE EXCEPTION 'Driver is no longer online or available. Please choose another driver.';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.rides r
      WHERE r.driver_id = requested_driver
        AND r.status IN ('searching', 'accepted', 'arrived', 'started')
    ) THEN
      RAISE EXCEPTION 'Driver already has an active ride. Please choose another driver.';
    END IF;
  END IF;

  INSERT INTO public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status, fare_locked
  ) VALUES (
    gen_random_uuid()::text, auth.uid(), requested_driver, passenger_name, passenger_phone, requested_vehicle,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, calculated_fare, platform_commission,
    calculated_fare - platform_commission, payment_method, 'searching',
    to_jsonb(config)
  ) RETURNING * INTO result;

  RETURN result;
END;
$$;

-- 11. Drop old fare_config table (optional, but requested to clean up)
DROP TABLE IF EXISTS public.fare_config CASCADE;
