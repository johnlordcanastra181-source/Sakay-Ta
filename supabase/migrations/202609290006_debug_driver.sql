CREATE OR REPLACE FUNCTION public.debug_driver()
RETURNS TABLE (
  driver_id uuid,
  application_status public.account_status,
  account_status public.account_status,
  vehicle_type public.vehicle_type,
  latitude double precision,
  longitude double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT d.user_id, d.application_status, p.account_status, presence.vehicle_type, presence.latitude, presence.longitude
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.user_id
  JOIN public.driver_presence presence ON presence.driver_id = d.user_id;
$$;
GRANT EXECUTE ON FUNCTION public.debug_driver TO anon;
