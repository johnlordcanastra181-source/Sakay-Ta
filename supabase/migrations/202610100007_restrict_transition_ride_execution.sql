-- Restrict the SECURITY DEFINER ride transition RPC to trusted API roles.
-- CREATE OR REPLACE preserves existing ACL entries, so explicitly remove the
-- historical direct grant to anon after installing the corrected function.

REVOKE ALL ON FUNCTION public.transition_ride(text, public.ride_status)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.transition_ride(text, public.ride_status)
  TO authenticated, service_role;
