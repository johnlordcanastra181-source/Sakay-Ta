-- Realtime connection hardening for the canonical Sakay Ta schema.
--
-- UX-critical live state is deliberately limited to discovery-safe presence,
-- ride lifecycle, the authenticated profile row, notifications, and payment
-- status. Private driver verification rows are not published.

do $$
declare
  table_name text;
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    foreach table_name in array array[
      'rides', 'driver_presence', 'profiles', 'notifications',
      'chat_messages', 'payments'
    ] loop
      if to_regclass(format('public.%I', table_name)) is not null
         and not exists (
           select 1
           from pg_publication_tables
           where pubname = 'supabase_realtime'
             and schemaname = 'public'
             and tablename = table_name
         ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          table_name
        );
      end if;
    end loop;
  end if;
end
$$;

-- Presence is intentionally discovery-safe. Approved drivers remain visible
-- to authenticated clients while offline so an Online -> Offline update can
-- be observed and removed from a passenger's authoritative nearby list. The
-- RPC still returns only online/available drivers for booking.
drop policy if exists driver_presence_online_authenticated_read
  on public.driver_presence;
drop policy if exists driver_presence_approved_authenticated_read
  on public.driver_presence;
create policy driver_presence_approved_authenticated_read
on public.driver_presence
for select to authenticated
using (
  public.is_approved_driver(driver_id)
  or driver_id = auth.uid()
  or public.is_admin()
);

-- Keep the discovery row's timestamp authoritative when the driver row is
-- mirrored by the trigger. This also makes reconnect diagnostics meaningful.
create or replace function public.sync_driver_presence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.driver_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at, updated_at
  ) values (
    new.user_id, new.vehicle_type, new.plate_number, new.is_online,
    new.is_available, new.current_latitude, new.current_longitude,
    new.last_location_at, now()
  ) on conflict (driver_id) do update set
    vehicle_type = excluded.vehicle_type,
    plate_number = excluded.plate_number,
    is_online = excluded.is_online,
    is_available = excluded.is_available,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    last_location_at = excluded.last_location_at,
    updated_at = now();
  return new;
end;
$$;

-- The ride ID is text in public.rides. The previous migration accidentally
-- cast it to uuid, so any application-generated ID (for example ride_<uuid>)
-- failed before the row could be updated or broadcast through Realtime.
create or replace function public.accept_ride(ride_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_ride public.rides%rowtype;
  current_driver public.drivers%rowtype;
  current_presence public.driver_presence%rowtype;
  has_other_active_ride boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into current_ride
  from public.rides
  where id = accept_ride.ride_id
  for update;
  if not found then return false; end if;

  if current_ride.status = 'accepted'
     and current_ride.driver_id = auth.uid() then
    return true;
  end if;

  if current_ride.status <> 'searching'
     or (current_ride.driver_id is not null
         and current_ride.driver_id <> auth.uid()) then
    return false;
  end if;

  select * into current_driver
  from public.drivers
  where user_id = auth.uid()
  for update;
  if not found then return false; end if;

  select * into current_presence
  from public.driver_presence
  where driver_id = auth.uid()
  for update;
  if not found then return false; end if;

  if current_driver.application_status not in ('approved', 'active')
     or not current_driver.is_online
     or not current_presence.is_online
     or current_ride.vehicle_type <> current_presence.vehicle_type then
    return false;
  end if;

  select exists (
    select 1
    from public.rides r
    where r.driver_id = auth.uid()
      and r.id <> current_ride.id
      and r.status in ('searching', 'accepted', 'arrived', 'started')
  ) into has_other_active_ride;
  if has_other_active_ride then return false; end if;

  -- A selected-driver request may already carry this driver's ID. An open
  -- pool request must still reserve an available driver atomically here.
  if current_ride.driver_id is null
     and (not current_driver.is_available
          or not current_presence.is_available) then
    return false;
  end if;

  update public.rides
  set driver_id = auth.uid(), status = 'accepted', accepted_at = now()
  where id = current_ride.id and status = 'searching';
  if not found then return false; end if;

  update public.drivers
  set is_available = false
  where user_id = auth.uid();
  update public.driver_presence
  set is_available = false
  where driver_id = auth.uid();

  insert into public.ride_status_history
    (ride_id, from_status, to_status, changed_by)
  values (current_ride.id, 'searching', 'accepted', auth.uid());

  insert into public.notifications
    (id, user_id, sender_id, ride_id, type, title, body)
  values (
    gen_random_uuid()::text, current_ride.passenger_id, auth.uid(),
    current_ride.id, 'ride_accepted', 'Driver Accepted',
    'A driver has accepted your ride request.'
  );
  return true;
end;
$$;

revoke all on function public.accept_ride(text) from public;
grant execute on function public.accept_ride(text) to authenticated;

-- Declining an open pool request is a per-driver UI decision; it must not
-- mutate a request visible to every other eligible driver. A selected request
-- assigned to this driver is released back to the searching pool.
create or replace function public.decline_ride(ride_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_ride public.rides%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into current_ride
  from public.rides
  where id = decline_ride.ride_id
  for update;
  if not found or current_ride.status <> 'searching' then return false; end if;
  if current_ride.driver_id is null then return true; end if;
  if current_ride.driver_id <> auth.uid() then return false; end if;

  update public.rides
  set driver_id = null
  where id = current_ride.id
    and driver_id = auth.uid()
    and status = 'searching';
  return found;
end;
$$;

revoke all on function public.decline_ride(text) from public;
grant execute on function public.decline_ride(text) to authenticated;
