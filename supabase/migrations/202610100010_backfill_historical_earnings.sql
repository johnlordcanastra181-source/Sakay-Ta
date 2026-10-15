
-- Backfill driver_earnings for older completed rides that missed them due to previous RPC logic
INSERT INTO public.driver_earnings (id, ride_id, driver_id, gross_amount, commission, net_amount, payment_method, settlement_status, created_at)
SELECT gen_random_uuid()::text, r.id, r.driver_id, r.fare, 0, r.fare, r.payment_method,
  CASE WHEN r.payment_method = 'cash' THEN 'confirmed' ELSE 'pending' END,
  COALESCE(r.completed_at, r.created_at)
FROM public.rides r
WHERE r.status = 'completed'
  AND r.driver_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.driver_earnings de WHERE de.ride_id = r.id
  );

