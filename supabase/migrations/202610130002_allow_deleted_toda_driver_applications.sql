-- Keep applications for review/retention if an Admin deletes an associated
-- TODA. The trigger continues to require an active TODA for normal Tricycle
-- inserts/updates; this check allows the FK's ON DELETE SET NULL action.
alter table public.driver_applications
  drop constraint if exists driver_applications_toda_vehicle_check;

alter table public.driver_applications
  add constraint driver_applications_toda_vehicle_check check (
    vehicle_type = 'tricycle' or
    (vehicle_type = 'habal' and toda_id is null)
  );
