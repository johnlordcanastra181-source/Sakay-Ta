-- 1. Update the trigger to fire on is_online and is_available changes
DROP TRIGGER IF EXISTS sync_driver_presence_trigger ON public.drivers;

CREATE TRIGGER sync_driver_presence_trigger
  AFTER UPDATE OF
  is_online, is_available, current_latitude, current_longitude, last_location_at
  ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_driver_presence();

-- 2. Update nearby_drivers RPC to return is_online, is_available and remove the 30-min restriction
DROP FUNCTION IF EXISTS public.nearby_drivers(double precision, double precision, public.vehicle_type, double precision);

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
  distance_km double precision,
  is_online boolean,
  is_available boolean
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
    )) as distance_km,
    presence.is_online,
    presence.is_available
  from public.drivers d
  join public.profiles p on p.id = d.user_id
  join public.driver_presence presence on presence.driver_id = d.user_id
  where auth.uid() is not null
    and d.application_status in ('approved', 'active')
    and p.account_status in ('approved', 'active')
    and presence.latitude is not null and presence.longitude is not null
    and (requested_vehicle is null or presence.vehicle_type = requested_vehicle)
    and 6371 * 2 * asin(sqrt(
      power(sin(radians(presence.latitude - passenger_latitude) / 2), 2) +
      cos(radians(passenger_latitude)) * cos(radians(presence.latitude)) *
      power(sin(radians(presence.longitude - passenger_longitude) / 2), 2)
    )) <= greatest(radius_km, 0)
  order by distance_km asc;
$$;
GRANT EXECUTE ON FUNCTION public.nearby_drivers TO authenticated;
