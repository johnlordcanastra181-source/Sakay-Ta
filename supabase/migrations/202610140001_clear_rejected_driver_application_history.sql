-- Migration: 202610140001_clear_rejected_driver_application_history.sql
-- Description: Add soft-clear columns and RPCs for Rejected Driver Application History

-- 1. Add nullable soft-clear columns to driver_applications table
alter table public.driver_applications
  add column if not exists history_cleared_at timestamptz,
  add column if not exists history_cleared_by uuid references public.profiles(id) on delete set null;

create index if not exists driver_applications_rejected_history_idx
  on public.driver_applications (status, submitted_at desc)
  where history_cleared_at is null;

-- 2. Add nullable soft-clear columns to drivers table (legacy applications)
alter table public.drivers
  add column if not exists history_cleared_at timestamptz,
  add column if not exists history_cleared_by uuid references public.profiles(id) on delete set null;

create index if not exists drivers_rejected_history_idx
  on public.drivers (application_status, submitted_at desc)
  where history_cleared_at is null;

-- 3. Function to clear an individual rejected application from history
create or replace function public.clear_rejected_driver_application(p_application_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  target_uuid uuid;
  cleared boolean := false;
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;

  begin
    target_uuid := p_application_id::uuid;
  exception when others then
    return false;
  end;

  -- 1. Try updating driver_applications (new secure workflow)
  update public.driver_applications
  set history_cleared_at = now(),
      history_cleared_by = auth.uid()
  where id = target_uuid
    and status = 'rejected'
    and history_cleared_at is null;
  cleared := found;

  -- 2. If not found, try updating drivers (legacy workflow)
  if not cleared then
    update public.drivers
    set history_cleared_at = now(),
        history_cleared_by = auth.uid()
    where user_id = target_uuid
      and application_status = 'rejected'
      and history_cleared_at is null;
    cleared := found;
  end if;

  return cleared;
end;
$$;

revoke all on function public.clear_rejected_driver_application(text) from public;
grant execute on function public.clear_rejected_driver_application(text) to authenticated;

-- 4. Function to clear all rejected applications from history
create or replace function public.clear_all_rejected_driver_applications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  count1 integer := 0;
  count2 integer := 0;
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;

  update public.driver_applications
  set history_cleared_at = now(),
      history_cleared_by = auth.uid()
  where status = 'rejected'
    and history_cleared_at is null;
  get diagnostics count1 = row_count;

  update public.drivers
  set history_cleared_at = now(),
      history_cleared_by = auth.uid()
  where application_status = 'rejected'
    and history_cleared_at is null;
  get diagnostics count2 = row_count;

  return count1 + count2;
end;
$$;

revoke all on function public.clear_all_rejected_driver_applications() from public;
grant execute on function public.clear_all_rejected_driver_applications() to authenticated;

