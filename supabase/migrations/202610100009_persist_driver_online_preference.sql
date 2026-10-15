
-- Remove is_online = false from stop_driver_online_session so that it preserves
-- the driver's explicit Online/Offline toggle preference across logins.
CREATE OR REPLACE FUNCTION public.stop_driver_online_session()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  closed boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  UPDATE public.driver_online_sessions
  SET ended_at = LEAST(now(), last_heartbeat_at + interval '90 seconds'),
      last_heartbeat_at = now()
  WHERE driver_id = auth.uid() AND ended_at IS NULL;
  closed := FOUND;

  -- ONLY set is_available = false so the driver is unbookable
  -- DO NOT wipe is_online, as it represents their explicit toggle state.
  UPDATE public.drivers
  SET is_available = false
  WHERE user_id = auth.uid();
  UPDATE public.driver_presence
  SET is_available = false, updated_at = now()
  WHERE driver_id = auth.uid();

  RETURN closed;
END;
$$;

