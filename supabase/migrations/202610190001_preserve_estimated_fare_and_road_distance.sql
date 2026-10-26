-- Preserve confirmed estimated fare and road distance in ride requests
-- Ensures whatever fare is confirmed by the passenger matches the ride record,
-- driver request offer, and 100% driver wallet earnings (0% commission).

DROP FUNCTION IF EXISTS public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text
);

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
  payment_method text DEFAULT 'cash',
  estimated_fare numeric DEFAULT NULL
)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
  p_client_ride_id text := client_ride_id;
  p_requested_driver uuid := requested_driver;
  p_requested_vehicle public.vehicle_type := requested_vehicle;
  p_passenger_name text := passenger_name;
  p_passenger_phone text := passenger_phone;
  p_pickup_address text := pickup_address;
  p_pickup_latitude double precision := pickup_latitude;
  p_pickup_longitude double precision := pickup_longitude;
  p_pickup_province text := pickup_province;
  p_destination_address text := destination_address;
  p_destination_latitude double precision := destination_latitude;
  p_destination_longitude double precision := destination_longitude;
  p_destination_province text := destination_province;
  p_distance_km numeric := distance_km;
  p_duration_minutes integer := duration_minutes;
  p_payment_method text := payment_method;
  p_estimated_fare numeric := estimated_fare;
  v_fare numeric;
  config public.fare_matrix%ROWTYPE;
  existing_ride public.rides%ROWTYPE;
  result public.rides%ROWTYPE;
  locked_driver_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF p_client_ride_id IS NULL OR pg_catalog.btrim(p_client_ride_id) = ''
     OR p_requested_vehicle IS NULL
     OR p_distance_km IS NULL OR p_distance_km < 0
     OR p_duration_minutes IS NULL OR p_duration_minutes < 0 THEN
    RAISE EXCEPTION 'invalid ride request';
  END IF;
  IF p_pickup_latitude NOT BETWEEN -90 AND 90
     OR p_destination_latitude NOT BETWEEN -90 AND 90
     OR p_pickup_longitude NOT BETWEEN -180 AND 180
     OR p_destination_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid coordinates';
  END IF;
  IF p_payment_method NOT IN ('cash', 'gcash', 'maya', 'card') THEN
    RAISE EXCEPTION 'unsupported payment method';
  END IF;

  PERFORM public.expire_unanswered_ride_requests();

  PERFORM 1
  FROM public.passenger_profiles AS pp
  WHERE pp.user_id = auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'passenger account required';
  END IF;

  SELECT r.* INTO existing_ride
  FROM public.rides AS r
  WHERE r.id = p_client_ride_id
  FOR UPDATE;
  IF FOUND THEN
    IF existing_ride.passenger_id = auth.uid()
       AND existing_ride.driver_id IS NOT DISTINCT FROM p_requested_driver
       AND existing_ride.vehicle_type = p_requested_vehicle
       AND existing_ride.status IN ('searching', 'accepted', 'arrived', 'started') THEN
      RETURN existing_ride;
    END IF;
    RAISE EXCEPTION 'ride request ID already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.rides AS r
    WHERE r.passenger_id = auth.uid()
      AND r.status IN ('searching', 'accepted', 'arrived', 'started')
  ) THEN
    RAISE EXCEPTION 'passenger already has an active ride';
  END IF;

  SELECT fm.* INTO config
  FROM public.fare_matrix AS fm
  WHERE fm.vehicle_type = p_requested_vehicle::text
    AND fm.is_active
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fare matrix missing for vehicle type';
  END IF;

  IF p_requested_driver IS NOT NULL THEN
    SELECT d.user_id INTO locked_driver_id
    FROM public.drivers AS d
    JOIN public.profiles AS p ON p.id = d.user_id
    JOIN public.driver_presence AS dp ON dp.driver_id = d.user_id
    WHERE d.user_id = p_requested_driver
      AND d.vehicle_type = p_requested_vehicle
      AND d.application_status IN ('approved', 'active')
      AND p.account_status IN ('approved', 'active')
      AND dp.vehicle_type = d.vehicle_type
      AND dp.latitude BETWEEN -90 AND 90
      AND dp.longitude BETWEEN -180 AND 180
      AND dp.last_location_at IS NOT NULL
      AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
      AND d.is_online
      AND public.driver_is_requestable(d.user_id)
      AND 6371.0 * 2 * pg_catalog.asin(pg_catalog.sqrt(LEAST(
        1.0,
        pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
          dp.latitude - p_pickup_latitude
        ) / 2), 2)
        + pg_catalog.cos(pg_catalog.radians(p_pickup_latitude))
          * pg_catalog.cos(pg_catalog.radians(dp.latitude))
          * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
              dp.longitude - p_pickup_longitude
            ) / 2), 2)
      ))) <= 15.0
    FOR UPDATE OF d, dp;

    IF locked_driver_id IS NULL THEN
      RAISE EXCEPTION 'Driver is no longer Online, approved, or has a saved location. Please choose another driver.';
    END IF;

    IF public.driver_has_conflicting_ride(p_requested_driver, NULL) THEN
      RAISE EXCEPTION 'Driver already has an active ride or reservation. Please choose another driver.';
    END IF;

    PERFORM public.recalculate_driver_availability(p_requested_driver, false);
  END IF;

  -- Determine authoritative fare: preserve confirmed estimated fare if valid,
  -- otherwise calculate from active fare matrix and provided road distance.
  IF p_estimated_fare IS NOT NULL AND p_estimated_fare > 0 THEN
    v_fare := pg_catalog.round(p_estimated_fare, 2);
  ELSE
    v_fare := GREATEST(
      config.minimum_fare,
      pg_catalog.round((
        config.base_fare
        + config.per_km_rate * GREATEST(
          p_distance_km - config.included_base_distance, 0
        )
      ) / 5) * 5
    );
  END IF;

  INSERT INTO public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status, fare_locked
  ) VALUES (
    p_client_ride_id, auth.uid(), p_requested_driver,
    COALESCE(p_passenger_name, ''), COALESCE(p_passenger_phone, ''),
    p_requested_vehicle,
    COALESCE(p_pickup_address, ''), p_pickup_latitude, p_pickup_longitude,
    p_pickup_province, COALESCE(p_destination_address, ''),
    p_destination_latitude, p_destination_longitude, p_destination_province,
    p_distance_km, p_duration_minutes,
    v_fare,
    0.00,
    v_fare,
    p_payment_method,
    'searching',
    pg_catalog.jsonb_build_object(
      'vehicle_type', config.vehicle_type,
      'base_fare', config.base_fare,
      'included_base_distance', config.included_base_distance,
      'per_km_rate', config.per_km_rate,
      'minimum_fare', config.minimum_fare,
      'confirmed_estimated_fare', v_fare,
      'rounding_rule', 'nearest_5_pesos'
    )
  ) RETURNING * INTO result;

  IF p_requested_driver IS NOT NULL THEN
    INSERT INTO public.notifications (
      id, user_id, sender_id, ride_id, type, title, body, payload
    ) VALUES (
      pg_catalog.gen_random_uuid()::text,
      locked_driver_id,
      auth.uid(),
      result.id,
      'ride_request',
      'New ride request',
      'A passenger sent you a ride request. Sign in to accept or decline it.',
      pg_catalog.jsonb_build_object(
        'ride_id', result.id,
        'status', 'searching'
      )
    );
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text, numeric
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text, numeric
) TO authenticated;

