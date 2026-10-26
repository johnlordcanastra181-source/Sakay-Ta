-- Lock Driver Registered Vehicle Details after Registration
-- Drivers cannot modify registered vehicle type, plate number, make, model, year, color, or TODA affiliation.
-- Only authorized administrators can update vehicle assignments.

-- 1. Revoke update privileges on registered vehicle columns from authenticated users (drivers)
revoke update (
  vehicle_type,
  plate_number,
  vehicle_make,
  vehicle_model,
  vehicle_year,
  vehicle_color,
  toda_id
) on public.drivers from authenticated;

-- Ensure authenticated drivers still retain update on their operational and location fields
grant update (
  is_online,
  is_available,
  current_latitude,
  current_longitude,
  last_location_at,
  updated_at
) on public.drivers to authenticated;

-- 2. Trigger function to prevent non-admin modifications to approved vehicle details
create or replace function public.prevent_driver_vehicle_details_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Administrators (is_admin()) are permitted to update vehicle details during fleet management.
  if not public.is_admin() then
    if (new.vehicle_type is distinct from old.vehicle_type) or
       (new.plate_number is distinct from old.plate_number) or
       (new.vehicle_make is distinct from old.vehicle_make) or
       (new.vehicle_model is distinct from old.vehicle_model) or
       (new.vehicle_year is distinct from old.vehicle_year) or
       (new.vehicle_color is distinct from old.vehicle_color) or
       (new.toda_id is distinct from old.toda_id) then
      raise exception 'Registered vehicle details are locked and cannot be modified by the driver'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_lock_driver_vehicle_details on public.drivers;
create trigger trg_lock_driver_vehicle_details
  before update on public.drivers
  for each row
  execute function public.prevent_driver_vehicle_details_mutation();

