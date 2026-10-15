-- Migration: Fix profile upsert permissions after OTP signup
-- The trigger handle_new_auth_user creates the profile row with SECURITY DEFINER.
-- After OTP verification, the authenticated user needs to update their own profile
-- with full_name, mobile, address. The existing profiles_update_own policy
-- already allows this, but we need to ensure passenger_profiles insert/upsert
-- works correctly when user_id = auth.uid().

-- Re-verify that passenger_profiles_own_insert policy is correct.
-- The trigger already inserts into passenger_profiles on auth.users insert,
-- so this policy is used when the client upserts additional data.
drop policy if exists passenger_profiles_own_insert on public.passenger_profiles;
create policy passenger_profiles_own_insert on public.passenger_profiles
  for insert to authenticated
  with check (user_id = auth.uid());

-- Also ensure upsert (insert+update) works for own row.
drop policy if exists passenger_profiles_own_upsert on public.passenger_profiles;
create policy passenger_profiles_own_upsert on public.passenger_profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Grant needed privileges (the existing migration grants these, but ensure)
-- These are idempotent grants.
grant usage on schema public to authenticated;
grant select, insert, update on public.passenger_profiles to authenticated;
