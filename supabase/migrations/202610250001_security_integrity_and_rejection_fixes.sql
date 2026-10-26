-- Migration: 202610250001_security_integrity_and_rejection_fixes.sql
-- Description:
--   1. Add transaction-level advisory locking (pg_advisory_xact_lock) to approve_driver
--      to eliminate concurrent approval/rejection race conditions (Item 10).
--   2. Preserve passenger account status and data when a driver application is rejected
--      so existing passengers are not locked out of their accounts (Item 4).
--   3. Clarify explicit table grants vs RLS policies on driver_earnings and ratings (Item 11).

create or replace function public.approve_driver(
  target_driver uuid,
  approved boolean,
  rejection_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin authorization required' using errcode = '42501';
  end if;

  -- Serialize concurrent approval/rejection attempts for the same target_driver
  perform pg_advisory_xact_lock(hashtext('approve_driver_' || target_driver::text));

  update public.drivers
  set application_status = case
        when $2 then 'approved'::public.account_status
        else 'rejected'::public.account_status
      end,
      rejection_reason = case when $2 then null else $3 end,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      is_online = false,
      is_available = false
  where user_id = $1 and application_status = 'pending';

  if not found then
    if exists (select 1 from public.drivers where user_id = $1) then
      raise exception 'driver application has already been reviewed' using errcode = '40001';
    end if;
    raise exception 'driver not found' using errcode = 'P0002';
  end if;

  -- Preserve passenger profile lifecycle when a driver application is rejected.
  -- Only set account_status = 'active' when approved; never downgrade an active
  -- passenger profile to 'rejected'.
  if $2 then
    update public.profiles
    set account_status = 'active'::public.account_status
    where id = $1;
  end if;

  update public.driver_presence
  set is_online = false, is_available = false
  where driver_id = $1;

  insert into public.notifications (id, user_id, sender_id, type, title, body)
  values (
    gen_random_uuid()::text, $1, auth.uid(), 'driver_verification',
    case when $2 then 'Application Approved' else 'Application Rejected' end,
    case when $2 then 'Your driver application was approved.'
         else 'Your driver application was rejected. ' || coalesce($3, '') end
  );
end;
$$;

revoke all on function public.approve_driver(uuid, boolean, text) from public;
grant execute on function public.approve_driver(uuid, boolean, text) to authenticated;

-- Clarify explicit grants vs RLS policies for read-only client tables mutated via SECURITY DEFINER RPCs:
-- Authenticated clients are explicitly granted SELECT permission (filtered by RLS owner/admin policies),
-- while direct INSERT/UPDATE/DELETE remain revoked from anon/authenticated and channeled exclusively through RPCs.
grant select on public.driver_earnings, public.ratings to authenticated;
revoke insert, update, delete on public.driver_earnings, public.ratings from anon, authenticated;

