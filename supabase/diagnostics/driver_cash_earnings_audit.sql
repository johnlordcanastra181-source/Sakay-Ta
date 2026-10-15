-- Read-only audit for Admin gross fares vs authenticated Driver cash earnings.
-- Run with: supabase db query --linked --file supabase/diagnostics/driver_cash_earnings_audit.sql

-- 1) Full completed-ride ownership and ledger comparison. drivers.user_id is
-- the canonical Auth UUID in this schema; profiles.id maps to that same UUID.
SELECT
  r.id AS ride_id,
  r.driver_id AS ride_driver_auth_uid,
  d.user_id AS driver_profile_user_id,
  d.firebase_uid AS legacy_firebase_uid,
  (p.id IS NOT NULL) AS auth_profile_exists,
  r.passenger_id,
  r.status AS ride_status,
  r.vehicle_type,
  r.fare::numeric(12, 2) AS final_gross_fare,
  lower(coalesce(r.payment_method, 'unknown')) AS ride_payment_method,
  lower(coalesce(r.payment_status, 'unknown')) AS ride_payment_status,
  r.completed_at,
  EXISTS (
    SELECT 1
    FROM public.payments AS paid
    WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
  ) AS has_paid_payment_record,
  EXISTS (
    SELECT 1
    FROM public.payments AS refunded
    WHERE refunded.ride_id = r.id AND lower(refunded.status) = 'refunded'
  ) AS has_refund_payment_record,
  e.id AS earning_id,
  e.driver_id AS earning_driver_auth_uid,
  e.gross_amount,
  e.commission,
  e.net_amount,
  e.payment_method AS earning_payment_method,
  e.settlement_status AS earning_settlement_status,
  e.created_at AS earning_created_at
FROM public.rides AS r
LEFT JOIN public.drivers AS d ON d.user_id = r.driver_id
LEFT JOIN public.profiles AS p ON p.id = d.user_id
LEFT JOIN public.driver_earnings AS e ON e.ride_id = r.id
WHERE lower(r.status::text) = 'completed'
ORDER BY r.completed_at NULLS LAST, r.id;

-- 2) Admin-side gross and cash-confirmed fare totals by actual ride driver UID.
SELECT
  r.driver_id AS ride_driver_auth_uid,
  lower(coalesce(r.payment_method, 'unknown')) AS payment_method,
  lower(coalesce(r.payment_status, 'unknown')) AS ride_payment_status,
  count(*) AS completed_ride_count,
  sum(r.fare)::numeric(14, 2) AS gross_fares,
  count(*) FILTER (
    WHERE lower(coalesce(r.payment_method, '')) = 'cash'
      AND (
        lower(coalesce(r.payment_status, '')) = 'paid'
        OR EXISTS (
          SELECT 1 FROM public.payments AS paid
          WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
        )
      )
  ) AS confirmed_cash_ride_count,
  coalesce(sum(r.fare) FILTER (
    WHERE lower(coalesce(r.payment_method, '')) = 'cash'
      AND (
        lower(coalesce(r.payment_status, '')) = 'paid'
        OR EXISTS (
          SELECT 1 FROM public.payments AS paid
          WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
        )
      )
  ), 0)::numeric(14, 2) AS confirmed_cash_gross
FROM public.rides AS r
WHERE lower(r.status::text) = 'completed'
GROUP BY r.driver_id, lower(coalesce(r.payment_method, 'unknown')),
         lower(coalesce(r.payment_status, 'unknown'))
ORDER BY r.driver_id NULLS LAST, payment_method, ride_payment_status;

-- 3) Driver-ledger totals; pending/refunded are intentionally separate.
SELECT
  e.driver_id AS earning_driver_auth_uid,
  lower(coalesce(e.payment_method, 'unknown')) AS payment_method,
  lower(coalesce(e.settlement_status, 'unknown')) AS settlement_status,
  count(*) AS earning_row_count,
  count(DISTINCT e.ride_id) AS earning_ride_count,
  sum(e.gross_amount)::numeric(14, 2) AS ledger_gross,
  sum(e.commission)::numeric(14, 2) AS ledger_commission,
  sum(e.net_amount)::numeric(14, 2) AS ledger_net
FROM public.driver_earnings AS e
GROUP BY e.driver_id, lower(coalesce(e.payment_method, 'unknown')),
         lower(coalesce(e.settlement_status, 'unknown'))
ORDER BY e.driver_id NULLS LAST, payment_method, settlement_status;

-- 4) Completed rides whose earning row is missing or disagrees with the ride.
-- This is diagnostic only; it does not insert or update financial records.
SELECT
  r.id AS ride_id,
  r.driver_id AS ride_driver_auth_uid,
  e.id AS earning_id,
  e.driver_id AS earning_driver_auth_uid,
  r.fare::numeric(12, 2) AS ride_gross,
  e.gross_amount AS earning_gross,
  e.net_amount AS earning_net,
  r.payment_method AS ride_payment_method,
  e.payment_method AS earning_payment_method,
  r.payment_status AS ride_payment_status,
  e.settlement_status AS earning_settlement_status,
  r.completed_at,
  CASE
    WHEN lower(coalesce(r.payment_status, '')) = 'refunded'
      OR EXISTS (
        SELECT 1 FROM public.payments AS refunded
        WHERE refunded.ride_id = r.id AND lower(refunded.status) = 'refunded'
      ) THEN 'refunded'
    WHEN lower(coalesce(r.payment_status, '')) = 'paid'
      OR EXISTS (
        SELECT 1 FROM public.payments AS paid
        WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
      ) THEN 'confirmed'
    ELSE 'pending'
  END AS expected_settlement_status
FROM public.rides AS r
LEFT JOIN public.driver_earnings AS e ON e.ride_id = r.id
WHERE lower(r.status::text) = 'completed'
  AND (
    e.id IS NULL
    OR e.driver_id IS DISTINCT FROM r.driver_id
    OR e.gross_amount IS DISTINCT FROM r.fare
    OR lower(coalesce(e.payment_method, ''))
       IS DISTINCT FROM lower(coalesce(r.payment_method, ''))
    OR lower(coalesce(e.settlement_status, '')) IS DISTINCT FROM CASE
      WHEN lower(coalesce(r.payment_status, '')) = 'refunded'
        OR EXISTS (
          SELECT 1 FROM public.payments AS refunded
          WHERE refunded.ride_id = r.id AND lower(refunded.status) = 'refunded'
        ) THEN 'refunded'
      WHEN lower(coalesce(r.payment_status, '')) = 'paid'
        OR EXISTS (
          SELECT 1 FROM public.payments AS paid
          WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
        ) THEN 'confirmed'
      ELSE 'pending'
    END
  )
ORDER BY r.completed_at NULLS LAST, r.id;
