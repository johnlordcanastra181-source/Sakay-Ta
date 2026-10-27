-- Migration: 202610270001_tricycle_multi_pax_capacity_and_concurrent_booking.sql
-- Enables concurrent multi-passenger bookings for Tricycles (up to 4 pax)
-- and prevents race conditions/crashes during simultaneous bookings.

-- 1. Add passenger_count column to public.rides table
ALTER TABLE public.rides
ADD COLUMN IF NOT EXISTS passenger_count integer NOT NULL DEFAULT 1
CHECK (passenger_count BETWEEN 1 AND 4);

-- 2. Update driver_has_conflicting_ride to support multi-passenger capacity
-- Tricycle: max 4 passengers across active rides
-- Habal-Habal (Motorcycle): max 1 passenger
CREATE OR REPLACE FUNCTION public.driver_has_conflicting_ride(
  p_driver_id uuid,
  p_excluded_ride_id text DEFAULT NULL,
  p_additional_pax integer DEFAULT 1
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_vehicle_type public.vehicle_type;
  v_max_capacity integer := 1;
  v_occupied_pax integer := 0;
  v_req_pax integer := LEAST(GREATEST(COALESCE(p_additional_pax, 1), 1), 4);
BEGIN
  SELECT d.vehicle_type INTO v_vehicle_type
  FROM public.drivers AS d
  WHERE d.user_id = p_driver_id;

  IF NOT FOUND THEN
    RETURN true;
  END IF;

  IF v_vehicle_type = 'tricycle'::public.vehicle_type THEN
    v_max_capacity := 4;
  ELSE
    v_max_capacity := 1;
  END IF;

  SELECT COALESCE(SUM(COALESCE(r.passenger_count, 1)), 0)::integer
  INTO v_occupied_pax
  FROM public.rides AS r
  WHERE r.driver_id = p_driver_id
    AND (p_excluded_ride_id IS NULL OR r.id <> p_excluded_ride_id)
    AND (
      r.status IN ('accepted', 'arrived', 'started')
      OR (
        r.status = 'searching'
        AND r.created_at >= pg_catalog.statement_timestamp() - interval '90 seconds'
      )
    );

  RETURN (v_occupied_pax + v_req_pax) > v_max_capacity;
END;
$$;

REVOKE ALL ON FUNCTION public.driver_has_conflicting_ride(uuid, text, integer) FROM PUBLIC, anon, authenticated;

-- 3. Update recalculate_driver_availability to use capacity-aware conflict check
CREATE OR REPLACE FUNCTION public.recalculate_driver_availability(
  p_driver_id uuid,
  p_touch_presence boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  saved_online boolean;
  should_be_available boolean;
BEGIN
  SELECT d.is_online
  INTO saved_online
  FROM public.drivers AS d
  WHERE d.user_id = p_driver_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  should_be_available := saved_online
      AND public.driver_is_requestable(p_driver_id)
      AND NOT public.driver_has_conflicting_ride(p_driver_id, NULL, 1);

  UPDATE public.drivers AS d
  SET is_available = should_be_available
  WHERE d.user_id = p_driver_id
    AND d.is_available IS DISTINCT FROM should_be_available;

  INSERT INTO public.driver_presence AS current_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at, updated_at
  )
  SELECT
    d.user_id, d.vehicle_type, d.plate_number, d.is_online,
    should_be_available, d.current_latitude, d.current_longitude,
    d.last_location_at, pg_catalog.statement_timestamp()
  FROM public.drivers AS d
  WHERE d.user_id = p_driver_id
  ON CONFLICT (driver_id) DO UPDATE SET
    vehicle_type = EXCLUDED.vehicle_type,
    plate_number = EXCLUDED.plate_number,
    is_online = EXCLUDED.is_online,
    is_available = EXCLUDED.is_available,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    last_location_at = EXCLUDED.last_location_at,
    updated_at = pg_catalog.statement_timestamp()
  WHERE p_touch_presence
     OR current_presence.vehicle_type IS DISTINCT FROM EXCLUDED.vehicle_type
     OR current_presence.plate_number IS DISTINCT FROM EXCLUDED.plate_number
     OR current_presence.is_online IS DISTINCT FROM EXCLUDED.is_online
     OR current_presence.is_available IS DISTINCT FROM EXCLUDED.is_available
     OR current_presence.latitude IS DISTINCT FROM EXCLUDED.latitude
     OR current_presence.longitude IS DISTINCT FROM EXCLUDED.longitude
     OR current_presence.last_location_at IS DISTINCT FROM EXCLUDED.last_location_at;
END;
$$;

-- 4. Update request_ride_with_id to accept passenger_count and handle concurrency
DROP FUNCTION IF EXISTS public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text, numeric
);
DROP FUNCTION IF EXISTS public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text, numeric, integer
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
  estimated_fare numeric DEFAULT NULL,
  passenger_count integer DEFAULT 1
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
  v_passenger_count integer := LEAST(GREATEST(COALESCE(passenger_count, 1), 1), 4);
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

  -- Habitual single-pax enforcement for motor / habal-habal
  IF p_requested_vehicle = 'habal'::public.vehicle_type AND v_passenger_count > 1 THEN
    v_passenger_count := 1;
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
    -- Serialize concurrent booking requests for this driver using row-level locking
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

    -- Concurrency check: does adding this booking exceed driver's seat capacity?
    IF public.driver_has_conflicting_ride(p_requested_driver, NULL, v_passenger_count) THEN
      RAISE EXCEPTION 'Driver has reached maximum passenger capacity. Please choose another driver.';
    END IF;

    PERFORM public.recalculate_driver_availability(p_requested_driver, false);
  END IF;

  -- Authoritative fare calculation
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
    payment_method, status, passenger_count, fare_locked
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
    v_passenger_count,
    pg_catalog.jsonb_build_object(
      'vehicle_type', config.vehicle_type,
      'base_fare', config.base_fare,
      'included_base_distance', config.included_base_distance,
      'per_km_rate', config.per_km_rate,
      'minimum_fare', config.minimum_fare,
      'confirmed_estimated_fare', v_fare,
      'passenger_count', v_passenger_count,
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
        'passenger_count', v_passenger_count,
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
  double precision, double precision, text, numeric, integer, text, numeric, integer
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text, numeric, integer
) TO authenticated;

-- 5. Update accept_ride to support multi-rider acceptance up to capacity
CREATE OR REPLACE FUNCTION public.accept_ride(ride_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
  p_ride_id text := ride_id;
  current_ride public.rides%ROWTYPE;
  current_driver public.drivers%ROWTYPE;
  current_presence public.driver_presence%ROWTYPE;
  v_ride_pax integer := 1;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  PERFORM public.expire_unanswered_ride_requests();

  SELECT r.* INTO current_ride
  FROM public.rides AS r
  WHERE r.id = p_ride_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_ride_pax := LEAST(GREATEST(COALESCE(current_ride.passenger_count, 1), 1), 4);

  IF current_ride.status = 'accepted'
     AND current_ride.driver_id = auth.uid() THEN
    RETURN true;
  END IF;
  IF current_ride.status <> 'searching'
     OR (current_ride.driver_id IS NOT NULL
         AND current_ride.driver_id <> auth.uid()) THEN
    RETURN false;
  END IF;

  SELECT d.* INTO current_driver
  FROM public.drivers AS d
  WHERE d.user_id = auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  SELECT dp.* INTO current_presence
  FROM public.driver_presence AS dp
  WHERE dp.driver_id = auth.uid()
  FOR UPDATE;
  IF NOT FOUND
     OR current_ride.vehicle_type <> current_driver.vehicle_type
     OR current_ride.vehicle_type <> current_presence.vehicle_type
     OR NOT public.driver_is_reachable_and_approved(auth.uid())
     OR public.driver_has_conflicting_ride(auth.uid(), p_ride_id, v_ride_pax) THEN
    RETURN false;
  END IF;

  IF current_ride.driver_id IS DISTINCT FROM auth.uid()
     AND NOT public.driver_is_bookable(auth.uid()) THEN
    RETURN false;
  END IF;

  UPDATE public.rides AS r
  SET driver_id = auth.uid(),
      status = 'accepted',
      accepted_at = pg_catalog.statement_timestamp(),
      updated_at = pg_catalog.statement_timestamp()
  WHERE r.id = p_ride_id
    AND r.status = 'searching';
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  INSERT INTO public.ride_status_history (
    ride_id, from_status, to_status, changed_by
  ) VALUES (
    p_ride_id, 'searching', 'accepted', auth.uid()
  );

  -- Keep driver available if seats still remain (e.g. 1-3 pax occupied on tricycle)
  PERFORM public.recalculate_driver_availability(auth.uid(), false);

  INSERT INTO public.notifications (
    id, user_id, sender_id, ride_id, type, title, body, payload
  ) VALUES (
    pg_catalog.gen_random_uuid()::text,
    current_ride.passenger_id,
    auth.uid(),
    p_ride_id,
    'ride_accepted',
    'Ride accepted',
    'A driver has accepted your ride request and is on their way.',
    pg_catalog.jsonb_build_object(
      'ride_id', p_ride_id,
      'driver_id', auth.uid(),
      'status', 'accepted'
    )
  );

  RETURN true;
END;
$$;

-- 6. Update transition_ride to recalculate availability correctly on trip completion
CREATE OR REPLACE FUNCTION public.transition_ride(
  ride_id text,
  next_status public.ride_status
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
#variable_conflict use_column
DECLARE
  p_ride_id text;
  p_next_status public.ride_status;
  current_ride public.rides%rowtype;
  earning_inserted boolean := false;
  existing_earning_id text;
  existing_payment_id text;
  current_rank integer;
  requested_rank integer;
BEGIN
  p_ride_id := ride_id;
  p_next_status := next_status;

  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;
  IF p_ride_id IS NULL OR pg_catalog.btrim(p_ride_id) = '' THEN
    RETURN false;
  END IF;

  SELECT * INTO current_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND OR current_ride.driver_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;

  IF current_ride.status = p_next_status THEN
    RETURN true;
  END IF;

  current_rank := CASE current_ride.status
    WHEN 'searching' THEN 1
    WHEN 'accepted'  THEN 2
    WHEN 'arrived'   THEN 3
    WHEN 'started'   THEN 4
    WHEN 'completed' THEN 5
    ELSE 0
  END;

  requested_rank := CASE p_next_status
    WHEN 'searching' THEN 1
    WHEN 'accepted'  THEN 2
    WHEN 'arrived'   THEN 3
    WHEN 'started'   THEN 4
    WHEN 'completed' THEN 5
    ELSE 0
  END;

  IF requested_rank > 0 AND current_rank >= requested_rank THEN
    RETURN true;
  END IF;

  IF NOT (
    (current_ride.status = 'accepted' AND p_next_status = 'arrived') OR
    (current_ride.status = 'arrived' AND p_next_status = 'started') OR
    (current_ride.status = 'started' AND p_next_status = 'completed')
  ) THEN
    RETURN false;
  END IF;

  UPDATE public.rides AS r
  SET
    status = p_next_status,
    arrived_at = CASE WHEN p_next_status = 'arrived' THEN pg_catalog.now() ELSE r.arrived_at END,
    started_at = CASE WHEN p_next_status = 'started' THEN pg_catalog.now() ELSE r.started_at END,
    completed_at = CASE WHEN p_next_status = 'completed' THEN pg_catalog.now() ELSE r.completed_at END,
    updated_at = pg_catalog.now()
  WHERE r.id = p_ride_id;

  IF p_next_status = 'completed' THEN
    UPDATE public.drivers AS d
    SET
      total_trips = d.total_trips + 1
    WHERE d.user_id = auth.uid();

    UPDATE public.passenger_profiles AS pp
    SET ride_count = pp.ride_count + 1
    WHERE pp.user_id = current_ride.passenger_id;

    -- Recalculate driver availability: frees up passenger's seat
    PERFORM public.recalculate_driver_availability(auth.uid(), false);

    IF current_ride.payment_method = 'cash' THEN
      SELECT p.id INTO existing_payment_id
      FROM public.payments AS p
      WHERE p.ride_id = p_ride_id;

      IF existing_payment_id IS NULL THEN
        INSERT INTO public.payments (
          id, ride_id, passenger_id, driver_id, amount, platform_fee, driver_net,
          method, status, metadata, created_at, paid_at, updated_at
        ) VALUES (
          'pay_' || p_ride_id,
          p_ride_id,
          current_ride.passenger_id,
          auth.uid(),
          current_ride.fare,
          0,
          current_ride.fare,
          'cash',
          'paid',
          pg_catalog.jsonb_build_object('settlement', 'driver_confirmed_cash'),
          pg_catalog.now(),
          pg_catalog.now(),
          pg_catalog.now()
        )
        ON CONFLICT DO NOTHING;
      END IF;

      UPDATE public.payments AS p
      SET
        passenger_id = current_ride.passenger_id,
        driver_id = auth.uid(),
        amount = current_ride.fare,
        platform_fee = 0,
        driver_net = current_ride.fare,
        method = 'cash',
        status = 'paid',
        paid_at = COALESCE(p.paid_at, pg_catalog.now()),
        updated_at = pg_catalog.now()
      WHERE p.ride_id = p_ride_id;
    END IF;

    SELECT de.id INTO existing_earning_id
    FROM public.driver_earnings AS de
    WHERE de.ride_id = p_ride_id;

    IF existing_earning_id IS NULL THEN
      INSERT INTO public.driver_earnings (
        driver_id, ride_id, gross_fare, platform_fee, net_earnings, payment_method, completed_at
      ) VALUES (
        auth.uid(),
        p_ride_id,
        current_ride.fare,
        0,
        current_ride.fare,
        current_ride.payment_method,
        pg_catalog.now()
      )
      ON CONFLICT (ride_id) DO NOTHING;
      earning_inserted := FOUND;
    END IF;

    IF earning_inserted THEN
      UPDATE public.drivers AS d
      SET lifetime_earnings = d.lifetime_earnings + current_ride.fare
      WHERE d.user_id = auth.uid();
    END IF;
  END IF;

  INSERT INTO public.ride_status_history (
    ride_id, from_status, to_status, changed_by
  ) VALUES (
    p_ride_id, current_ride.status, p_next_status, auth.uid()
  );

  RETURN true;
END;
$$;

-- 7. Update cancel_ride to release capacity via recalculate_driver_availability
CREATE OR REPLACE FUNCTION public.cancel_ride(ride_id text, reason text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  current_ride public.rides%rowtype;
BEGIN
  SELECT * INTO current_ride
  FROM public.rides
  WHERE id = ride_id
  FOR UPDATE;

  IF NOT FOUND
    OR (NOT public.is_admin() AND current_ride.passenger_id <> auth.uid() AND current_ride.driver_id IS DISTINCT FROM auth.uid())
    OR current_ride.status NOT IN ('searching', 'accepted', 'arrived', 'started') THEN
    RETURN false;
  END IF;

  UPDATE public.rides
  SET status = 'cancelled',
      cancelled_at = pg_catalog.now(),
      cancellation_reason = reason,
      updated_at = pg_catalog.now()
  WHERE id = ride_id;

  IF current_ride.driver_id IS NOT NULL THEN
    PERFORM public.recalculate_driver_availability(current_ride.driver_id, false);
  END IF;

  INSERT INTO public.ride_status_history (
    ride_id, from_status, to_status, changed_by, reason
  ) VALUES (
    ride_id, current_ride.status, 'cancelled', auth.uid(), reason
  );

  RETURN true;
END;
$$;

-- 8. Update nearby_drivers to reflect seat availability
DROP FUNCTION IF EXISTS public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
);

CREATE FUNCTION public.nearby_drivers(
  p_passenger_latitude double precision,
  p_passenger_longitude double precision,
  p_requested_vehicle public.vehicle_type DEFAULT NULL,
  p_radius_km double precision DEFAULT 10.0
)
RETURNS TABLE(
  user_id uuid,
  full_name text,
  profile_photo_path text,
  vehicle_type public.vehicle_type,
  plate_number text,
  latitude double precision,
  longitude double precision,
  last_location_at timestamptz,
  rating_average numeric,
  rating_count integer,
  distance_km double precision,
  is_online boolean,
  is_available boolean,
  has_active_ride boolean,
  has_live_session boolean,
  completed_trips integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT
    d.user_id,
    p.full_name,
    COALESCE(
      NULLIF(BTRIM(p.profile_photo_path), ''),
      (SELECT dd.storage_path FROM public.driver_documents dd
       WHERE dd.driver_id = d.user_id AND dd.document_type = 'profile'
       ORDER BY dd.uploaded_at DESC LIMIT 1),
      (SELECT da.doc_profile FROM public.driver_applications da
       WHERE (da.auth_user_id = d.user_id OR da.id = d.approved_application_id)
         AND da.doc_profile IS NOT NULL
       ORDER BY da.submitted_at DESC LIMIT 1)
    ) AS profile_photo_path,
    dp.vehicle_type,
    dp.plate_number,
    dp.latitude,
    dp.longitude,
    dp.last_location_at,
    d.rating_average,
    d.rating_count,
    distance_data.distance_km,
    d.is_online,
    public.driver_is_requestable(d.user_id)
      AND NOT public.driver_has_conflicting_ride(d.user_id, NULL, 1),
    public.driver_has_conflicting_ride(d.user_id, NULL, 1),
    public.driver_has_live_session(d.user_id),
    COALESCE((
      SELECT COUNT(DISTINCT r.id)::integer
      FROM public.rides AS r
      WHERE r.driver_id = d.user_id
        AND r.status = 'completed'
    ), 0) AS completed_trips
  FROM public.drivers AS d
  JOIN public.profiles AS p ON p.id = d.user_id
  JOIN public.driver_presence AS dp ON dp.driver_id = d.user_id
  CROSS JOIN LATERAL (
    SELECT 6371.0 * 2 * pg_catalog.asin(pg_catalog.sqrt(
      pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
        dp.latitude - p_passenger_latitude
      ) / 2), 2)
      + pg_catalog.cos(pg_catalog.radians(p_passenger_latitude))
        * pg_catalog.cos(pg_catalog.radians(dp.latitude))
        * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
            dp.longitude - p_passenger_longitude
          ) / 2), 2)
    )) AS distance_km
  ) AS distance_data
  WHERE d.application_status IN ('approved', 'active')
    AND p.account_status IN ('approved', 'active')
    AND dp.latitude BETWEEN -90 AND 90
    AND dp.longitude BETWEEN -180 AND 180
    AND dp.last_location_at IS NOT NULL
    AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
    AND (p_requested_vehicle IS NULL OR dp.vehicle_type = p_requested_vehicle)
    AND distance_data.distance_km <= COALESCE(p_radius_km, 10.0)
  ORDER BY
    (d.is_online AND public.driver_is_requestable(d.user_id) AND NOT public.driver_has_conflicting_ride(d.user_id, NULL, 1)) DESC,
    distance_data.distance_km ASC;
$$;

REVOKE ALL ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) TO authenticated;

