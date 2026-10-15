-- Passenger ↔ Admin contract hardening.
--
-- Canonical identity:
--   auth.users.id = profiles.id = passenger_profiles.user_id
--
-- `profiles` contains a user's admin-visible identity (name, mirrored Auth
-- email, mobile, account_status and avatar path). `passenger_profiles` is the
-- passenger capability/private-preferences row. The Admin portal must list
-- passenger_profiles first and then read the matching profiles rows.

-- The former trigger inserted a passenger_profiles row for every new auth
-- identity. That made driver and administrator identities look like passenger
-- accounts before their actual role capability was known. Passenger creation
-- is now intentional: the trusted passenger-signup Edge Function creates the
-- capability row after it has created the Auth identity and profile.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, mobile, email_verified)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.email,
    new.phone,
    coalesce(new.email_confirmed_at is not null, false)
  )
  on conflict (id) do update set
    email = excluded.email,
    mobile = excluded.mobile,
    email_verified = excluded.email_verified;
  return new;
end;
$$;

-- These are table privileges only. The existing own-or-admin RLS policies
-- remain the authorization boundary: passengers read/update only their rows;
-- an active admin recognized by public.is_admin() can manage passenger data.
grant select on public.profiles, public.passenger_profiles to authenticated;

-- `profiles.email` is deliberately a searchable mirror of auth.users.email.
-- Auth's trigger and the trusted signup function may write it, but an ordinary
-- authenticated browser/mobile client must not create a divergent identity.
revoke update on public.profiles from authenticated;
grant update (
  full_name,
  mobile,
  address,
  latitude,
  longitude,
  location_updated_at,
  profile_photo_path,
  avatar_color,
  updated_at
) on public.profiles to authenticated;

-- Overview uses this count instead of a raw passenger_profiles count so it
-- matches the Admin Passengers list without downloading every profile row.
create or replace function public.admin_passenger_count()
returns bigint
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

  return (
    select count(*)
    from public.passenger_profiles pp
    left join public.drivers d on d.user_id = pp.user_id
    left join public.admin_roles ar on ar.user_id = pp.user_id
    where d.user_id is null
      and ar.user_id is null
  );
end;
$$;

revoke all on function public.admin_passenger_count() from public;
grant execute on function public.admin_passenger_count() to authenticated;

-- A non-destructive, administrator-only audit for legacy imports and for the
-- old trigger behaviour. It deliberately reports inconsistencies instead of
-- deleting or changing real accounts.
create or replace function public.passenger_account_integrity_issues()
returns table (issue text, user_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select 'passenger_profile_without_identity'::text, pp.user_id
  from public.passenger_profiles pp
  left join public.profiles p on p.id = pp.user_id
  where p.id is null

  union all

  select 'driver_also_marked_as_passenger'::text, pp.user_id
  from public.passenger_profiles pp
  join public.drivers d on d.user_id = pp.user_id

  union all

  select 'administrator_also_marked_as_passenger'::text, pp.user_id
  from public.passenger_profiles pp
  join public.admin_roles ar on ar.user_id = pp.user_id;
$$;

revoke all on function public.passenger_account_integrity_issues() from public;

-- Enforce the same authorization as the management screen when this audit is
-- called through PostgREST. SECURITY DEFINER avoids recursive RLS checks, but
-- the function itself never returns a row to a non-admin.
create or replace function public.admin_passenger_account_integrity_issues()
returns table (issue text, user_id uuid)
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
  return query select * from public.passenger_account_integrity_issues();
end;
$$;

revoke all on function public.admin_passenger_account_integrity_issues() from public;
grant execute on function public.admin_passenger_account_integrity_issues() to authenticated;
