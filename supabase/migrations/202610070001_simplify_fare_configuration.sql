-- Simplify the active fare flow while preserving legacy financial columns.
-- Existing rides keep their stored fare. Only new fare calculations use this
-- formula:
--   base fare + max(0, distance - included distance) * per-km rate
-- followed by the established nearest-5-pesos rounding and minimum fare.

ALTER TABLE public.fare_matrix
  ADD COLUMN IF NOT EXISTS included_base_distance numeric(10,2)
    NOT NULL DEFAULT 1.00
    CHECK (included_base_distance >= 0);

-- Keep the old column for future payment integration, but make new rows
-- neutral while the platform-fee system is disabled.
ALTER TABLE public.fare_matrix
  ALTER COLUMN commission_percent SET DEFAULT 0;

UPDATE public.fare_matrix
SET commission_percent = 0
WHERE commission_percent <> 0;

-- The explicit snapshot keeps the fare inputs that determined a new ride
-- without making legacy financial columns part of the active calculation.
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
  WHERE vehicle_type = requested_vehicle::text
    AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'fare matrix missing for vehicle type'; END IF;

  calculated_fare := GREATEST(
    config.minimum_fare,
    ROUND((
      config.base_fare
      + config.per_km_rate * GREATEST(distance_km - config.included_base_distance, 0)
    ) / 5) * 5
  );

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
    distance_km, duration_minutes, calculated_fare, 0,
    calculated_fare, payment_method, 'searching',
    jsonb_build_object(
      'vehicle_type', config.vehicle_type,
      'base_fare', config.base_fare,
      'included_base_distance', config.included_base_distance,
      'per_km_rate', config.per_km_rate,
      'minimum_fare', config.minimum_fare,
      'rounding_rule', 'nearest_5_pesos'
    )
  ) RETURNING * INTO result;

  RETURN result;
END;
$$;

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
  WHERE vehicle_type = requested_vehicle::text
    AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'fare matrix missing for vehicle type'; END IF;

  calculated_fare := GREATEST(
    config.minimum_fare,
    ROUND((
      config.base_fare
      + config.per_km_rate * GREATEST(distance_km - config.included_base_distance, 0)
    ) / 5) * 5
  );

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
    distance_km, duration_minutes, calculated_fare, 0,
    calculated_fare, payment_method, 'searching',
    jsonb_build_object(
      'vehicle_type', config.vehicle_type,
      'base_fare', config.base_fare,
      'included_base_distance', config.included_base_distance,
      'per_km_rate', config.per_km_rate,
      'minimum_fare', config.minimum_fare,
      'rounding_rule', 'nearest_5_pesos'
    )
  ) RETURNING * INTO result;

  RETURN result;
END;
$$;

-- Keep the payment settlement signature available for future providers, but
-- settle a driver's earning at the full stored payment amount for now.
CREATE OR REPLACE FUNCTION public.settle_ride_payment(
  payment_id text,
  ride_id text,
  provider_reference text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_payment public.payments%rowtype;
BEGIN
  IF auth.role() <> 'service_role' AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'trusted server or admin authorization required';
  END IF;

  SELECT * INTO current_payment
  FROM public.payments p
  WHERE p.id = payment_id
    AND p.ride_id = settle_ride_payment.ride_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN false; END IF;
  IF current_payment.status = 'paid' THEN RETURN true; END IF;

  UPDATE public.payments
  SET status = 'paid', paid_at = now(), provider_reference = settle_ride_payment.provider_reference
  WHERE id = payment_id;

  UPDATE public.rides SET payment_status = 'paid' WHERE id = ride_id;

  IF current_payment.driver_id IS NOT NULL THEN
    INSERT INTO public.driver_earnings (
      id, driver_id, ride_id, gross_amount, commission, net_amount
    ) VALUES (
      'earn_' || ride_id,
      current_payment.driver_id,
      ride_id,
      current_payment.amount,
      0,
      current_payment.amount
    )
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.drivers
    SET lifetime_earnings = lifetime_earnings + current_payment.amount
    WHERE user_id = current_payment.driver_id;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text, double precision,
  double precision, text, text, double precision, double precision, text,
  numeric, integer, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text, double precision,
  double precision, text, text, double precision, double precision, text,
  numeric, integer, text
) TO authenticated;

REVOKE ALL ON FUNCTION public.request_ride(
  uuid, public.vehicle_type, text, text, text, double precision,
  double precision, text, text, double precision, double precision, text,
  numeric, integer, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_ride(
  uuid, public.vehicle_type, text, text, text, double precision,
  double precision, text, text, double precision, double precision, text,
  numeric, integer, text
) TO authenticated;

REVOKE ALL ON FUNCTION public.settle_ride_payment(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_ride_payment(text, text, text)
  TO authenticated, service_role;
