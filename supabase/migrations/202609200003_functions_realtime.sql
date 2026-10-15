-- Atomic business operations, derived views, triggers, and Realtime setup.

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'profiles', 'admin_roles', 'passenger_profiles', 'todas', 'drivers',
    'driver_presence', 'fare_config', 'rides', 'payments', 'reports'
  ] loop
    execute format('drop trigger if exists set_updated_at on public.%I', table_name);
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      table_name
    );
  end loop;
end $$;

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

  insert into public.passenger_profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email, phone, email_confirmed_at on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.sync_driver_presence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.driver_presence (
    driver_id, vehicle_type, plate_number, is_online, is_available,
    latitude, longitude, last_location_at
  ) values (
    new.user_id, new.vehicle_type, new.plate_number, new.is_online, new.is_available,
    new.current_latitude, new.current_longitude, new.last_location_at
  ) on conflict (driver_id) do update set
    vehicle_type = excluded.vehicle_type,
    plate_number = excluded.plate_number,
    is_online = excluded.is_online,
    is_available = excluded.is_available,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    last_location_at = excluded.last_location_at;
  return new;
end;
$$;
drop trigger if exists sync_driver_presence_after_write on public.drivers;
create trigger sync_driver_presence_after_write
after insert or update of vehicle_type, plate_number, is_online, is_available,
  current_latitude, current_longitude, last_location_at on public.drivers
for each row execute function public.sync_driver_presence();

-- An approved online driver may see currently searchable requests. Assigned
-- and historical rides remain participant/admin only.
drop policy if exists rides_available_to_approved_drivers on public.rides;
create policy rides_available_to_approved_drivers on public.rides
for select to authenticated
using (
  status = 'searching'
  and exists (
    select 1 from public.drivers d
    join public.profiles p on p.id = d.user_id
    where d.user_id = auth.uid()
      and d.application_status in ('approved', 'active')
      and p.account_status in ('approved', 'active')
      and d.is_online
      and d.vehicle_type = rides.vehicle_type
  )
);

create or replace function public.nearby_drivers(
  passenger_latitude double precision,
  passenger_longitude double precision,
  requested_vehicle public.vehicle_type default null,
  radius_km double precision default 10
)
returns table (
  user_id uuid,
  full_name text,
  profile_photo_path text,
  vehicle_type public.vehicle_type,
  plate_number text,
  latitude double precision,
  longitude double precision,
  last_location_at timestamptz,
  rating_average numeric,
  rating_count integer,
  distance_km double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.user_id, p.full_name, p.profile_photo_path, presence.vehicle_type,
    presence.plate_number, presence.latitude, presence.longitude,
    presence.last_location_at, d.rating_average, d.rating_count,
    6371 * 2 * asin(sqrt(
      power(sin(radians(presence.latitude - passenger_latitude) / 2), 2) +
      cos(radians(passenger_latitude)) * cos(radians(presence.latitude)) *
      power(sin(radians(presence.longitude - passenger_longitude) / 2), 2)
    )) as distance_km
  from public.drivers d
  join public.profiles p on p.id = d.user_id
  join public.driver_presence presence on presence.driver_id = d.user_id
  where auth.uid() is not null
    and d.application_status in ('approved', 'active')
    and p.account_status in ('approved', 'active')
    and presence.is_online and presence.is_available
    and presence.latitude is not null and presence.longitude is not null
    and presence.last_location_at >= now() - interval '30 minutes'
    and (requested_vehicle is null or presence.vehicle_type = requested_vehicle)
    and 6371 * 2 * asin(sqrt(
      power(sin(radians(presence.latitude - passenger_latitude) / 2), 2) +
      cos(radians(passenger_latitude)) * cos(radians(presence.latitude)) *
      power(sin(radians(presence.longitude - passenger_longitude) / 2), 2)
    )) <= greatest(radius_km, 0)
  order by distance_km asc;
$$;
revoke all on function public.nearby_drivers(double precision, double precision, public.vehicle_type, double precision) from public;
grant execute on function public.nearby_drivers(double precision, double precision, public.vehicle_type, double precision) to authenticated;

create or replace function public.request_ride(
  requested_driver uuid,
  requested_vehicle public.vehicle_type,
  pickup_address text,
  pickup_latitude double precision,
  pickup_longitude double precision,
  pickup_province text,
  destination_address text,
  destination_latitude double precision,
  destination_longitude double precision,
  destination_province text,
  distance_km numeric,
  duration_minutes integer,
  payment_method text default 'cash'
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  config public.fare_config%rowtype;
  calculated_fare numeric;
  platform_commission numeric;
  result public.rides%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if distance_km < 0 or duration_minutes < 0 then raise exception 'invalid route metrics'; end if;
  if pickup_latitude not between -90 and 90 or destination_latitude not between -90 and 90
    or pickup_longitude not between -180 and 180 or destination_longitude not between -180 and 180 then
    raise exception 'invalid coordinates';
  end if;
  if coalesce(trim(pickup_province), '') <> '' and coalesce(trim(destination_province), '') <> ''
    and lower(trim(pickup_province)) <> lower(trim(destination_province)) then
    raise exception 'pickup and destination must be in the same province';
  end if;
  if payment_method not in ('cash', 'gcash', 'maya', 'card') then raise exception 'unsupported payment method'; end if;
  if exists (
    select 1 from public.rides r where r.passenger_id = auth.uid()
    and r.status in ('searching', 'accepted', 'arrived', 'started')
  ) then raise exception 'passenger already has an active ride'; end if;

  select * into config from public.fare_config where vehicle_type = requested_vehicle;
  if not found then raise exception 'fare configuration missing'; end if;
  calculated_fare := greatest(config.base_fare,
    round((config.base_fare + config.per_km_rate * greatest(distance_km - config.base_km, 0)) / 5) * 5);
  platform_commission := round(calculated_fare * config.commission_percent / 100, 2);

  if requested_driver is not null and not exists (
    select 1 from public.driver_presence presence
    where presence.driver_id = requested_driver
      and presence.vehicle_type = requested_vehicle
      and presence.is_online and presence.is_available
      and public.is_approved_driver(requested_driver)
  ) then raise exception 'selected driver is not available'; end if;

  insert into public.rides (
    id, passenger_id, driver_id, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status
  ) values (
    gen_random_uuid()::text, auth.uid(), requested_driver, requested_vehicle,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, calculated_fare, platform_commission,
    calculated_fare - platform_commission, payment_method, 'searching'
  ) returning * into result;
  insert into public.ride_status_history (ride_id, to_status, changed_by)
  values (result.id, 'searching', auth.uid());
  return result;
end;
$$;
revoke all on function public.request_ride(uuid, public.vehicle_type, text, double precision, double precision, text, text, double precision, double precision, text, numeric, integer, text) from public;
grant execute on function public.request_ride(uuid, public.vehicle_type, text, double precision, double precision, text, text, double precision, double precision, text, numeric, integer, text) to authenticated;

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
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select * into current_driver from public.drivers
  where user_id = auth.uid() for update;
  select * into current_presence from public.driver_presence
  where driver_id = auth.uid() for update;
  if not found
    or current_driver.application_status not in ('approved', 'active')
    or current_presence.driver_id is null
    or not current_presence.is_online
    or not current_presence.is_available then
    return false;
  end if;

  select * into current_ride from public.rides where id = ride_id for update;
  if not found
    or current_ride.status <> 'searching'
    or (current_ride.driver_id is not null and current_ride.driver_id <> auth.uid())
    or current_ride.vehicle_type <> current_presence.vehicle_type then
    return false;
  end if;

  update public.rides set
    driver_id = auth.uid(), status = 'accepted', accepted_at = now()
  where id = ride_id;
  update public.drivers set is_available = false where user_id = auth.uid();
  update public.driver_presence set is_available = false where driver_id = auth.uid();
  insert into public.ride_status_history (ride_id, from_status, to_status, changed_by)
  values (ride_id, 'searching', 'accepted', auth.uid());
  insert into public.notifications (id, user_id, sender_id, ride_id, type, title, body)
  values (
    gen_random_uuid()::text, current_ride.passenger_id, auth.uid(), ride_id,
    'ride_accepted', 'Driver Accepted', 'A driver has accepted your ride request.'
  );
  return true;
end;
$$;
revoke all on function public.accept_ride(text) from public;
grant execute on function public.accept_ride(text) to authenticated;

create or replace function public.transition_ride(ride_id text, next_status public.ride_status)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare current_ride public.rides%rowtype;
begin
  select * into current_ride from public.rides where id = ride_id for update;
  if not found or current_ride.driver_id <> auth.uid() then return false; end if;
  if not (
    (current_ride.status = 'accepted' and next_status = 'arrived') or
    (current_ride.status = 'arrived' and next_status = 'started') or
    (current_ride.status = 'started' and next_status = 'completed')
  ) then return false; end if;

  update public.rides set
    status = next_status,
    arrived_at = case when next_status = 'arrived' then now() else arrived_at end,
    started_at = case when next_status = 'started' then now() else started_at end,
    completed_at = case when next_status = 'completed' then now() else completed_at end
  where id = ride_id;
  if next_status = 'completed' then
    update public.drivers set is_available = is_online, total_trips = total_trips + 1
    where user_id = auth.uid();
    update public.driver_presence set is_available = is_online where driver_id = auth.uid();
    update public.passenger_profiles set ride_count = ride_count + 1
    where user_id = current_ride.passenger_id;
  end if;
  insert into public.ride_status_history (ride_id, from_status, to_status, changed_by)
  values (ride_id, current_ride.status, next_status, auth.uid());
  return true;
end;
$$;
revoke all on function public.transition_ride(text, public.ride_status) from public;
grant execute on function public.transition_ride(text, public.ride_status) to authenticated;

create or replace function public.cancel_ride(ride_id text, reason text default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare current_ride public.rides%rowtype;
begin
  select * into current_ride from public.rides where id = ride_id for update;
  if not found
    or (not public.is_admin() and current_ride.passenger_id <> auth.uid() and current_ride.driver_id is distinct from auth.uid())
    or current_ride.status not in ('searching', 'accepted', 'arrived', 'started') then
    return false;
  end if;
  update public.rides set status = 'cancelled', cancelled_at = now(), cancellation_reason = reason
  where id = ride_id;
  if current_ride.driver_id is not null then
    update public.drivers set is_available = is_online where user_id = current_ride.driver_id;
    update public.driver_presence set is_available = is_online where driver_id = current_ride.driver_id;
  end if;
  insert into public.ride_status_history (ride_id, from_status, to_status, changed_by, reason)
  values (ride_id, current_ride.status, 'cancelled', auth.uid(), reason);
  return true;
end;
$$;
revoke all on function public.cancel_ride(text, text) from public;
grant execute on function public.cancel_ride(text, text) to authenticated;

create or replace function public.decline_ride(ride_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.rides set driver_id = null
  where id = ride_id and driver_id = auth.uid() and status = 'searching';
  return found;
end;
$$;
revoke all on function public.decline_ride(text) from public;
grant execute on function public.decline_ride(text) to authenticated;

create or replace function public.refresh_driver_rating(target_driver uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.drivers d set
    rating_average = stats.average_rating,
    rating_count = stats.rating_count
  from (
    select round(avg(rating)::numeric, 2) average_rating, count(*)::integer rating_count
    from public.ratings where driver_id = target_driver
  ) stats
  where d.user_id = target_driver;
$$;

create or replace function public.rating_aggregate_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.refresh_driver_rating(coalesce(new.driver_id, old.driver_id));
  return coalesce(new, old);
end;
$$;
drop trigger if exists refresh_driver_rating_after_write on public.ratings;
create trigger refresh_driver_rating_after_write
after insert or update or delete on public.ratings
for each row execute function public.rating_aggregate_trigger();

create or replace function public.approve_driver(target_driver uuid, approved boolean, rejection_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin authorization required'; end if;
  update public.drivers set
    application_status = case when approved then 'approved'::public.account_status else 'rejected'::public.account_status end,
    rejection_reason = case when approved then null else rejection_reason end,
    reviewed_at = now(), reviewed_by = auth.uid(),
    is_online = case when approved then is_online else false end,
    is_available = case when approved then is_available else false end
  where user_id = target_driver;
  update public.driver_presence set
    is_online = case when approved then is_online else false end,
    is_available = case when approved then is_available else false end
  where driver_id = target_driver;
  if not found then raise exception 'driver not found'; end if;
  insert into public.notifications (id, user_id, sender_id, type, title, body)
  values (
    gen_random_uuid()::text, target_driver, auth.uid(), 'driver_verification',
    case when approved then 'Application Approved' else 'Application Rejected' end,
    case when approved then 'Your driver application was approved.'
         else 'Your driver application was rejected. ' || coalesce(rejection_reason, '') end
  );
end;
$$;
revoke all on function public.approve_driver(uuid, boolean, text) from public;
grant execute on function public.approve_driver(uuid, boolean, text) to authenticated;

create or replace function public.set_account_status(
  target_user uuid,
  new_status public.account_status,
  reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin authorization required'; end if;
  if target_user = auth.uid() and new_status in ('suspended', 'deactivated') then
    raise exception 'an administrator cannot deactivate their own session';
  end if;
  update public.profiles set account_status = new_status where id = target_user;
  if not found then raise exception 'profile not found'; end if;
  update public.drivers set
    application_status = case
      when new_status = 'suspended' then 'suspended'::public.account_status
      when new_status = 'active' and application_status = 'suspended' then 'approved'::public.account_status
      else application_status
    end,
    suspension_reason = case when new_status = 'suspended' then reason else null end,
    is_online = case when new_status in ('suspended', 'deactivated') then false else is_online end,
    is_available = case when new_status in ('suspended', 'deactivated') then false else is_available end
  where user_id = target_user;
  update public.driver_presence set
    is_online = case when new_status in ('suspended', 'deactivated') then false else is_online end,
    is_available = case when new_status in ('suspended', 'deactivated') then false else is_available end
  where driver_id = target_user;
end;
$$;
revoke all on function public.set_account_status(uuid, public.account_status, text) from public;
grant execute on function public.set_account_status(uuid, public.account_status, text) to authenticated;

create or replace function public.update_fare(
  target_vehicle public.vehicle_type,
  new_base_fare numeric,
  new_per_km_rate numeric,
  new_commission_percent numeric default 12
)
returns public.fare_config
language plpgsql
security definer
set search_path = public
as $$
declare result public.fare_config;
begin
  if not public.is_admin() then raise exception 'admin authorization required'; end if;
  insert into public.fare_config (vehicle_type, base_fare, per_km_rate, commission_percent, updated_by)
  values (target_vehicle, new_base_fare, new_per_km_rate, new_commission_percent, auth.uid())
  on conflict (vehicle_type) do update set
    base_fare = excluded.base_fare,
    per_km_rate = excluded.per_km_rate,
    commission_percent = excluded.commission_percent,
    effective_at = now(),
    updated_by = auth.uid()
  returning * into result;
  return result;
end;
$$;
revoke all on function public.update_fare(public.vehicle_type, numeric, numeric, numeric) from public;
grant execute on function public.update_fare(public.vehicle_type, numeric, numeric, numeric) to authenticated;

create or replace function public.settle_ride_payment(
  payment_id text,
  ride_id text,
  provider_reference text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare current_payment public.payments%rowtype;
begin
  if auth.role() <> 'service_role' and not public.is_admin() then
    raise exception 'trusted server or admin authorization required';
  end if;
  select * into current_payment from public.payments p
  where p.id = payment_id and p.ride_id = settle_ride_payment.ride_id for update;
  if not found then return false; end if;
  if current_payment.status = 'paid' then return true; end if;
  update public.payments set status = 'paid', paid_at = now(), provider_reference = settle_ride_payment.provider_reference
  where id = payment_id;
  update public.rides set payment_status = 'paid' where id = ride_id;
  if current_payment.driver_id is not null then
    insert into public.driver_earnings (id, driver_id, ride_id, gross_amount, commission, net_amount)
    values ('earn_' || ride_id, current_payment.driver_id, ride_id, current_payment.amount,
      current_payment.platform_fee, current_payment.driver_net)
    on conflict (id) do nothing;
    update public.drivers set lifetime_earnings = lifetime_earnings + current_payment.driver_net
    where user_id = current_payment.driver_id;
  end if;
  return true;
end;
$$;
revoke all on function public.settle_ride_payment(text, text, text) from public;
grant execute on function public.settle_ride_payment(text, text, text) to authenticated, service_role;

create or replace function public.refund_ride_payment(payment_id text, reason text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare target_ride text;
begin
  if not public.is_admin() then raise exception 'admin authorization required'; end if;
  update public.payments set
    status = 'refunded',
    metadata = metadata || jsonb_build_object('refund_reason', reason, 'refunded_by', auth.uid(), 'refunded_at', now())
  where id = payment_id and status = 'paid'
  returning ride_id into target_ride;
  if target_ride is null then return false; end if;
  update public.rides set payment_status = 'refunded' where id = target_ride;
  return true;
end;
$$;
revoke all on function public.refund_ride_payment(text, text) from public;
grant execute on function public.refund_ride_payment(text, text) to authenticated;

-- Postgres Changes are used only for UX-critical live state.
do $$
declare table_name text;
begin
  foreach table_name in array array['rides', 'driver_presence', 'notifications', 'chat_messages', 'payments'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end $$;
