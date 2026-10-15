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
  config public.fare_config%rowtype;
  calculated_fare numeric;
  platform_commission numeric;
  result public.rides%rowtype;
  locked_driver_id uuid;
BEGIN
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if distance_km < 0 or duration_minutes < 0 then raise exception 'invalid route metrics'; end if;
  if pickup_latitude not between -90 and 90 or destination_latitude not between -90 and 90
    or pickup_longitude not between -180 and 180 or destination_longitude not between -180 and 180 then
    raise exception 'invalid coordinates';
  end if;
  if payment_method not in ('cash', 'gcash', 'maya', 'card') then raise exception 'unsupported payment method'; end if;
  
  if exists (
    select 1 from public.rides r where r.passenger_id = auth.uid()
    and r.status in ('searching', 'accepted', 'arrived', 'started')
  ) then raise exception 'passenger already has an active ride'; end if;

  select * into config from public.fare_config where vehicle_type = requested_vehicle;
  if not found then raise exception 'fare configuration missing'; end if;
  
  calculated_fare := greatest(config.base_fare,
    round((config.base_fare + config.per_km_rate * greatest(distance_km - config.base_km, 0)) / 5) * 5);
  platform_commission := round(calculated_fare * config.commission_percent / 100, 2);

  -- ATOMIC BACKEND VALIDATION & RESERVATION
  if requested_driver is not null then
    -- Lock the driver row to prevent double-booking race conditions
    SELECT user_id INTO locked_driver_id
    FROM public.drivers
    WHERE user_id = requested_driver
      AND vehicle_type = requested_vehicle
      AND is_online = true
      AND is_available = true
      AND application_status IN ('approved', 'active')
    FOR UPDATE SKIP LOCKED;

    IF locked_driver_id IS NULL THEN
      RAISE EXCEPTION 'Driver is no longer online or available. Please choose another driver.';
    END IF;

    -- Update driver to unavailable immediately
    UPDATE public.drivers
    SET is_available = false
    WHERE user_id = locked_driver_id;
  end if;

  insert into public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status
  ) values (
    client_ride_id, auth.uid(), requested_driver, passenger_name, passenger_phone, requested_vehicle,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, calculated_fare, platform_commission, calculated_fare - platform_commission,
    payment_method, 'searching'
  ) returning * into result;

  return result;
END;
$$;
