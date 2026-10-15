CREATE OR REPLACE FUNCTION public.debug_rides()
RETURNS TABLE (
  id text,
  passenger_id uuid,
  driver_id uuid,
  status public.ride_status
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, passenger_id, driver_id, status FROM public.rides WHERE status IN ('searching', 'accepted', 'started', 'arrived');
$$;
GRANT EXECUTE ON FUNCTION public.debug_rides TO anon;
