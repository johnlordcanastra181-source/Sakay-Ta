-- Keep driver request delivery stable and make acceptance idempotent.

-- DriverHome subscribes to the current profile. The production publication
-- drifted and omitted this table, producing RealtimeSubscribeException.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end
$$;

-- Booking a selected driver serializes on the driver row and rejects a
-- second active assignment, but does not mark the driver busy before Accept.
create or replace function public.request_ride_with_id(
  client_ride_id text,
  requested_driver uuid,
  requested_vehicle public.vehicle_type,
  passenger_name text,
  passenger_phone text,
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
  locked_driver_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if distance_km < 0 or duration_minutes < 0 then raise exception 'invalid route metrics'; end if;
  if pickup_latitude not between -90 and 90 or destination_latitude not between -90 and 90
    or pickup_longitude not between -180 and 180 or destination_longitude not between -180 and 180 then
    raise exception 'invalid coordinates';
  end if;
  if payment_method not in ('cash', 'gcash', 'maya', 'card') then
    raise exception 'unsupported payment method';
  end if;

  if exists (
    select 1 from public.rides r
    where r.passenger_id = auth.uid()
      and r.status in ('searching', 'accepted', 'arrived', 'started')
  ) then
    raise exception 'passenger already has an active ride';
  end if;

  select * into config
  from public.fare_config
  where vehicle_type = requested_vehicle;
  if not found then raise exception 'fare configuration missing'; end if;

  calculated_fare := greatest(
    config.base_fare,
    round((config.base_fare + config.per_km_rate * greatest(distance_km - config.base_km, 0)) / 5) * 5
  );
  platform_commission := round(calculated_fare * config.commission_percent / 100, 2);

  if requested_driver is not null then
    select d.user_id into locked_driver_id
    from public.drivers d
    where d.user_id = requested_driver
      and d.vehicle_type = requested_vehicle
      and d.is_online
      and d.is_available
      and d.application_status in ('approved', 'active')
    for update;

    if locked_driver_id is null then
      raise exception 'Driver is no longer online or available. Please choose another driver.';
    end if;

    if exists (
      select 1 from public.rides r
      where r.driver_id = requested_driver
        and r.status in ('searching', 'accepted', 'arrived', 'started')
    ) then
      raise exception 'Driver already has an active ride. Please choose another driver.';
    end if;
  end if;

  insert into public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status
  ) values (
    client_ride_id, auth.uid(), requested_driver, passenger_name, passenger_phone, requested_vehicle,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, calculated_fare, platform_commission,
    calculated_fare - platform_commission, payment_method, 'searching'
  ) returning * into result;

  return result;
end;
$$;

revoke all on function public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text
) from public;
grant execute on function public.request_ride_with_id(
  text, uuid, public.vehicle_type, text, text, text,
  double precision, double precision, text, text,
  double precision, double precision, text, numeric, integer, text
) to authenticated;

-- The same driver may safely repeat Accept for the same ride. Only the first
-- successful transition writes history/notification and marks the driver busy.
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
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select * into current_ride
  from public.rides
  where id = ride_id
  for update;
  if not found then return false; end if;

  if current_ride.status = 'accepted' and current_ride.driver_id = auth.uid() then
    return true;
  end if;

  if current_ride.status <> 'searching'
    or (current_ride.driver_id is not null and current_ride.driver_id <> auth.uid()) then
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
    select 1 from public.rides r
    where r.driver_id = auth.uid()
      and r.id <> current_ride.id
      and r.status in ('searching', 'accepted', 'arrived', 'started')
  ) into has_other_active_ride;
  if has_other_active_ride then return false; end if;

  -- New requests remain available until this point. The assigned-ride clause
  -- heals legacy requests that were incorrectly pre-reserved as unavailable.
  if (not current_driver.is_available or not current_presence.is_available)
    and current_ride.driver_id is distinct from auth.uid() then
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

  insert into public.ride_status_history (ride_id, from_status, to_status, changed_by)
  values (current_ride.id, 'searching', 'accepted', auth.uid());
  insert into public.notifications (id, user_id, sender_id, ride_id, type, title, body)
  values (
    gen_random_uuid()::text, current_ride.passenger_id, auth.uid(), current_ride.id,
    'ride_accepted', 'Driver Accepted', 'A driver has accepted your ride request.'
  );
  return true;
end;
$$;

revoke all on function public.accept_ride(text) from public;
grant execute on function public.accept_ride(text) to authenticated;
