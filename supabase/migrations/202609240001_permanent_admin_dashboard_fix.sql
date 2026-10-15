-- ============================================================
-- PERMANENT ADMIN DASHBOARD FIX
-- 202609240001_permanent_admin_dashboard_fix.sql
--
-- Root causes addressed:
--
-- 1. Migration 202609230003 set `role = 'superadmin'` in is_super_admin()
--    but the DB CHECK constraint only allows 'super_admin' (with underscore).
--    This caused is_super_admin() to always return false, and if any RLS
--    policy calls is_super_admin(), those policies silently fail.
--
-- 2. Missing GRANT SELECT on core tables (passenger_profiles, rides, etc.)
--    caused PostgREST to return 404 Not Found for COUNT(*) queries, which
--    the Dart client surfaced as the "Unable to load this data" error.
--
-- 3. adminHealthOnce() Dart check `rows.length != 1` was too strict —
--    an admin with multiple role entries would fail. Fixed on Dart side.
--    This migration repairs the DB side by ensuring the RPC always returns
--    exactly what the auth contract expects.
--
-- This migration is IDEMPOTENT — safe to run multiple times.
-- ============================================================

-- ── 1. Repair is_admin() ─────────────────────────────────────────────────────
-- Uses LANGUAGE SQL STABLE SECURITY DEFINER to avoid per-row VOLATILE
-- function evaluation overhead on large tables (rides, drivers, etc.).
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

-- ── 2. Repair is_super_admin() ───────────────────────────────────────────────
-- Migration 202609230003 used 'superadmin' (wrong). Correct value is 'super_admin'.
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

-- ── 3. Repair admin_dashboard_authorization() RPC ───────────────────────────
create or replace function public.admin_dashboard_authorization()
returns table (role text, status text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin(auth.uid()) then
    raise exception 'administrator authorization required'
      using errcode = 'insufficient_privilege';
  end if;

  return query
    select ar.role, ar.status
    from public.admin_roles ar
    where ar.user_id = auth.uid()
      and ar.status = 'active'
      and ar.role in ('admin', 'super_admin');
end;
$$;

-- ── 4. Ensure function execute permissions are correct ───────────────────────
revoke all on function public.is_admin(uuid) from public;
revoke all on function public.is_super_admin(uuid) from public;
revoke all on function public.admin_dashboard_authorization() from public;

grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_super_admin(uuid) to authenticated;
grant execute on function public.admin_dashboard_authorization() to authenticated;

-- ── 5. Grant SELECT on all admin-readable tables ────────────────────────────
-- PostgREST returns 404 (not 403) when SELECT is not granted at the table
-- level, even when an RLS policy would allow the row. The grant here is a
-- privilege grant only — row visibility is still controlled by RLS policies
-- (which call is_admin()). Ordinary authenticated users cannot read rows
-- belonging to other users because RLS denies them.
grant select on
  public.profiles,
  public.admin_roles,
  public.passenger_profiles,
  public.drivers,
  public.driver_documents,
  public.driver_earnings,
  public.driver_presence,
  public.rides,
  public.reports,
  public.payments,
  public.withdrawals,
  public.toda_associations,
  public.fare_config,
  public.notifications
to authenticated;

-- ── 6. Ensure RLS policies for admin SELECT exist ───────────────────────────
-- These are CREATE IF NOT EXISTS equivalents. We use DO blocks to skip
-- creation if the policy already exists, making this idempotent.

do $$
begin
  -- passenger_profiles: admin can select all rows
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'passenger_profiles'
      and policyname = 'passenger_profiles_admin_all'
  ) then
    execute $pol$
      create policy passenger_profiles_admin_all on public.passenger_profiles
      for all to authenticated
      using (public.is_admin())
      with check (public.is_admin())
    $pol$;
  end if;

  -- rides: admin can select all rides
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'rides'
      and policyname = 'rides_participant_or_admin_select'
  ) then
    execute $pol$
      create policy rides_participant_or_admin_select on public.rides
      for select to authenticated
      using (
        passenger_id = auth.uid()
        or driver_id = auth.uid()
        or public.is_admin()
      )
    $pol$;
  end if;

  -- driver_earnings: admin can select all
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'driver_earnings'
      and policyname = 'driver_earnings_admin_select'
  ) then
    execute $pol$
      create policy driver_earnings_admin_select on public.driver_earnings
      for select to authenticated
      using (driver_id = auth.uid() or public.is_admin())
    $pol$;
  end if;

  -- driver_presence: admin can select
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'driver_presence'
      and policyname = 'driver_presence_admin_select'
  ) then
    execute $pol$
      create policy driver_presence_admin_select on public.driver_presence
      for select to authenticated
      using (driver_id = auth.uid() or public.is_admin())
    $pol$;
  end if;

  -- reports: admin can select all
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'reports_admin_select'
  ) then
    execute $pol$
      create policy reports_admin_select on public.reports
      for select to authenticated
      using (reporter_id = auth.uid() or public.is_admin())
    $pol$;
  end if;

end;
$$;

