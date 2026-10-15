-- Keep the saved Online preference separate from live presence and booking
-- availability. Reconcile availability from the session, GPS fix and rides.

CREATE OR REPLACE FUNCTION public.driver_has_live_session(p_driver_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.driver_online_sessions AS s
    WHERE s.driver_id = p_driver_id
      AND s.ended_at IS NULL
      AND s.last_heartbeat_at >= pg_catalog.statement_timestamp() - interval '90 seconds'
  );
$$;

CREATE OR REPLACE FUNCTION public.driver_has_conflicting_ride(
  p_driver_id uuid,
  p_excluded_ride_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rides AS r
    WHERE r.driver_id = p_driver_id
      AND (p_excluded_ride_id IS NULL OR r.id <> p_excluded_ride_id)
      AND (
        r.status IN ('accepted', 'arrived', 'started')
        OR (
          r.status = 'searching'
          AND r.created_at >= pg_catalog.statement_timestamp() - interval '90 seconds'
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.driver_is_reachable_and_approved(p_driver_id uuid)
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
      AND dp.last_location_at >= pg_catalog.statement_timestamp() - interval '5 minutes'
      AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
      AND public.driver_has_live_session(d.user_id)
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
  live_online boolean;
  should_be_available boolean;
BEGIN
  SELECT d.is_online AND public.driver_has_live_session(d.user_id)
  INTO live_online
  FROM public.drivers AS d
  WHERE d.user_id = p_driver_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  should_be_available := live_online AND public.driver_is_bookable(p_driver_id);

  UPDATE public.drivers AS d
  SET is_available = should_be_available
  WHERE d.user_id = p_driver_id
    AND d.is_available IS DISTINCT FROM should_be_available;

  INSERT INTO public.driver_presence AS current_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at, updated_at
  )
  SELECT
    d.user_id, d.vehicle_type, d.plate_number, live_online,
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

REVOKE ALL ON FUNCTION public.driver_has_live_session(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.driver_has_conflicting_ride(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.driver_is_reachable_and_approved(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.driver_is_bookable(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.recalculate_driver_availability(uuid, boolean) FROM PUBLIC, anon, authenticated;

-- This read-only preflight is derived from canonical session, location,
-- approval and ride state rather than the cached is_available bit.
CREATE OR REPLACE FUNCTION public.is_driver_bookable(target_driver uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT auth.uid() IS NOT NULL
     AND public.driver_is_bookable(target_driver);
$$;

REVOKE ALL ON FUNCTION public.is_driver_bookable(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_driver_bookable(uuid) TO authenticated;

-- The driver row stores the saved toggle preference. Presence is live only
-- while an authenticated app session is heartbeating.
CREATE OR REPLACE FUNCTION public.sync_driver_presence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  live_online boolean;
  available_now boolean;
BEGIN
  live_online := NEW.is_online AND public.driver_has_live_session(NEW.user_id);
  available_now := live_online AND public.driver_is_bookable(NEW.user_id);

  INSERT INTO public.driver_presence AS current_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at, updated_at
  ) VALUES (
    NEW.user_id, NEW.vehicle_type, NEW.plate_number, live_online,
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

REVOKE ALL ON FUNCTION public.sync_driver_presence() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_driver_presence_trigger ON public.drivers;
CREATE TRIGGER sync_driver_presence_trigger
  AFTER INSERT OR UPDATE OF
    is_online, is_available, application_status, vehicle_type, plate_number,
    current_latitude, current_longitude, last_location_at
  ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_driver_presence();

CREATE OR REPLACE FUNCTION public.reconcile_driver_state_after_ride_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.driver_id IS NOT NULL
     AND OLD.driver_id IS DISTINCT FROM NEW.driver_id THEN
    PERFORM public.recalculate_driver_availability(OLD.driver_id, false);
  END IF;

  IF NEW.driver_id IS NOT NULL THEN
    PERFORM public.recalculate_driver_availability(NEW.driver_id, false);
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_driver_state_after_ride_change() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS rides_reconcile_driver_state_insert ON public.rides;
DROP TRIGGER IF EXISTS rides_reconcile_driver_state_update ON public.rides;
CREATE TRIGGER rides_reconcile_driver_state_insert
  AFTER INSERT ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.reconcile_driver_state_after_ride_change();
CREATE TRIGGER rides_reconcile_driver_state_update
  AFTER UPDATE OF driver_id, status ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.reconcile_driver_state_after_ride_change();

-- Catch direct presence updates too. This prevents older RPC code from
-- overwriting a derived Busy/Available value after the ride row has changed.
CREATE OR REPLACE FUNCTION public.reconcile_driver_state_after_presence_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  PERFORM public.recalculate_driver_availability(NEW.driver_id, false);
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_driver_state_after_presence_change() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS driver_presence_reconcile_state ON public.driver_presence;
CREATE TRIGGER driver_presence_reconcile_state
  AFTER INSERT OR UPDATE ON public.driver_presence
  FOR EACH ROW
  EXECUTE FUNCTION public.reconcile_driver_state_after_presence_change();

-- Searching requests assigned to a driver are reservations for 90 seconds.
-- A request that receives no response is cancelled lazily by dispatch RPCs;
-- accepted and in-progress rides are never expired by this cleanup.
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
    SELECT r.id, r.driver_id
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
      expired_count := expired_count + 1;
    END IF;
  END LOOP;

  RETURN expired_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_unanswered_ride_requests() FROM PUBLIC, anon, authenticated;

-- Return live presence and availability derived from approval, the current
-- heartbeat, fresh GPS and conflicting ride/reservation rows.
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
  has_active_ride boolean
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
    d.is_online AND public.driver_has_live_session(d.user_id),
    public.driver_is_bookable(d.user_id),
    public.driver_has_conflicting_ride(d.user_id, NULL)
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

-- A declined or cancelled request can no longer leave a stale stored Busy bit.
-- Booking revalidates the locked driver and presence rows regardless of that
-- stored bit, but only repairs it when every live eligibility condition holds.
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

  -- Serialize this passenger's concurrent booking attempts.
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
      AND dp.last_location_at >= pg_catalog.statement_timestamp() - interval '5 minutes'
      AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
      AND d.is_online
      AND public.driver_has_live_session(d.user_id)
    FOR UPDATE OF d, dp;

    IF locked_driver_id IS NULL THEN
      RAISE EXCEPTION 'Driver is no longer online, approved, reachable, or location-current. Please choose another driver.';
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
     OR public.driver_has_conflicting_ride(auth.uid(), p_ride_id) THEN
    RETURN false;
  END IF;

  -- A selected-driver searching row is this driver's live reservation. An
  -- unassigned pool request still requires the full available predicate.
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

  INSERT INTO public.notifications (
    id, user_id, sender_id, ride_id, type, title, body
  ) VALUES (
    pg_catalog.gen_random_uuid()::text,
    current_ride.passenger_id,
    auth.uid(),
    p_ride_id,
    'ride_accepted',
    'Driver Accepted',
    'A driver has accepted your ride request.'
  );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_ride(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_ride(text) TO authenticated;

-- Logout ends live presence but preserves the saved toggle preference. The
-- explicit Offline button uses set_driver_offline(), which clears the pref.
CREATE OR REPLACE FUNCTION public.start_driver_online_session()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  active_id uuid;
  active_heartbeat timestamptz;
  new_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers AS d
    JOIN public.profiles AS p ON p.id = d.user_id
    WHERE d.user_id = auth.uid()
      AND d.application_status IN ('approved', 'active')
      AND p.account_status IN ('approved', 'active')
  ) THEN
    RAISE EXCEPTION 'approved driver authorization required';
  END IF;

  -- Serialize concurrent start/stop calls before touching the single-open
  -- session row, avoiding a unique-index race during rapid app reconnects.
  PERFORM 1
  FROM public.drivers AS d
  WHERE d.user_id = auth.uid()
  FOR UPDATE;

  SELECT s.id, s.last_heartbeat_at
  INTO active_id, active_heartbeat
  FROM public.driver_online_sessions AS s
  WHERE s.driver_id = auth.uid()
    AND s.ended_at IS NULL
  FOR UPDATE;

  IF active_id IS NOT NULL
     AND active_heartbeat >= pg_catalog.statement_timestamp() - interval '90 seconds' THEN
    UPDATE public.driver_online_sessions AS s
    SET last_heartbeat_at = pg_catalog.statement_timestamp()
    WHERE s.id = active_id;
    new_id := active_id;
  ELSE
    IF active_id IS NOT NULL THEN
      UPDATE public.driver_online_sessions AS s
      SET ended_at = LEAST(
        pg_catalog.statement_timestamp(),
        s.last_heartbeat_at + interval '90 seconds'
      )
      WHERE s.id = active_id;
    END IF;

    INSERT INTO public.driver_online_sessions (driver_id)
    VALUES (auth.uid())
    RETURNING id INTO new_id;
  END IF;

  UPDATE public.drivers AS d
  SET is_online = true
  WHERE d.user_id = auth.uid();
  PERFORM public.recalculate_driver_availability(auth.uid(), true);

  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.stop_driver_online_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  closed_session boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  PERFORM 1
  FROM public.drivers AS d
  WHERE d.user_id = auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  UPDATE public.driver_online_sessions AS s
  SET ended_at = LEAST(
        pg_catalog.statement_timestamp(),
        s.last_heartbeat_at + interval '90 seconds'
      ),
      last_heartbeat_at = pg_catalog.statement_timestamp()
  WHERE s.driver_id = auth.uid()
    AND s.ended_at IS NULL;
  closed_session := FOUND;

  PERFORM public.recalculate_driver_availability(auth.uid(), true);
  RETURN closed_session;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_driver_offline()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  PERFORM 1
  FROM public.drivers AS d
  WHERE d.user_id = auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  PERFORM public.stop_driver_online_session();
  UPDATE public.drivers AS d
  SET is_online = false,
      is_available = false
  WHERE d.user_id = auth.uid();
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  PERFORM public.recalculate_driver_availability(auth.uid(), true);
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.heartbeat_driver_online_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.driver_online_sessions AS s
  SET last_heartbeat_at = pg_catalog.statement_timestamp()
  WHERE s.driver_id = auth.uid()
    AND s.ended_at IS NULL
    AND s.last_heartbeat_at >= pg_catalog.statement_timestamp() - interval '90 seconds';
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  PERFORM public.recalculate_driver_availability(auth.uid(), true);
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.start_driver_online_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_driver_online_session() TO authenticated;
REVOKE ALL ON FUNCTION public.stop_driver_online_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stop_driver_online_session() TO authenticated;
REVOKE ALL ON FUNCTION public.set_driver_offline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_offline() TO authenticated;
REVOKE ALL ON FUNCTION public.heartbeat_driver_online_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.heartbeat_driver_online_session() TO authenticated;

-- A completed ride always enters the earnings history exactly once. Cash is
-- confirmed only when the ride/payment is marked paid; online payments can
-- remain pending and become confirmed through the payment settlement trigger.
CREATE OR REPLACE FUNCTION public.record_completed_driver_earning()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  settlement text;
BEGIN
  IF NEW.status <> 'completed'
     OR OLD.status = 'completed'
     OR NEW.driver_id IS NULL
     OR NEW.completed_at IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT CASE
    WHEN NEW.payment_status = 'refunded'
      OR EXISTS (
        SELECT 1 FROM public.payments AS p
        WHERE p.ride_id = NEW.id AND p.status = 'refunded'
      ) THEN 'refunded'
    WHEN NEW.payment_status = 'paid'
      OR EXISTS (
        SELECT 1 FROM public.payments AS p
        WHERE p.ride_id = NEW.id AND p.status = 'paid'
      ) THEN 'confirmed'
    ELSE 'pending'
  END INTO settlement;

  INSERT INTO public.driver_earnings (
    id, driver_id, ride_id, gross_amount, commission, net_amount,
    payment_method, settlement_status, created_at
  ) VALUES (
    'earn_' || NEW.id,
    NEW.driver_id,
    NEW.id,
    NEW.fare,
    0,
    NEW.fare,
    NEW.payment_method,
    settlement,
    NEW.completed_at
  )
  ON CONFLICT DO NOTHING;

  IF FOUND THEN
    UPDATE public.drivers AS d
    SET lifetime_earnings = d.lifetime_earnings + NEW.fare
    WHERE d.user_id = NEW.driver_id;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.record_completed_driver_earning() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS rides_record_completed_driver_earning ON public.rides;
CREATE TRIGGER rides_record_completed_driver_earning
  AFTER UPDATE OF status ON public.rides
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.record_completed_driver_earning();

CREATE OR REPLACE FUNCTION public.sync_driver_earning_payment_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status NOT IN ('paid', 'refunded') OR NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.driver_earnings AS e
  SET gross_amount = r.fare,
      commission = 0,
      net_amount = r.fare,
      payment_method = NEW.method,
      settlement_status = CASE WHEN NEW.status = 'paid' THEN 'confirmed' ELSE 'refunded' END,
      created_at = COALESCE(r.completed_at, e.created_at)
  FROM public.rides AS r
  WHERE r.id = NEW.ride_id
    AND r.status = 'completed'
    AND e.ride_id = r.id
    AND e.driver_id = NEW.driver_id;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_driver_earning_payment_status() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS payments_sync_driver_earning_status ON public.payments;
CREATE TRIGGER payments_sync_driver_earning_status
  AFTER INSERT OR UPDATE OF status ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_driver_earning_payment_status();

-- Correct/backfill retained earnings from the canonical completed ride fare
-- and completion timestamp. Passenger profile deletion does not erase rides or
-- driver_earnings rows under the existing retention migration.
UPDATE public.driver_earnings AS e
SET gross_amount = r.fare,
    commission = 0,
    net_amount = r.fare,
    payment_method = r.payment_method,
    settlement_status = CASE
      WHEN r.payment_status = 'refunded'
        OR EXISTS (
          SELECT 1 FROM public.payments AS p
          WHERE p.ride_id = r.id AND p.status = 'refunded'
        ) THEN 'refunded'
      WHEN r.payment_status = 'paid'
        OR EXISTS (
          SELECT 1 FROM public.payments AS p
          WHERE p.ride_id = r.id AND p.status = 'paid'
        ) THEN 'confirmed'
      ELSE 'pending'
    END,
    created_at = r.completed_at
FROM public.rides AS r
WHERE r.id = e.ride_id
  AND r.driver_id = e.driver_id
  AND r.status = 'completed'
  AND r.completed_at IS NOT NULL;

INSERT INTO public.driver_earnings (
  id, driver_id, ride_id, gross_amount, commission, net_amount,
  payment_method, settlement_status, created_at
)
SELECT
  'earn_' || r.id,
  r.driver_id,
  r.id,
  r.fare,
  0,
  r.fare,
  r.payment_method,
  CASE
    WHEN r.payment_status = 'refunded'
      OR EXISTS (
        SELECT 1 FROM public.payments AS p
        WHERE p.ride_id = r.id AND p.status = 'refunded'
      ) THEN 'refunded'
    WHEN r.payment_status = 'paid'
      OR EXISTS (
        SELECT 1 FROM public.payments AS p
        WHERE p.ride_id = r.id AND p.status = 'paid'
      ) THEN 'confirmed'
    ELSE 'pending'
  END,
  r.completed_at
FROM public.rides AS r
WHERE r.status = 'completed'
  AND r.driver_id IS NOT NULL
  AND r.completed_at IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.driver_earnings AS e WHERE e.ride_id = r.id
  )
ON CONFLICT DO NOTHING;

-- Lazily retire unanswered requests once, then reconcile all stored flags
-- against the live session, location and canonical ride state.
DO $$
DECLARE
  driver_record record;
BEGIN
  PERFORM public.expire_unanswered_ride_requests();
  FOR driver_record IN SELECT d.user_id FROM public.drivers AS d LOOP
    PERFORM public.recalculate_driver_availability(driver_record.user_id, false);
  END LOOP;
END;
$$;

-- driver_earnings is already an RLS-protected owner ledger. Ensure it remains
-- in Realtime so the existing Wallet stream refreshes after completion/payment.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_publication AS p
    WHERE p.pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_publication_tables AS pt
    WHERE pt.pubname = 'supabase_realtime'
      AND pt.schemaname = 'public'
      AND pt.tablename = 'driver_earnings'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_earnings';
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
