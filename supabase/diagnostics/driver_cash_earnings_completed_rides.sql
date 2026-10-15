-- Read-only ride-level audit of completed fares, driver ownership, payment
-- confirmation, and matching driver_earnings rows.
SELECT
  r.id AS ride_id,
  r.driver_id AS ride_driver_auth_uid,
  d.user_id AS driver_profile_user_id,
  d.firebase_uid AS legacy_firebase_uid,
  (p.id IS NOT NULL) AS auth_profile_exists,
  r.status::text AS ride_status,
  r.vehicle_type,
  r.fare::numeric(12, 2) AS final_gross_fare,
  lower(coalesce(r.payment_method, 'unknown')) AS ride_payment_method,
  lower(coalesce(r.payment_status, 'unknown')) AS ride_payment_status,
  r.completed_at,
  EXISTS (
    SELECT 1 FROM public.payments AS paid
    WHERE paid.ride_id = r.id AND lower(paid.status) = 'paid'
  ) AS has_paid_payment_record,
  EXISTS (
    SELECT 1 FROM public.payments AS refunded
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
