-- Optimize RLS functions to be STABLE instead of VOLATILE (default).
-- Volatile functions are evaluated once per row, which causes massive timeouts 
-- when counting rows in tables with thousands of records (e.g. rides, drivers).
-- STABLE allows Postgres to evaluate the function once per query, preventing the Admin Portal from crashing.

CREATE OR REPLACE FUNCTION public.is_admin(check_user uuid DEFAULT auth.uid())
RETURNS boolean AS $$
DECLARE
  is_admin boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.admin_roles
    WHERE user_id = check_user AND status = 'active'
  ) INTO is_admin;
  RETURN is_admin;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_super_admin(check_user uuid DEFAULT auth.uid())
RETURNS boolean AS $$
DECLARE
  is_super boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.admin_roles
    WHERE user_id = check_user AND status = 'active' AND role = 'superadmin'
  ) INTO is_super;
  RETURN is_super;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

