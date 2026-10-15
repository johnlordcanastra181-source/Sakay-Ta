-- Reconcile five specifically identified historical cash rides that the
-- driver confirmed were collected. This is intentionally not a general rule
-- for every completed/unpaid cash ride.
--
-- Expected reconciliation: 5 rides, PHP 210.20 total. The guarded, idempotent
-- update also preserves the original completion time and never increments
-- drivers.lifetime_earnings (the earning rows already exist).
DO $$
DECLARE
  target_driver_id constant uuid := 'd0790549-c9be-4dfa-b47a-da1564dc79d8';
  verified_ride_count integer;
  affected_ride record;
  updated_earning_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers AS d
    WHERE d.user_id = target_driver_id
  ) THEN
    RAISE EXCEPTION 'Historical cash reconciliation aborted: expected driver is missing';
  END IF;

  WITH expected(ride_id, fare) AS (
    VALUES
      ('fa427388-aa6d-4b51-96c8-aab90923c6ed'::text, 20.00::numeric),
      ('55cc5b8f-f465-43db-9ba4-1b634e198216'::text, 15.00::numeric),
      ('2482ea40-6234-4103-b867-7c5b51a0fa96'::text, 65.00::numeric),
      ('d9d8ddff-ab35-45da-890a-601679a39b21'::text, 15.00::numeric),
      ('fb802866-9521-4ccd-926b-51d94b9a7c57'::text, 95.20::numeric)
  )
  SELECT count(DISTINCT expected.ride_id)::integer
  INTO verified_ride_count
  FROM expected
  JOIN public.rides AS r ON r.id = expected.ride_id
  JOIN public.driver_earnings AS e ON e.ride_id = r.id
  WHERE r.driver_id = target_driver_id
    AND r.status = 'completed'
    AND lower(coalesce(r.payment_method, '')) = 'cash'
    AND r.payment_status IN ('unpaid', 'paid')
    AND r.completed_at IS NOT NULL
    AND r.fare = expected.fare
    AND e.driver_id = target_driver_id
    AND e.gross_amount = expected.fare
    AND e.commission = 0
    AND e.net_amount = expected.fare
    AND lower(coalesce(e.payment_method, '')) = 'cash'
    AND lower(coalesce(e.settlement_status, '')) IN ('pending', 'confirmed')
    AND NOT EXISTS (
      SELECT 1
      FROM public.payments AS p
      WHERE p.ride_id = r.id
        AND (
          p.status = 'refunded'
          OR lower(coalesce(p.method, '')) <> 'cash'
          OR p.amount IS DISTINCT FROM expected.fare
          OR (p.driver_id IS NOT NULL AND p.driver_id <> target_driver_id)
        )
    );

  IF verified_ride_count <> 5 THEN
    RAISE EXCEPTION
      'Historical cash reconciliation aborted: expected 5 exact ride/ledger matches, verified %',
      verified_ride_count;
  END IF;

  FOR affected_ride IN
    SELECT expected.ride_id, expected.fare
    FROM (VALUES
      ('fa427388-aa6d-4b51-96c8-aab90923c6ed'::text, 20.00::numeric),
      ('55cc5b8f-f465-43db-9ba4-1b634e198216'::text, 15.00::numeric),
      ('2482ea40-6234-4103-b867-7c5b51a0fa96'::text, 65.00::numeric),
      ('d9d8ddff-ab35-45da-890a-601679a39b21'::text, 15.00::numeric),
      ('fb802866-9521-4ccd-926b-51d94b9a7c57'::text, 95.20::numeric)
    ) AS expected(ride_id, fare)
  LOOP
    UPDATE public.rides AS r
    SET payment_status = 'paid',
        commission = 0,
        driver_net = affected_ride.fare,
        updated_at = now()
    WHERE r.id = affected_ride.ride_id
      AND r.driver_id = target_driver_id
      AND r.status = 'completed'
      AND lower(coalesce(r.payment_method, '')) = 'cash'
      AND r.fare = affected_ride.fare;

    INSERT INTO public.payments AS target_payment (
      id, ride_id, passenger_id, driver_id, amount, platform_fee, driver_net,
      method, status, metadata, created_at, paid_at, updated_at
    )
    SELECT
      coalesce(prior_payment.id, 'pay_' || r.id),
      r.id,
      r.passenger_id,
      target_driver_id,
      r.fare,
      0,
      r.fare,
      'cash',
      'paid',
      coalesce(prior_payment.metadata, '{}'::jsonb) ||
        jsonb_build_object(
          'settlement', 'driver_confirmed_cash',
          'reconciliation', 'user_confirmed_historical_cash',
          'reconciled_at', now()
        ),
      coalesce(prior_payment.created_at, now()),
      coalesce(prior_payment.paid_at, r.completed_at),
      now()
    FROM public.rides AS r
    LEFT JOIN public.payments AS prior_payment ON prior_payment.ride_id = r.id
    WHERE r.id = affected_ride.ride_id
      AND r.driver_id = target_driver_id
      AND r.status = 'completed'
      AND lower(coalesce(r.payment_method, '')) = 'cash'
      AND r.fare = affected_ride.fare
    ON CONFLICT (ride_id) DO UPDATE
    SET passenger_id = coalesce(EXCLUDED.passenger_id, target_payment.passenger_id),
        driver_id = EXCLUDED.driver_id,
        amount = EXCLUDED.amount,
        platform_fee = 0,
        driver_net = EXCLUDED.driver_net,
        method = 'cash',
        status = 'paid',
        metadata = coalesce(target_payment.metadata, '{}'::jsonb) ||
          jsonb_build_object(
            'settlement', 'driver_confirmed_cash',
            'reconciliation', 'user_confirmed_historical_cash',
            'reconciled_at', now()
          ),
        paid_at = coalesce(target_payment.paid_at, EXCLUDED.paid_at),
        updated_at = now();

    UPDATE public.driver_earnings AS e
    SET gross_amount = affected_ride.fare,
        commission = 0,
        net_amount = affected_ride.fare,
        payment_method = 'cash',
        settlement_status = 'confirmed'
    WHERE e.ride_id = affected_ride.ride_id
      AND e.driver_id = target_driver_id
      AND e.gross_amount = affected_ride.fare
      AND e.net_amount = affected_ride.fare
      AND e.commission = 0;

    GET DIAGNOSTICS updated_earning_count = ROW_COUNT;
    IF updated_earning_count <> 1 THEN
      RAISE EXCEPTION
        'Historical cash reconciliation aborted: expected one earning update for ride %, got %',
        affected_ride.ride_id,
        updated_earning_count;
    END IF;
  END LOOP;

  WITH expected(ride_id, fare) AS (
    VALUES
      ('fa427388-aa6d-4b51-96c8-aab90923c6ed'::text, 20.00::numeric),
      ('55cc5b8f-f465-43db-9ba4-1b634e198216'::text, 15.00::numeric),
      ('2482ea40-6234-4103-b867-7c5b51a0fa96'::text, 65.00::numeric),
      ('d9d8ddff-ab35-45da-890a-601679a39b21'::text, 15.00::numeric),
      ('fb802866-9521-4ccd-926b-51d94b9a7c57'::text, 95.20::numeric)
  )
  SELECT count(*)::integer
  INTO verified_ride_count
  FROM expected
  JOIN public.rides AS r ON r.id = expected.ride_id
  JOIN public.payments AS p ON p.ride_id = r.id
  JOIN public.driver_earnings AS e ON e.ride_id = r.id
  WHERE r.driver_id = target_driver_id
    AND r.status = 'completed'
    AND r.payment_status = 'paid'
    AND p.driver_id = target_driver_id
    AND p.method = 'cash'
    AND p.status = 'paid'
    AND p.amount = expected.fare
    AND e.driver_id = target_driver_id
    AND e.settlement_status = 'confirmed'
    AND e.gross_amount = expected.fare
    AND e.net_amount = expected.fare
    AND e.commission = 0;

  IF verified_ride_count <> 5 THEN
    RAISE EXCEPTION
      'Historical cash reconciliation verification failed: expected 5 reconciled rides, found %',
      verified_ride_count;
  END IF;
END;
$$;
