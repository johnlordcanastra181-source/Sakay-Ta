-- Harden the driver completion boundary.
--
-- A driver can retry after the first transaction committed but before the
-- client received the RPC response.  The original transition function
-- returned false for that retry, which made the client report a failure even
-- though the ride, payment, and earning were already final.  Treating the
-- same driver's completed -> completed request as a successful no-op keeps
-- completion idempotent without incrementing trips or earnings twice.

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

  -- The first request may have committed before its response was received.
  -- Do not repeat counters, history, payment, or earning writes on retry.
  IF current_ride.status = 'completed' AND next_status = 'completed' THEN
    RETURN true;
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

REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status) TO authenticated;
