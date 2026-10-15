CREATE OR REPLACE FUNCTION public.get_pending_driver_applications()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  result json;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin authorization required';
  END IF;

  SELECT coalesce(json_agg(
    json_build_object(
      'driver', d,
      'profile', p
    )
  ), '[]'::json) INTO result
  FROM public.drivers d
  JOIN public.profiles p ON d.user_id = p.id
  WHERE d.application_status = 'pending';

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pending_driver_applications() TO authenticated;
