-- Drop the insecure policies that allowed any admin to insert/update
DROP POLICY IF EXISTS admin_roles_admin_insert ON public.admin_roles;
DROP POLICY IF EXISTS admin_roles_admin_update ON public.admin_roles;

-- Create hardened policies requiring super_admin for any modifications
CREATE POLICY admin_roles_super_admin_insert ON public.admin_roles
  FOR INSERT TO authenticated WITH CHECK (public.is_super_admin());

CREATE POLICY admin_roles_super_admin_update ON public.admin_roles
  FOR UPDATE TO authenticated USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

