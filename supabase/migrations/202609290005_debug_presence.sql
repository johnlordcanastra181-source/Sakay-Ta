CREATE OR REPLACE FUNCTION public.debug_presence()
RETURNS TABLE (
  driver_id uuid,
  vehicle_type public.vehicle_type,
  is_online boolean,
  is_available boolean,
  latitude double precision,
  longitude double precision,
  last_location_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT driver_id, vehicle_type, is_online, is_available, latitude, longitude, last_location_at
  FROM public.driver_presence;
$$;
GRANT EXECUTE ON FUNCTION public.debug_presence TO anon;
