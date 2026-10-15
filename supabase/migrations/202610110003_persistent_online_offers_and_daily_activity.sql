-- Today's activity comes from canonical completed rides and their actual
-- completion instant. The wallet's driver_earnings ledger is not rewritten.
CREATE INDEX IF NOT EXISTS rides_driver_completed_at_idx
  ON public.rides (driver_id, completed_at)
  WHERE status = 'completed' AND completed_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_driver_daily_activity_today(
  target_driver uuid
)
RETURNS TABLE(gross_earnings numeric, completed_trips bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  p_target_driver uuid := target_driver;
  manila_day_start_utc timestamptz;
  manila_day_end_utc timestamptz;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_target_driver THEN
    RAISE EXCEPTION 'drivers may only read their own daily activity';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.drivers AS d WHERE d.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'driver account required';
  END IF;

  -- Convert Philippine local midnight to the corresponding UTC instants;
  -- the interval is [start, end), so midnight belongs to exactly one day.
  manila_day_start_utc := date_trunc(
    'day', pg_catalog.statement_timestamp() AT TIME ZONE 'Asia/Manila'
  ) AT TIME ZONE 'Asia/Manila';
  manila_day_end_utc := manila_day_start_utc + interval '1 day';

  RETURN QUERY
  SELECT
    COALESCE(
      SUM(r.fare) FILTER (
        WHERE lower(COALESCE(r.payment_status, '')) <> 'refunded'
          AND NOT EXISTS (
            SELECT 1
            FROM public.payments AS payment
            WHERE payment.ride_id = r.id
              AND lower(payment.status) = 'refunded'
          )
      ),
      0
    )::numeric,
    COUNT(*)::bigint
  FROM public.rides AS r
  WHERE r.driver_id = p_target_driver
    AND r.status = 'completed'
    AND r.completed_at >= manila_day_start_utc
    AND r.completed_at < manila_day_end_utc;
END;
$$;

REVOKE ALL ON FUNCTION public.get_driver_daily_activity_today(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_daily_activity_today(uuid)
  TO authenticated;

-- Persisted preference is drivers.is_online. A live session is only required
-- to accept an offer, not to create a short-lived pending offer for that driver.
CREATE OR REPLACE FUNCTION public.driver_is_requestable(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.drivers AS d
    JOIN public.profiles AS p ON p.id = d.user_id
    JOIN public.driver_presence AS dp ON dp.driver_id = d.user_id
    WHERE d.user_id = p_driver_id
      AND d.is_online
      AND d.application_status IN ('approved', 'active')
      AND p.account_status IN ('approved', 'active')
      AND dp.vehicle_type = d.vehicle_type
      AND dp.latitude BETWEEN -90 AND 90
      AND dp.longitude BETWEEN -180 AND 180
      AND dp.last_location_at IS NOT NULL
      AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
  );
$$;

CREATE OR REPLACE FUNCTION public.driver_is_bookable(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT public.driver_is_reachable_and_approved(p_driver_id)
     AND NOT public.driver_has_conflicting_ride(p_driver_id, NULL);
$$;

REVOKE ALL ON FUNCTION public.driver_is_requestable(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.driver_is_bookable(uuid)
  FROM PUBLIC, anon, authenticated;

-- Passenger preflight for creating a pending offer. Accept still uses the
-- stricter live-session/fresh-location bookability predicate above.
CREATE OR REPLACE FUNCTION public.is_driver_requestable(target_driver uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT auth.uid() IS NOT NULL
     AND public.driver_is_requestable(target_driver)
     AND NOT public.driver_has_conflicting_ride(target_driver, NULL);
$$;

REVOKE ALL ON FUNCTION public.is_driver_requestable(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_driver_requestable(uuid)
  TO authenticated;

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
      AND NOT public.driver_has_conflicting_ride(p_driver_id, NULL);

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

CREATE OR REPLACE FUNCTION public.sync_driver_presence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  available_now boolean;
BEGIN
  available_now := NEW.is_online
      AND public.driver_is_requestable(NEW.user_id)
      AND NOT public.driver_has_conflicting_ride(NEW.user_id, NULL);

  INSERT INTO public.driver_presence AS current_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at, updated_at
  ) VALUES (
    NEW.user_id, NEW.vehicle_type, NEW.plate_number, NEW.is_online,
    available_now, NEW.current_latitude, NEW.current_longitude,
    NEW.last_location_at, pg_catalog.statement_timestamp()
  )
  ON CONFLICT (driver_id) DO UPDATE SET
    vehicle_type = EXCLUDED.vehicle_type,
    plate_number = EXCLUDED.plate_number,
    is_online = EXCLUDED.is_online,
    is_available = EXCLUDED.is_available,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    last_location_at = EXCLUDED.last_location_at,
    updated_at = pg_catalog.statement_timestamp()
  WHERE current_presence.vehicle_type IS DISTINCT FROM EXCLUDED.vehicle_type
     OR current_presence.plate_number IS DISTINCT FROM EXCLUDED.plate_number
     OR current_presence.is_online IS DISTINCT FROM EXCLUDED.is_online
     OR current_presence.is_available IS DISTINCT FROM EXCLUDED.is_available
     OR current_presence.latitude IS DISTINCT FROM EXCLUDED.latitude
     OR current_presence.longitude IS DISTINCT FROM EXCLUDED.longitude
     OR current_presence.last_location_at IS DISTINCT FROM EXCLUDED.last_location_at;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_driver_availability(uuid, boolean)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_driver_presence()
  FROM PUBLIC, anon, authenticated;

-- Expire unanswered searching offers at their existing 90-second deadline,
-- release the driver reservation, and persist a passenger-facing notice.
CREATE OR REPLACE FUNCTION public.expire_unanswered_ride_requests()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  stale_ride record;
  expired_count integer := 0;
BEGIN
  FOR stale_ride IN
    SELECT r.id, r.driver_id, r.passenger_id
    FROM public.rides AS r
    WHERE r.status = 'searching'
      AND r.created_at <= pg_catalog.statement_timestamp() - interval '90 seconds'
    ORDER BY r.created_at, r.id
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.rides AS r
    SET status = 'cancelled',
        cancelled_at = pg_catalog.statement_timestamp(),
        cancellation_reason = COALESCE(r.cancellation_reason, 'request_expired'),
        updated_at = pg_catalog.statement_timestamp()
    WHERE r.id = stale_ride.id
      AND r.status = 'searching';

    IF FOUND THEN
      INSERT INTO public.ride_status_history (
        ride_id, from_status, to_status, changed_by, reason
      ) VALUES (
        stale_ride.id, 'searching', 'cancelled', auth.uid(), 'request_expired'
      );
      INSERT INTO public.notifications (
        id, user_id, sender_id, ride_id, type, title, body, payload
      ) VALUES (
        pg_catalog.gen_random_uuid()::text,
        stale_ride.passenger_id,
        stale_ride.driver_id,
        stale_ride.id,
        'ride_request_expired',
        'Ride request expired',
        'No driver accepted this request in time. Please choose another driver.',
        pg_catalog.jsonb_build_object(
          'ride_id', stale_ride.id,
          'status', 'cancelled',
          'reason', 'request_expired'
        )
      );
      expired_count := expired_count + 1;
    END IF;
  END LOOP;

  RETURN expired_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_unanswered_ride_requests()
  FROM PUBLIC, anon, authenticated;

-- Driver login performs a scoped cleanup before fetching persisted offers, so
-- an expired request cannot reappear while the scheduled cleanup is catching up.
CREATE OR REPLACE FUNCTION public.expire_driver_pending_requests()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  stale_ride record;
  expired_count integer := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.drivers AS d WHERE d.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'driver authentication required';
  END IF;

  FOR stale_ride IN
    SELECT r.id, r.passenger_id
    FROM public.rides AS r
    WHERE r.driver_id = auth.uid()
      AND r.status = 'searching'
      AND r.created_at <= pg_catalog.statement_timestamp() - interval '90 seconds'
    ORDER BY r.created_at, r.id
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.rides AS r
    SET status = 'cancelled',
        cancelled_at = pg_catalog.statement_timestamp(),
        cancellation_reason = COALESCE(r.cancellation_reason, 'request_expired'),
        updated_at = pg_catalog.statement_timestamp()
    WHERE r.id = stale_ride.id
      AND r.driver_id = auth.uid()
      AND r.status = 'searching';

    IF FOUND THEN
      INSERT INTO public.ride_status_history (
        ride_id, from_status, to_status, changed_by, reason
      ) VALUES (
        stale_ride.id, 'searching', 'cancelled', auth.uid(), 'request_expired'
      );
      INSERT INTO public.notifications (
        id, user_id, sender_id, ride_id, type, title, body, payload
      ) VALUES (
        pg_catalog.gen_random_uuid()::text,
        stale_ride.passenger_id,
        auth.uid(),
        stale_ride.id,
        'ride_request_expired',
        'Ride request expired',
        'No driver accepted this request in time. Please choose another driver.',
        pg_catalog.jsonb_build_object(
          'ride_id', stale_ride.id,
          'status', 'cancelled',
          'reason', 'request_expired'
        )
      );
      expired_count := expired_count + 1;
    END IF;
  END LOOP;

  RETURN expired_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_driver_pending_requests()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expire_driver_pending_requests()
  TO authenticated;

-- The RPC keeps Online as the saved preference and exposes session reachability
-- as a separate field. A stale marker is explicitly not a live ETA in the app.
DROP FUNCTION IF EXISTS public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
);
CREATE FUNCTION public.nearby_drivers(
  passenger_latitude double precision,
  passenger_longitude double precision,
  requested_vehicle public.vehicle_type DEFAULT NULL,
  radius_km double precision DEFAULT 10
)
RETURNS TABLE (
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
  has_live_session boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
  p_passenger_latitude double precision := passenger_latitude;
  p_passenger_longitude double precision := passenger_longitude;
  p_requested_vehicle public.vehicle_type := requested_vehicle;
  p_radius_km double precision := radius_km;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF p_passenger_latitude NOT BETWEEN -90 AND 90
     OR p_passenger_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid passenger coordinates';
  END IF;

  PERFORM public.expire_unanswered_ride_requests();

  RETURN QUERY
  SELECT
    d.user_id,
    p.full_name,
    p.profile_photo_path,
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
      AND NOT public.driver_has_conflicting_ride(d.user_id, NULL),
    public.driver_has_conflicting_ride(d.user_id, NULL),
    public.driver_has_live_session(d.user_id)
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
    AND distance_data.distance_km <= GREATEST(COALESCE(p_radius_km, 10), 0)
  ORDER BY distance_data.distance_km ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) TO authenticated;

-- Keep the established fare/validation/idempotency contract. The saved Online
-- preference plus a real last-known fix is enough to create a searching offer;
-- accept_ride still independently requires an authenticated live driver session
-- and a fresh GPS fix before changing status to accepted.
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
  payment_method text DEFAULT 'cash'
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
      -- The passenger picker exposes 5/10/15 km radii. Enforce its maximum
      -- service radius here too, so a direct RPC call cannot target a remote
      -- last-known location outside the supported dispatch area.
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
    GREATEST(
      config.minimum_fare,
      pg_catalog.round((
        config.base_fare
        + config.per_km_rate * GREATEST(
          p_distance_km - config.included_base_distance, 0
        )
      ) / 5) * 5
    ),
    0,
    GREATEST(
      config.minimum_fare,
      pg_catalog.round((
        config.base_fare
        + config.per_km_rate * GREATEST(
          p_distance_km - config.included_base_distance, 0
        )
      ) / 5) * 5
    ),
    p_payment_method,
    'searching',
    pg_catalog.jsonb_build_object(
      'vehicle_type', config.vehicle_type,
      'base_fare', config.base_fare,
      'included_base_distance', config.included_base_distance,
      'per_km_rate', config.per_km_rate,
      'minimum_fare', config.minimum_fare,
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
  double precision, double precision, text, numeric, integer, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text
) TO authenticated;

-- A scheduled server cleanup ensures passengers are not left waiting if every
-- client closes. The authenticated driver fetch also expires its own stale
-- request before showing the persisted inbox.
CREATE EXTENSION IF NOT EXISTS pg_cron;
DO $$
DECLARE
  existing_job record;
BEGIN
  FOR existing_job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'sakayta-expire-unanswered-ride-requests'
  LOOP
    PERFORM cron.unschedule(existing_job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'sakayta-expire-unanswered-ride-requests',
    '* * * * *',
    'SELECT public.expire_unanswered_ride_requests();'
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
