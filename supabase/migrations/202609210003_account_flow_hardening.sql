-- Account-flow hardening for the canonical Supabase schema.
-- Auth identity is auth.users.id -> profiles.id; role capability rows use the
-- same UUID through passenger_profiles.user_id, drivers.user_id, and
-- admin_roles.user_id.

-- A driver may save and resume the application fields owned by that driver.
-- Verification state, availability, ratings, earnings, and review metadata
-- intentionally remain outside this grant.
grant update (
  license_type,
  license_number,
  license_expiry,
  dl_codes,
  condition_codes,
  vehicle_type,
  plate_number,
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
  submitted_at,
  updated_at
) on public.drivers to authenticated;

-- The mobile client persists a private Storage object path in
-- driver_documents. A retried submit may write the same metadata row, but it
-- must never be able to approve or review its own documents.
create policy driver_documents_owner_retry_pending on public.driver_documents
for update to authenticated
using (driver_id = auth.uid() and status = 'pending')
with check (
  driver_id = auth.uid()
  and status = 'pending'
  and storage_path like auth.uid()::text || '/%'
);

grant update (storage_path) on public.driver_documents to authenticated;
