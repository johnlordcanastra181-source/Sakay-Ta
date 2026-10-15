-- Fix driver application submission (upsert) failure by granting UPDATE
-- on the remaining profile columns. Upsert requires UPDATE permission
-- on all included columns.

GRANT UPDATE (
  license_type,
  license_number,
  license_expiry,
  dl_codes,
  condition_codes,
  date_of_birth,
  sex,
  barangay,
  municipality,
  province
) ON public.drivers TO authenticated;
