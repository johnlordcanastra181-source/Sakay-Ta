-- Canonical admin authorization contract for every browser-side admin read.
-- Client applications retain only the publishable key; RLS remains the access
-- boundary. The SECURITY DEFINER functions below read the role registry using
-- the migration owner and never grant table access to anonymous users.

create or replace function public.is_admin(check_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select check_user is not null and exists (
    select 1
    from public.admin_roles ar
    where ar.user_id = check_user
      and ar.status = 'active'
      and ar.role in ('admin', 'super_admin')
  );
$$;

create or replace function public.is_super_admin(check_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select check_user is not null and exists (
    select 1
    from public.admin_roles ar
    where ar.user_id = check_user
      and ar.status = 'active'
      and ar.role = 'super_admin'
  );
$$;

revoke all on function public.is_admin(uuid) from public;
revoke all on function public.is_super_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_super_admin(uuid) to authenticated;

-- The portal invokes this once before rendering protected data. It checks the
-- same public.is_admin() predicate used by the RLS policies, preventing a
-- frontend-only "Super Administrator" label from masking a broken database
-- role mapping.
create or replace function public.admin_dashboard_authorization()
returns table (role text, status text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin(auth.uid()) then
    raise exception 'administrator authorization required';
  end if;

  return query
    select ar.role, ar.status
    from public.admin_roles ar
    where ar.user_id = auth.uid()
      and ar.status = 'active'
      and ar.role in ('admin', 'super_admin');
end;
$$;

revoke all on function public.admin_dashboard_authorization() from public;
grant execute on function public.admin_dashboard_authorization() to authenticated;

-- These are privilege grants only. Row access remains constrained by the
-- existing owner-or-admin SELECT policies that call public.is_admin(). They
-- protect against dashboard-table privilege drift without opening data to
-- anonymous or ordinary authenticated users.
grant select on public.profiles, public.admin_roles, public.passenger_profiles,
  public.drivers, public.driver_documents, public.driver_earnings,
  public.driver_presence, public.rides, public.reports to authenticated;
