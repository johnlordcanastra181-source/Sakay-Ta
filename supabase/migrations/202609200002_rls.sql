-- Row-level and Storage security. The service-role key is never required by
-- Flutter; migration utilities use it only from a trusted local environment.

create or replace function public.is_admin(check_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = check_user and ar.status = 'active'
  );
$$;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;

create or replace function public.is_super_admin(check_user uuid default auth.uid())
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = check_user and ar.role = 'super_admin' and ar.status = 'active'
  );
$$;
revoke all on function public.is_super_admin(uuid) from public;
grant execute on function public.is_super_admin(uuid) to authenticated;

create or replace function public.is_ride_participant(check_ride_id text, check_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.rides r
    where r.id = check_ride_id
      and (r.passenger_id = check_user or r.driver_id = check_user)
  );
$$;
revoke all on function public.is_ride_participant(text, uuid) from public;
grant execute on function public.is_ride_participant(text, uuid) to authenticated;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'firebase_user_map', 'profiles', 'admin_roles', 'passenger_profiles',
    'todas', 'drivers', 'driver_documents', 'driver_presence', 'toda_associations',
    'fare_config', 'rides', 'ride_status_history', 'bookings', 'ratings',
    'payments', 'driver_earnings', 'withdrawals', 'chat_messages',
    'notifications', 'wallet_transactions', 'reports', 'saved_places',
    'email_otps', 'magic_links'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end $$;

-- Identity and profiles
create policy profiles_select_own_or_admin on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_admin());

create policy profiles_insert_own on public.profiles
for insert to authenticated
with check (id = auth.uid() and account_status = 'active');

create policy profiles_admin_update on public.profiles
for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy profiles_update_own on public.profiles
for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- Prevent self-promotion/suspension changes even when PostgREST was granted
-- broad defaults by an earlier project configuration.
revoke update on public.profiles from authenticated;
grant update (full_name, email, mobile, address, latitude, longitude,
  location_updated_at, profile_photo_path, avatar_color, updated_at)
on public.profiles to authenticated;

create policy admin_roles_select_own_or_admin on public.admin_roles
for select to authenticated
using (user_id = auth.uid() or public.is_admin());
create policy admin_roles_admin_insert on public.admin_roles
for insert to authenticated with check (public.is_admin());
create policy admin_roles_admin_update on public.admin_roles
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_roles_super_admin_delete on public.admin_roles
for delete to authenticated
using (public.is_super_admin());

create policy passenger_profiles_own_or_admin_select on public.passenger_profiles
for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy passenger_profiles_own_insert on public.passenger_profiles
for insert to authenticated with check (user_id = auth.uid());
create policy passenger_profiles_own_update on public.passenger_profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy passenger_profiles_admin_all on public.passenger_profiles
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Drivers. Discovery goes through nearby_drivers() so private verification
-- columns never become passenger-readable.
create policy drivers_owner_or_admin_select on public.drivers
for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy drivers_owner_pending_insert on public.drivers
for insert to authenticated
with check (user_id = auth.uid() and application_status = 'pending' and not is_online and not is_available);
create policy drivers_admin_update on public.drivers
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy drivers_owner_update on public.drivers
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke update on public.drivers from authenticated;
grant update (is_online, is_available, current_latitude, current_longitude,
  last_location_at, plate_number, vehicle_type, vehicle_make, vehicle_model,
  vehicle_year, vehicle_color, toda_id, updated_at)
on public.drivers to authenticated;

create policy driver_documents_owner_or_admin_select on public.driver_documents
for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy driver_documents_owner_insert on public.driver_documents
for insert to authenticated
with check (driver_id = auth.uid() and storage_path like auth.uid()::text || '/%');
create policy driver_documents_owner_delete_pending on public.driver_documents
for delete to authenticated using (driver_id = auth.uid() and status = 'pending');
create policy driver_documents_admin_update on public.driver_documents
for update to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.is_approved_driver(check_driver uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.drivers d join public.profiles p on p.id = d.user_id
    where d.user_id = check_driver
      and d.application_status in ('approved', 'active')
      and p.account_status in ('approved', 'active')
  );
$$;
revoke all on function public.is_approved_driver(uuid) from public;
grant execute on function public.is_approved_driver(uuid) to authenticated;

create policy driver_presence_online_authenticated_read on public.driver_presence
for select to authenticated
using ((is_online and public.is_approved_driver(driver_id)) or driver_id = auth.uid() or public.is_admin());
create policy driver_presence_owner_update on public.driver_presence
for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
create policy driver_presence_admin_all on public.driver_presence
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Public operational configuration: signed-in users may read; only admins
-- may mutate.
create policy fare_config_authenticated_read on public.fare_config
for select to authenticated using (true);
create policy fare_config_admin_write on public.fare_config
for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy todas_authenticated_read on public.todas
for select to authenticated using (is_active or public.is_admin());
create policy todas_admin_write on public.todas
for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy associations_self_or_admin_read on public.toda_associations
for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy associations_owner_pending_insert on public.toda_associations
for insert to authenticated with check (driver_id = auth.uid() and status = 'pending');
create policy associations_admin_write on public.toda_associations
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Rides are created by their passenger. State transitions and assignments are
-- intentionally RPC-only to make status checks atomic.
create policy rides_participant_or_admin_select on public.rides
for select to authenticated
using (passenger_id = auth.uid() or driver_id = auth.uid() or public.is_admin());
create policy rides_passenger_create on public.rides
for insert to authenticated
with check (passenger_id = auth.uid() and driver_id is null and status = 'searching');
create policy rides_admin_update on public.rides
for update to authenticated using (public.is_admin()) with check (public.is_admin());
revoke update, delete on public.rides from authenticated;

create policy ride_history_participant_or_admin_read on public.ride_status_history
for select to authenticated using (public.is_ride_participant(ride_id) or public.is_admin());

create policy bookings_owner_or_admin_select on public.bookings
for select to authenticated using (passenger_id = auth.uid() or public.is_admin());
create policy bookings_owner_insert on public.bookings
for insert to authenticated with check (passenger_id = auth.uid());
create policy bookings_owner_cancel on public.bookings
for update to authenticated using (passenger_id = auth.uid()) with check (passenger_id = auth.uid());

create policy ratings_participant_or_admin_read on public.ratings
for select to authenticated
using (passenger_id = auth.uid() or driver_id = auth.uid() or public.is_admin());
create policy ratings_passenger_insert on public.ratings
for insert to authenticated
with check (
  passenger_id = auth.uid()
  and exists (
    select 1 from public.rides r
    where r.id = ride_id and r.passenger_id = auth.uid()
      and r.driver_id = driver_id and r.status = 'completed'
  )
);

create policy payments_participant_or_admin_read on public.payments
for select to authenticated
using (passenger_id = auth.uid() or driver_id = auth.uid() or public.is_admin());
create policy payments_passenger_insert on public.payments
for insert to authenticated
with check (
  passenger_id = auth.uid()
  and exists (
    select 1 from public.rides r
    where r.id = ride_id and r.passenger_id = auth.uid()
      and r.driver_id is not distinct from driver_id and r.fare = amount
  )
);
create policy payments_admin_update on public.payments
for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy earnings_driver_or_admin_read on public.driver_earnings
for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy withdrawals_driver_or_admin_read on public.withdrawals
for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy withdrawals_driver_create on public.withdrawals
for insert to authenticated with check (driver_id = auth.uid() and status = 'pending');
create policy withdrawals_admin_update on public.withdrawals
for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy chat_participant_read on public.chat_messages
for select to authenticated using (public.is_ride_participant(ride_id) or public.is_admin());
create policy chat_participant_insert on public.chat_messages
for insert to authenticated
with check (sender_id = auth.uid() and public.is_ride_participant(ride_id));

create policy notifications_recipient_or_admin_read on public.notifications
for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy notifications_authenticated_insert on public.notifications
for insert to authenticated
with check (
  sender_id = auth.uid()
  and (
    public.is_admin()
    or user_id = auth.uid()
    or (ride_id is not null and public.is_ride_participant(ride_id, auth.uid()) and public.is_ride_participant(ride_id, user_id))
  )
);
create policy notifications_recipient_update on public.notifications
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke update on public.notifications from authenticated;
grant update (is_read) on public.notifications to authenticated;

create policy wallet_owner_or_admin_read on public.wallet_transactions
for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy reports_related_or_admin_read on public.reports
for select to authenticated
using (reporter_id = auth.uid() or reported_user_id = auth.uid() or public.is_admin());
create policy reports_authenticated_create on public.reports
for insert to authenticated with check (reporter_id = auth.uid() and status = 'pending');
create policy reports_admin_update on public.reports
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy saved_places_owner_or_admin_all on public.saved_places
for all to authenticated using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

-- No client policies are defined for firebase_user_map, email_otps, or
-- magic_links. They remain accessible only to trusted migration/server roles.

-- Storage object paths start with the authenticated user's UUID.
create policy avatars_owner_select on storage.objects
for select to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_owner_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_owner_update on storage.objects
for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_owner_delete on storage.objects
for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy driver_documents_owner_or_admin_read on storage.objects
for select to authenticated
using (
  bucket_id = 'driver-documents' and
  ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
);
create policy driver_documents_owner_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = auth.uid()::text);
create policy driver_documents_owner_delete on storage.objects
for delete to authenticated
using (bucket_id = 'driver-documents' and owner_id = auth.uid()::text);

-- Remove anonymous Data API access. Public avatar delivery is controlled by
-- the bucket's public flag and does not grant database access.
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Re-apply column restrictions after the broad table grants above.
revoke update on public.profiles, public.drivers, public.driver_presence, public.notifications, public.rides from authenticated;
grant update (full_name, email, mobile, address, latitude, longitude,
  location_updated_at, profile_photo_path, avatar_color, updated_at)
on public.profiles to authenticated;
grant update (is_online, is_available, current_latitude, current_longitude,
  last_location_at, plate_number, vehicle_type, vehicle_make, vehicle_model,
  vehicle_year, vehicle_color, toda_id, updated_at)
on public.drivers to authenticated;
grant update (is_online, is_available, latitude, longitude, last_location_at, updated_at)
on public.driver_presence to authenticated;
grant update (is_read) on public.notifications to authenticated;
revoke all on public.firebase_user_map, public.email_otps, public.magic_links from authenticated;
revoke insert, update, delete on public.admin_roles from authenticated;
revoke insert, update, delete on public.rides from authenticated;
revoke update, delete on public.bookings from authenticated;
