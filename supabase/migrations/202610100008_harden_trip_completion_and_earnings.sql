-- Migration 202610100008: Hard fix PostgreSQL error 42702 (ambiguous ride_id)
-- Resolves any potential PL/pgSQL variable/column collision in transition_ride
-- and settle_ride_payment. Fully qualifies all table columns with table aliases,
-- copies parameters to clearly named local variables, sets #variable_conflict use_column,
-- and ensures driver earnings, driver availability, trips counter, and payments are
-- authoritatively recorded once and only once.

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
BEGIN
  p_ride_id := ride_id;
  p_next_status := next_status;

  IF p_ride_id IS NULL OR pg_catalog.btrim(p_ride_id) = '' THEN
    RETURN false;
  END IF;

  SELECT r.* INTO current_ride
  FROM public.rides AS r
  WHERE r.id = p_ride_id
  FOR UPDATE;

  IF NOT FOUND OR current_ride.driver_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;

  -- Idempotency: A committed completion retried by the driver returns true
  -- without re-incrementing counters or duplicate earnings.
  IF current_ride.status = 'completed' AND p_next_status = 'completed' THEN
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
    commission = CASE
      WHEN p_next_status = 'completed' THEN 0
      ELSE r.commission
    END,
    driver_net = CASE
      WHEN p_next_status = 'completed' THEN r.fare
      ELSE r.driver_net
    END,
    payment_status = CASE
      WHEN p_next_status = 'completed' AND r.payment_method = 'cash'
        THEN 'paid'
      ELSE r.payment_status
    END,
    arrived_at = CASE
      WHEN p_next_status = 'arrived' THEN pg_catalog.now()
      ELSE r.arrived_at
    END,
    started_at = CASE
      WHEN p_next_status = 'started' THEN pg_catalog.now()
      ELSE r.started_at
    END,
    completed_at = CASE
      WHEN p_next_status = 'completed' THEN pg_catalog.now()
      ELSE r.completed_at
    END,
    updated_at = pg_catalog.now()
  WHERE r.id = p_ride_id;

  IF p_next_status = 'completed' THEN
    UPDATE public.drivers AS d
    SET
      is_available = d.is_online,
      total_trips = d.total_trips + 1
    WHERE d.user_id = auth.uid();

    UPDATE public.driver_presence AS dp
    SET
      is_available = dp.is_online,
      updated_at = pg_catalog.now()
    WHERE dp.driver_id = auth.uid();

    UPDATE public.passenger_profiles AS pp
    SET ride_count = pp.ride_count + 1
    WHERE pp.user_id = current_ride.passenger_id;

    -- Cash completion is the driver's explicit cash collection confirmation
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
        updated_at = pg_catalog.now(),
        metadata = COALESCE(p.metadata, '{}'::jsonb) ||
          pg_catalog.jsonb_build_object('settlement', 'driver_confirmed_cash')
      WHERE p.ride_id = p_ride_id;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Unable to reconcile payment for ride %', p_ride_id;
      END IF;

      -- Check and record driver earnings uniquely
      SELECT e.id INTO existing_earning_id
      FROM public.driver_earnings AS e
      WHERE e.ride_id = p_ride_id;

      IF existing_earning_id IS NULL THEN
        INSERT INTO public.driver_earnings (
          id, driver_id, ride_id, gross_amount, commission, net_amount,
          payment_method, settlement_status, created_at
        ) VALUES (
          'earn_' || p_ride_id,
          auth.uid(),
          p_ride_id,
          current_ride.fare,
          0,
          current_ride.fare,
          'cash',
          'confirmed',
          pg_catalog.now()
        )
        ON CONFLICT DO NOTHING;
        earning_inserted := FOUND;
      END IF;

    ELSIF current_ride.payment_status = 'paid' THEN
      SELECT e.id INTO existing_earning_id
      FROM public.driver_earnings AS e
      WHERE e.ride_id = p_ride_id;

      IF existing_earning_id IS NULL THEN
        INSERT INTO public.driver_earnings (
          id, driver_id, ride_id, gross_amount, commission, net_amount,
          payment_method, settlement_status, created_at
        ) VALUES (
          'earn_' || p_ride_id,
          auth.uid(),
          p_ride_id,
          current_ride.fare,
          0,
          current_ride.fare,
          current_ride.payment_method,
          'confirmed',
          pg_catalog.now()
        )
        ON CONFLICT DO NOTHING;
        earning_inserted := FOUND;
      END IF;
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
    p_ride_id,
    current_ride.status,
    p_next_status,
    auth.uid()
  );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.settle_ride_payment(
  payment_id text,
  ride_id text,
  provider_reference text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
#variable_conflict use_column
DECLARE
  p_payment_id text;
  p_ride_id text;
  p_provider_ref text;
  current_payment public.payments%rowtype;
  current_ride public.rides%rowtype;
  earning_inserted boolean := false;
  existing_earning_id text;
BEGIN
  p_payment_id := payment_id;
  p_ride_id := ride_id;
  p_provider_ref := provider_reference;

  IF auth.role() <> 'service_role' AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'trusted server or admin authorization required';
  END IF;

  SELECT p.* INTO current_payment
  FROM public.payments AS p
  WHERE p.id = p_payment_id
    AND p.ride_id = p_ride_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  SELECT r.* INTO current_ride
  FROM public.rides AS r
  WHERE r.id = p_ride_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  IF current_payment.status <> 'paid' THEN
    UPDATE public.payments AS p
    SET
      status = 'paid',
      platform_fee = 0,
      driver_net = current_payment.amount,
      paid_at = pg_catalog.now(),
      provider_reference = p_provider_ref,
      updated_at = pg_catalog.now()
    WHERE p.id = p_payment_id;
  END IF;

  UPDATE public.rides AS r
  SET
    payment_status = 'paid',
    commission = 0,
    driver_net = current_ride.fare,
    updated_at = pg_catalog.now()
  WHERE r.id = p_ride_id;

  IF current_ride.status = 'completed' AND current_payment.driver_id IS NOT NULL THEN
    SELECT e.id INTO existing_earning_id
    FROM public.driver_earnings AS e
    WHERE e.ride_id = p_ride_id;

    IF existing_earning_id IS NULL THEN
      INSERT INTO public.driver_earnings (
        id, driver_id, ride_id, gross_amount, commission, net_amount,
        payment_method, settlement_status, created_at
      ) VALUES (
        'earn_' || p_ride_id,
        current_payment.driver_id,
        p_ride_id,
        current_ride.fare,
        0,
        current_ride.fare,
        current_payment.method,
        'confirmed',
        COALESCE(current_ride.completed_at, pg_catalog.now())
      )
      ON CONFLICT DO NOTHING;
      earning_inserted := FOUND;

      IF earning_inserted THEN
        UPDATE public.drivers AS d
        SET lifetime_earnings = d.lifetime_earnings + current_ride.fare
        WHERE d.user_id = current_payment.driver_id;
      END IF;
    END IF;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.settle_ride_payment(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.settle_ride_payment(text, text, text) TO service_role;

NOTIFY pgrst, 'reload schema';

