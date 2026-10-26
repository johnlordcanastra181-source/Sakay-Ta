-- Optimize History Page and Driver/Passenger Wallet query performance.
-- Adds missing composite indexes for rides, driver_earnings, withdrawals, and payments,
-- and provides a batch RPC to resolve driver display info for ride history & receipts
-- without N+1 queries or RLS denials.

CREATE INDEX IF NOT EXISTS rides_passenger_status_created_idx
  ON public.rides (passenger_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS rides_driver_status_created_idx
  ON public.rides (driver_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS driver_earnings_driver_created_idx
  ON public.driver_earnings (driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS driver_earnings_driver_status_created_idx
  ON public.driver_earnings (driver_id, settlement_status, created_at DESC);

CREATE INDEX IF NOT EXISTS withdrawals_driver_requested_idx
  ON public.withdrawals (driver_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS payments_passenger_created_idx
  ON public.payments (passenger_id, created_at DESC);

CREATE INDEX IF NOT EXISTS payments_driver_created_idx
  ON public.payments (driver_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.get_ride_driver_display_info(
  target_driver_ids uuid[]
)
RETURNS TABLE (
  driver_id uuid,
  full_name text,
  plate_number text,
  vehicle_type text,
  profile_photo_path text,
  avatar_color integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF target_driver_ids IS NULL OR pg_catalog.array_length(target_driver_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id AS driver_id,
    COALESCE(p.full_name, '') AS full_name,
    COALESCE(d.plate_number, dp.plate_number, '') AS plate_number,
    COALESCE(d.vehicle_type::text, dp.vehicle_type::text, '') AS vehicle_type,
    p.profile_photo_path,
    COALESCE(p.avatar_color, 0) AS avatar_color
  FROM public.profiles AS p
  LEFT JOIN public.drivers AS d ON d.user_id = p.id
  LEFT JOIN public.driver_presence AS dp ON dp.driver_id = p.id
  WHERE p.id = ANY(target_driver_ids)
    AND (
      p.id = auth.uid()
      OR public.is_admin()
      OR d.application_status IN ('approved', 'active')
      OR EXISTS (
        SELECT 1
        FROM public.rides AS r
        WHERE r.driver_id = p.id
          AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_ride_driver_display_info(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ride_driver_display_info(uuid[]) TO authenticated;

