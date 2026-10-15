CREATE OR REPLACE FUNCTION public.debug_get_rides()
RETURNS SETOF public.rides
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM public.rides;
$$;
GRANT EXECUTE ON FUNCTION public.debug_get_rides TO anon;
