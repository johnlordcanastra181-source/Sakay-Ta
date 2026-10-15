-- Enforce the vehicle-specific TODA contract for every new/updated driver
-- application row. The referenced table is the Admin-managed public.todas.
-- New applicants have no Auth session yet, so expose only active TODA IDs,
-- names, and cities through this controlled signup RPC instead of granting
-- anonymous table access or weakening the existing RLS policy.
CREATE OR REPLACE FUNCTION public.get_driver_signup_todas()
RETURNS TABLE (id text, name text, city text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT t.id, t.name, t.city
  FROM public.todas AS t
  WHERE t.is_active = true
  ORDER BY lower(t.name), t.id;
$$;

REVOKE ALL ON FUNCTION public.get_driver_signup_todas()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_signup_todas()
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_driver_application_toda()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Preserve the existing Admin delete behavior: public.todas uses ON DELETE
  -- SET NULL, which runs as a nested referential-action trigger. A deleted
  -- association must not prevent its parent TODA record from being removed.
  IF TG_OP = 'UPDATE'
     AND pg_trigger_depth() > 1
     AND OLD.toda_id IS NOT NULL
     AND NEW.toda_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.vehicle_type = 'tricycle' THEN
    IF NEW.toda_id IS NULL OR NOT EXISTS (
      SELECT 1
      FROM public.todas AS t
      WHERE t.id = NEW.toda_id
        AND t.is_active = true
    ) THEN
      RAISE EXCEPTION 'Tricycle driver applications require an active TODA.'
        USING ERRCODE = '23514';
    END IF;
  ELSIF NEW.vehicle_type = 'habal' AND NEW.toda_id IS NOT NULL THEN
    RAISE EXCEPTION 'Habal-Habal driver applications must not include a TODA.'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_driver_application_toda()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS drivers_enforce_application_toda
  ON public.drivers;
CREATE TRIGGER drivers_enforce_application_toda
  BEFORE INSERT OR UPDATE OF vehicle_type, toda_id
  ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_driver_application_toda();

-- The existing schema already permits NULL for license_type, license_number,
-- license_expiry, dl_codes, and condition_codes; no license-schema migration
-- or RLS change is needed to represent an applicant who has no license.
