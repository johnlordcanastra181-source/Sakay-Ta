CREATE OR REPLACE FUNCTION public.accept_ride(ride_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_ride public.rides%rowtype;
  current_driver public.drivers%rowtype;
  current_presence public.driver_presence%rowtype;
BEGIN
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select * into current_ride from public.rides where id = ride_id::uuid for update;
  if not found then return false; end if;

  select * into current_driver from public.drivers
  where user_id = auth.uid() for update;
  select * into current_presence from public.driver_presence
  where driver_id = auth.uid() for update;

  if not found
    or current_driver.application_status not in ('approved', 'active')
    or current_presence.driver_id is null
    or not current_presence.is_online
    or (not current_presence.is_available and current_ride.driver_id is distinct from auth.uid()) then
    return false;
  end if;

  if current_ride.status <> 'searching'
    or (current_ride.driver_id is not null and current_ride.driver_id <> auth.uid())
    or current_ride.vehicle_type <> current_presence.vehicle_type then
    return false;
  end if;

  update public.rides set
    driver_id = auth.uid(), status = 'accepted', accepted_at = now()
  where id = ride_id::uuid;
  update public.drivers set is_available = false where user_id = auth.uid();
  update public.driver_presence set is_available = false where driver_id = auth.uid();
  insert into public.ride_status_history (ride_id, from_status, to_status, changed_by)
  values (ride_id::uuid, 'searching', 'accepted', auth.uid());
  insert into public.notifications (id, user_id, sender_id, ride_id, type, title, body)
  values (
    gen_random_uuid()::text, current_ride.passenger_id, auth.uid(), ride_id,
    'ride_accepted', 'Driver Accepted', 'A driver has accepted your ride request.'
  );
  return true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_ride(text) TO authenticated;
