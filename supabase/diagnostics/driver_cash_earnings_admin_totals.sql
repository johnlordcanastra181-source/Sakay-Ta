-- Read-only Admin-side gross fare and confirmed cash totals by actual ride
-- driver Auth UUID, payment method, and ride payment status.
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
