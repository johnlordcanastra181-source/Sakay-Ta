-- PostgREST upsert requires UPDATE permissions on all columns provided in the payload.
-- The driver registration payload includes user_id and submitted_at.
-- We must grant UPDATE on all of them.

GRANT UPDATE (
  user_id,
  vehicle_type,
  plate_number,
  license_type,
  license_number,
  license_expiry,
  dl_codes,
  condition_codes,
  vehicle_make,
  vehicle_model,
  vehicle_year,
  vehicle_color,
  date_of_birth,
  sex,
  barangay,
  municipality,
  province,
  toda_id,
  submitted_at
) ON public.drivers TO authenticated;
