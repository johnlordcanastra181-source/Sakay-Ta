-- Separate new driver applications from authenticated driver accounts.
-- Existing drivers rows are intentionally preserved: rides, earnings, and
-- other history remain linked to their existing Auth UUIDs.

create table if not exists public.driver_applications (
  id uuid primary key default gen_random_uuid(),
  submission_key uuid not null unique,
  status_token_hash text not null,
  full_name text not null,
  email text not null,
  mobile text not null,
  address text not null,
  date_of_birth date not null,
  sex text not null,
  vehicle_type public.vehicle_type not null,
  plate_number text not null,
  vehicle_make text not null,
  vehicle_model text not null,
  vehicle_year integer not null,
  vehicle_color text not null,
  license_type text,
  license_number text,
  license_expiry date,
  dl_codes text,
  condition_codes text,
  toda_id text references public.todas(id) on delete set null,
  barangay text not null,
  municipality text not null,
  province text not null,
  doc_profile text not null,
  doc_license_front text,
  doc_or_cr text,
  status text not null default 'uploading'
    check (status in ('uploading', 'pending', 'provisioning',
                     'provisioning_failed', 'awaiting_activation',
                     'active', 'rejected')),
  submitted_by_auth_user_id uuid references auth.users(id) on delete set null,
  auth_user_id uuid references auth.users(id) on delete set null,
  rejection_reason text,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  provisioning_started_at timestamptz,
  provisioning_attempts integer not null default 0,
  provisioning_error text,
  applicant_notification_status text not null default 'not_sent'
    check (applicant_notification_status in ('not_sent', 'sending', 'sent', 'failed', 'not_configured')),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint driver_applications_toda_vehicle_check check (
    (vehicle_type = 'tricycle' and toda_id is not null) or
    (vehicle_type = 'habal' and toda_id is null)
  ),
  constraint driver_applications_year_check check (vehicle_year between 1950 and 2100),
  constraint driver_applications_email_normalized check (email = lower(btrim(email)))
);

create unique index if not exists driver_applications_one_open_email
  on public.driver_applications (lower(email))
  where status in ('uploading', 'pending', 'provisioning',
                   'provisioning_failed', 'awaiting_activation', 'active');
create index if not exists driver_applications_review_queue_idx
  on public.driver_applications (status, submitted_at desc);
create index if not exists driver_applications_auth_user_idx
  on public.driver_applications (auth_user_id)
  where auth_user_id is not null;

alter table public.driver_applications enable row level security;
alter table public.driver_applications force row level security;
revoke all on public.driver_applications from public, anon, authenticated;
grant all on public.driver_applications to service_role;

drop trigger if exists driver_applications_set_updated_at on public.driver_applications;
create trigger driver_applications_set_updated_at
before update on public.driver_applications
for each row execute function public.set_updated_at();

create or replace function public.enforce_driver_application_toda()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Preserve the existing Admin delete behavior: the TODA FK action sets
  -- drivers.toda_id to NULL while deleting a TODA, and that nested update
  -- must not prevent the parent deletion.
  if tg_op = 'UPDATE'
     and pg_trigger_depth() > 1
     and old.toda_id is not null
     and new.toda_id is null then
    return new;
  end if;

  if new.vehicle_type = 'tricycle' then
    if new.toda_id is null or not exists (
      select 1 from public.todas t where t.id = new.toda_id and t.is_active
    ) then
      raise exception 'An active TODA is required for tricycle applications.'
        using errcode = '23514';
    end if;
  elsif new.vehicle_type = 'habal' and new.toda_id is not null then
    raise exception 'Habal-Habal applications must not select a TODA.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_driver_application_toda()
  from public, anon, authenticated;

drop trigger if exists enforce_driver_application_toda on public.driver_applications;
create trigger enforce_driver_application_toda
before insert or update of vehicle_type, toda_id on public.driver_applications
for each row execute function public.enforce_driver_application_toda();

alter table public.drivers
  add column if not exists approved_application_id uuid
  references public.driver_applications(id) on delete set null;
create unique index if not exists drivers_approved_application_unique
  on public.drivers (approved_application_id)
  where approved_application_id is not null;

-- Signed, application-scoped uploads need no public Storage policy. Once an
-- application is provisioned, the driver may read only objects referenced by
-- their own driver_documents rows; Admins retain their existing review access.
drop policy if exists driver_documents_owner_or_admin_read on storage.objects;
create policy driver_documents_owner_or_admin_read on storage.objects
for select to authenticated
using (
  bucket_id = 'driver-documents' and (
    public.is_admin() or
    (storage.foldername(name))[1] = auth.uid()::text or
    exists (
      select 1 from public.driver_documents dd
      where dd.driver_id = auth.uid() and dd.storage_path = storage.objects.name
    )
  )
);

-- Durable, atomic rate-limit buckets for the unauthenticated application edge
-- endpoint. Only service_role can invoke the limiter or inspect its hashes.
create table if not exists public.driver_application_rate_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0)
);
alter table public.driver_application_rate_limits enable row level security;
alter table public.driver_application_rate_limits force row level security;
revoke all on public.driver_application_rate_limits from public, anon, authenticated;
grant all on public.driver_application_rate_limits to service_role;

create or replace function public.consume_driver_application_rate_limit(
  p_key_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count integer;
begin
  if length(p_key_hash) <> 64 or p_limit < 1 or p_window_seconds < 1 then
    raise exception 'Invalid rate limit request.' using errcode = '22023';
  end if;

  insert into public.driver_application_rate_limits as limits
    (key_hash, window_started_at, request_count)
  values (p_key_hash, now(), 1)
  on conflict (key_hash) do update set
    window_started_at = case
      when limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
        then now()
      else limits.window_started_at
    end,
    request_count = case
      when limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
        then 1
      else limits.request_count + 1
    end
  returning request_count into current_count;

  delete from public.driver_application_rate_limits
  where window_started_at < now() - interval '14 days';
  return current_count <= p_limit;
end;
$$;
revoke all on function public.consume_driver_application_rate_limit(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_driver_application_rate_limit(text, integer, integer)
  to service_role;

-- Driver capabilities may only be created by the trusted approval workflow.
drop policy if exists drivers_owner_pending_insert on public.drivers;
revoke insert on public.drivers from anon, authenticated;

-- The legacy Auth-backed flow still exists for records submitted by older app
-- versions. Make it a single pending->decision transition and use positional
-- $3 for the reason to avoid the old column/parameter-name ambiguity.
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

  -- Keep the legacy Auth-backed profile lifecycle intact. Driver rows use
  -- "approved" while the shared account profile uses "active".
  update public.profiles
  set account_status = case
        when $2 then 'active'::public.account_status
        else 'rejected'::public.account_status
      end
  where id = $1;

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

