-- Read-only diagnostic: completed rides with a missing or inconsistent
-- driver_earnings row. An empty result means no mismatches under these checks.
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
