-- 1. Modify nearby_drivers to NOT filter out offline drivers so they remain visible (Dart handles bookable UI state)
CREATE OR REPLACE FUNCTION public.nearby_drivers(
  passenger_latitude double precision,
  passenger_longitude double precision,
  requested_vehicle public.vehicle_type default null,
  radius_km double precision default 10
)
RETURNS TABLE (
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
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
    -- Intentionally removed is_online / is_available here so offline drivers remain visible
    -- The Dart UI model checks isOnline and disables the Book button natively.
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

GRANT EXECUTE ON FUNCTION public.nearby_drivers TO authenticated;

-- 2. Create the missing request_ride_with_id RPC required by Dart booking flow
CREATE OR REPLACE FUNCTION public.request_ride_with_id(
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
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  config public.fare_config%rowtype;
  calculated_fare numeric;
  platform_commission numeric;
  result public.rides%rowtype;
BEGIN
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if distance_km < 0 or duration_minutes < 0 then raise exception 'invalid route metrics'; end if;
  if pickup_latitude not between -90 and 90 or destination_latitude not between -90 and 90
    or pickup_longitude not between -180 and 180 or destination_longitude not between -180 and 180 then
    raise exception 'invalid coordinates';
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

  -- ATOMIC BACKEND VALIDATION: NEVER book an offline driver!
  if requested_driver is not null and not exists (
    select 1 from public.driver_presence presence
    where presence.driver_id = requested_driver
      and presence.vehicle_type = requested_vehicle
      and presence.is_online and presence.is_available
      and public.is_approved_driver(requested_driver)
  ) then raise exception 'selected driver is not available'; end if;

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
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_ride_with_id TO authenticated;
