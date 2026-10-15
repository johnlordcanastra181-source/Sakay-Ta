-- Driver financial/activity reconciliation.
--
-- New ride completion is the authoritative boundary for driver activity:
-- completed rides are counted once, cash completion creates a driver-confirmed
-- cash settlement, and paid online rides are settled once by ride_id.  Legacy
-- rows are not recalculated.

ALTER TABLE public.driver_earnings
  ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'cash';

ALTER TABLE public.driver_earnings
  ADD COLUMN IF NOT EXISTS settlement_status text NOT NULL DEFAULT 'confirmed';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'driver_earnings_settlement_status_check'
      AND conrelid = 'public.driver_earnings'::regclass
  ) THEN
    ALTER TABLE public.driver_earnings
      ADD CONSTRAINT driver_earnings_settlement_status_check
      CHECK (settlement_status IN ('pending', 'confirmed', 'refunded'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS driver_earnings_one_row_per_ride
  ON public.driver_earnings (ride_id)
  WHERE ride_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.driver_online_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(user_id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  last_heartbeat_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_online_sessions_time_check
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS driver_online_sessions_one_open
  ON public.driver_online_sessions (driver_id)
  WHERE ended_at IS NULL;

CREATE INDEX IF NOT EXISTS driver_online_sessions_driver_started_idx
  ON public.driver_online_sessions (driver_id, started_at DESC);

ALTER TABLE public.driver_online_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_online_sessions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_online_sessions_owner_or_admin_read
  ON public.driver_online_sessions;
CREATE POLICY driver_online_sessions_owner_or_admin_read
  ON public.driver_online_sessions
  FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

-- Earnings and ratings are written only by their secure server functions.
-- This prevents a Flutter client from fabricating income or changing a score.
REVOKE INSERT, UPDATE, DELETE ON public.driver_earnings FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.ratings FROM anon, authenticated;
REVOKE ALL ON public.driver_online_sessions FROM anon, authenticated;
GRANT SELECT ON public.driver_online_sessions TO authenticated;

CREATE OR REPLACE FUNCTION public.start_driver_online_session()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  active_id uuid;
  active_heartbeat timestamptz;
  new_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF NOT public.is_approved_driver(auth.uid()) THEN
    RAISE EXCEPTION 'approved driver authorization required';
  END IF;

  SELECT id, last_heartbeat_at
  INTO active_id, active_heartbeat
  FROM public.driver_online_sessions
  WHERE driver_id = auth.uid() AND ended_at IS NULL
  FOR UPDATE;

  IF active_id IS NOT NULL
     AND active_heartbeat >= now() - interval '90 seconds' THEN
    UPDATE public.driver_online_sessions
    SET last_heartbeat_at = now()
    WHERE id = active_id;
    UPDATE public.drivers
    SET is_online = true, is_available = true
    WHERE user_id = auth.uid();
    UPDATE public.driver_presence
    SET is_online = true, is_available = true, updated_at = now()
    WHERE driver_id = auth.uid();
    RETURN active_id;
  END IF;

  IF active_id IS NOT NULL THEN
    UPDATE public.driver_online_sessions
    SET ended_at = LEAST(now(), active_heartbeat + interval '90 seconds')
    WHERE id = active_id;
  END IF;

  INSERT INTO public.driver_online_sessions (driver_id)
  VALUES (auth.uid())
  RETURNING id INTO new_id;

  UPDATE public.drivers
  SET is_online = true, is_available = true
  WHERE user_id = auth.uid();
  UPDATE public.driver_presence
  SET is_online = true, is_available = true, updated_at = now()
  WHERE driver_id = auth.uid();

  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.stop_driver_online_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  closed boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  UPDATE public.driver_online_sessions
  SET ended_at = LEAST(now(), last_heartbeat_at + interval '90 seconds'),
      last_heartbeat_at = now()
  WHERE driver_id = auth.uid() AND ended_at IS NULL;
  closed := FOUND;

  UPDATE public.drivers
  SET is_online = false, is_available = false
  WHERE user_id = auth.uid();
  UPDATE public.driver_presence
  SET is_online = false, is_available = false, updated_at = now()
  WHERE driver_id = auth.uid();

  RETURN closed;
END;
$$;

CREATE OR REPLACE FUNCTION public.heartbeat_driver_online_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.driver_online_sessions
  SET last_heartbeat_at = now()
  WHERE driver_id = auth.uid()
    AND ended_at IS NULL
    AND last_heartbeat_at >= now() - interval '90 seconds';

  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.driver_online_hours_today(target_driver uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  day_start timestamptz;
  day_end timestamptz;
  total_seconds numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF target_driver IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'driver activity authorization required';
  END IF;

  day_start := ((now() AT TIME ZONE 'Asia/Manila')::date::timestamp
    AT TIME ZONE 'Asia/Manila');
  day_end := day_start + interval '1 day';

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (
    LEAST(
      COALESCE(s.ended_at,
        LEAST(now(), s.last_heartbeat_at + interval '90 seconds')),
      day_end
    ) - GREATEST(s.started_at, day_start)
  ))), 0)
  INTO total_seconds
  FROM public.driver_online_sessions s
  WHERE s.driver_id = target_driver
    AND s.started_at < day_end
    AND COALESCE(s.ended_at,
      LEAST(now(), s.last_heartbeat_at + interval '90 seconds')) > day_start;

  RETURN ROUND(GREATEST(total_seconds, 0) / 3600, 2);
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_ride(
  ride_id text,
  next_status public.ride_status
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_ride public.rides%rowtype;
  earning_inserted boolean := false;
BEGIN
  SELECT * INTO current_ride
  FROM public.rides
  WHERE id = ride_id
  FOR UPDATE;

  IF NOT FOUND OR current_ride.driver_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;
  IF NOT (
    (current_ride.status = 'accepted' AND next_status = 'arrived') OR
    (current_ride.status = 'arrived' AND next_status = 'started') OR
    (current_ride.status = 'started' AND next_status = 'completed')
  ) THEN
    RETURN false;
  END IF;

  UPDATE public.rides
  SET
    status = next_status,
    commission = CASE WHEN next_status = 'completed' THEN 0 ELSE commission END,
    driver_net = CASE WHEN next_status = 'completed' THEN fare ELSE driver_net END,
    payment_status = CASE
      WHEN next_status = 'completed' AND payment_method = 'cash' THEN 'paid'
      ELSE payment_status
    END,
    arrived_at = CASE WHEN next_status = 'arrived' THEN now() ELSE arrived_at END,
    started_at = CASE WHEN next_status = 'started' THEN now() ELSE started_at END,
    completed_at = CASE WHEN next_status = 'completed' THEN now() ELSE completed_at END,
    updated_at = now()
  WHERE id = ride_id;

  IF next_status = 'completed' THEN
    UPDATE public.drivers
    SET is_available = is_online, total_trips = total_trips + 1
    WHERE user_id = auth.uid();
    UPDATE public.driver_presence
    SET is_available = is_online, updated_at = now()
    WHERE driver_id = auth.uid();
    UPDATE public.passenger_profiles
    SET ride_count = ride_count + 1
    WHERE user_id = current_ride.passenger_id;

    -- Completing a cash ride is the driver's explicit cash-collection
    -- confirmation. No platform commission is retained.
    IF current_ride.payment_method = 'cash' THEN
      INSERT INTO public.payments AS existing_payment (
        id, ride_id, passenger_id, driver_id, amount, platform_fee, driver_net,
        method, status, metadata, created_at, paid_at, updated_at
      ) VALUES (
        'pay_' || ride_id, ride_id, current_ride.passenger_id, auth.uid(),
        current_ride.fare, 0, current_ride.fare, 'cash', 'paid',
        jsonb_build_object('settlement', 'driver_confirmed_cash'),
        now(), now(), now()
      )
      ON CONFLICT (ride_id) DO UPDATE SET
        status = 'paid',
        platform_fee = 0,
        driver_net = EXCLUDED.driver_net,
        method = 'cash',
        paid_at = COALESCE(existing_payment.paid_at, now()),
        updated_at = now(),
        metadata = existing_payment.metadata || EXCLUDED.metadata;

      INSERT INTO public.driver_earnings (
        id, driver_id, ride_id, gross_amount, commission, net_amount,
        payment_method, settlement_status, created_at
      ) VALUES (
        'earn_' || ride_id, auth.uid(), ride_id, current_ride.fare, 0,
        current_ride.fare, 'cash', 'confirmed', now()
      )
      ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL DO NOTHING;
      earning_inserted := FOUND;
    ELSIF current_ride.payment_status = 'paid' THEN
      INSERT INTO public.driver_earnings (
        id, driver_id, ride_id, gross_amount, commission, net_amount,
        payment_method, settlement_status, created_at
      ) VALUES (
        'earn_' || ride_id, auth.uid(), ride_id, current_ride.fare, 0,
        current_ride.fare, current_ride.payment_method, 'confirmed', now()
      )
      ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL DO NOTHING;
      earning_inserted := FOUND;
    END IF;

    IF earning_inserted THEN
      UPDATE public.drivers
      SET lifetime_earnings = lifetime_earnings + current_ride.fare
      WHERE user_id = auth.uid();
    END IF;
  END IF;

  INSERT INTO public.ride_status_history (ride_id, from_status, to_status, changed_by)
  VALUES (ride_id, current_ride.status, next_status, auth.uid());
  RETURN true;
END;
$$;

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
  current_ride public.rides%rowtype;
  earning_inserted boolean := false;
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

  SELECT * INTO current_ride
  FROM public.rides
  WHERE id = settle_ride_payment.ride_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  IF current_payment.status <> 'paid' THEN
    UPDATE public.payments
    SET status = 'paid',
        platform_fee = 0,
        driver_net = amount,
        paid_at = now(),
        provider_reference = settle_ride_payment.provider_reference,
        updated_at = now()
    WHERE id = payment_id;
  END IF;

  UPDATE public.rides
  SET payment_status = 'paid', commission = 0, driver_net = fare, updated_at = now()
  WHERE id = settle_ride_payment.ride_id;

  IF current_ride.status = 'completed' AND current_payment.driver_id IS NOT NULL THEN
    INSERT INTO public.driver_earnings (
      id, driver_id, ride_id, gross_amount, commission, net_amount,
      payment_method, settlement_status, created_at
    ) VALUES (
      'earn_' || settle_ride_payment.ride_id,
      current_payment.driver_id,
      settle_ride_payment.ride_id,
      current_ride.fare,
      0,
      current_ride.fare,
      current_payment.method,
      'confirmed',
      COALESCE(current_ride.completed_at, now())
    )
    ON CONFLICT (ride_id) WHERE ride_id IS NOT NULL DO NOTHING;
    earning_inserted := FOUND;

    IF earning_inserted THEN
      UPDATE public.drivers
      SET lifetime_earnings = lifetime_earnings + current_ride.fare
      WHERE user_id = current_payment.driver_id;
    END IF;
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_ride_rating(
  target_ride text,
  target_rating smallint,
  target_comment text DEFAULT NULL
)
RETURNS public.ratings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_ride public.rides%rowtype;
  existing_rating public.ratings%rowtype;
  result public.ratings%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF target_rating < 1 OR target_rating > 5 THEN
    RAISE EXCEPTION 'rating must be between 1 and 5';
  END IF;

  SELECT * INTO current_ride
  FROM public.rides
  WHERE id = target_ride;
  IF NOT FOUND
     OR current_ride.passenger_id <> auth.uid()
     OR current_ride.driver_id IS NULL
     OR current_ride.status <> 'completed' THEN
    RAISE EXCEPTION 'only the passenger can rate a completed ride';
  END IF;

  SELECT * INTO existing_rating
  FROM public.ratings
  WHERE ride_id = target_ride;
  IF FOUND THEN
    RETURN existing_rating;
  END IF;

  INSERT INTO public.ratings (
    id, ride_id, passenger_id, driver_id, rating, comment, created_at
  ) VALUES (
    'rating_' || target_ride,
    target_ride,
    auth.uid(),
    current_ride.driver_id,
    target_rating,
    NULLIF(BTRIM(target_comment), ''),
    now()
  )
  ON CONFLICT (ride_id) DO NOTHING
  RETURNING * INTO result;

  IF result.id IS NULL THEN
    SELECT * INTO result FROM public.ratings WHERE ride_id = target_ride;
  END IF;
  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.start_driver_online_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_driver_online_session() TO authenticated;
REVOKE ALL ON FUNCTION public.stop_driver_online_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.stop_driver_online_session() TO authenticated;
REVOKE ALL ON FUNCTION public.heartbeat_driver_online_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.heartbeat_driver_online_session() TO authenticated;
REVOKE ALL ON FUNCTION public.driver_online_hours_today(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_online_hours_today(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status) TO authenticated;
REVOKE ALL ON FUNCTION public.settle_ride_payment(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_ride_payment(text, text, text)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.submit_ride_rating(text, smallint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_ride_rating(text, smallint, text) TO authenticated;

DO $$
DECLARE
  table_name text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH table_name IN ARRAY ARRAY[
      'driver_earnings', 'withdrawals', 'ratings', 'driver_online_sessions'
    ] LOOP
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = table_name
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          table_name
        );
      END IF;
    END LOOP;
  END IF;
END $$;
