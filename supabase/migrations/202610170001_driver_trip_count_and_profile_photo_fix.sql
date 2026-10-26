-- Migration: 202610170001_driver_trip_count_and_profile_photo_fix.sql
-- Description:
-- 1. Update public.nearby_drivers RPC to return completed_trips and resolve profile_photo_path.
-- 2. Add Storage RLS policy allowing authenticated users to read driver profile photos in driver-documents.
-- 3. Backfill profiles.profile_photo_path for approved drivers from driver_documents and driver_applications.
-- 4. Synchronize drivers.total_trips with actual completed rides from public.rides.
-- 5. Update public.approve_driver RPC to auto-sync profile photo path upon approval.

-- ============================================================================
-- 1. Update nearby_drivers RPC
-- ============================================================================
DROP FUNCTION IF EXISTS public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
);

CREATE FUNCTION public.nearby_drivers(
  passenger_latitude double precision,
  passenger_longitude double precision,
  requested_vehicle public.vehicle_type DEFAULT NULL,
  radius_km double precision DEFAULT 10
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
  is_available boolean,
  has_active_ride boolean,
  has_live_session boolean,
  completed_trips integer
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
  p_passenger_latitude double precision := passenger_latitude;
  p_passenger_longitude double precision := passenger_longitude;
  p_requested_vehicle public.vehicle_type := requested_vehicle;
  p_radius_km double precision := radius_km;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF p_passenger_latitude NOT BETWEEN -90 AND 90
     OR p_passenger_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid passenger coordinates';
  END IF;

  PERFORM public.expire_unanswered_ride_requests();

  RETURN QUERY
  SELECT
    d.user_id,
    p.full_name,
    COALESCE(
      NULLIF(BTRIM(p.profile_photo_path), ''),
      (SELECT dd.storage_path FROM public.driver_documents dd
       WHERE dd.driver_id = d.user_id AND dd.document_type = 'profile'
       ORDER BY dd.uploaded_at DESC LIMIT 1),
      (SELECT da.doc_profile FROM public.driver_applications da
       WHERE (da.auth_user_id = d.user_id OR da.id = d.approved_application_id)
         AND da.doc_profile IS NOT NULL
       ORDER BY da.submitted_at DESC LIMIT 1)
    ) AS profile_photo_path,
    dp.vehicle_type,
    dp.plate_number,
    dp.latitude,
    dp.longitude,
    dp.last_location_at,
    d.rating_average,
    d.rating_count,
    distance_data.distance_km,
    d.is_online,
    public.driver_is_requestable(d.user_id)
      AND NOT public.driver_has_conflicting_ride(d.user_id, NULL),
    public.driver_has_conflicting_ride(d.user_id, NULL),
    public.driver_has_live_session(d.user_id),
    COALESCE((
      SELECT COUNT(DISTINCT r.id)::integer
      FROM public.rides AS r
      WHERE r.driver_id = d.user_id
        AND r.status = 'completed'
    ), 0) AS completed_trips
  FROM public.drivers AS d
  JOIN public.profiles AS p ON p.id = d.user_id
  JOIN public.driver_presence AS dp ON dp.driver_id = d.user_id
  CROSS JOIN LATERAL (
    SELECT 6371.0 * 2 * pg_catalog.asin(pg_catalog.sqrt(
      pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
        dp.latitude - p_passenger_latitude
      ) / 2), 2)
      + pg_catalog.cos(pg_catalog.radians(p_passenger_latitude))
        * pg_catalog.cos(pg_catalog.radians(dp.latitude))
        * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(
            dp.longitude - p_passenger_longitude
          ) / 2), 2)
    )) AS distance_km
  ) AS distance_data
  WHERE d.application_status IN ('approved', 'active')
    AND p.account_status IN ('approved', 'active')
    AND dp.latitude BETWEEN -90 AND 90
    AND dp.longitude BETWEEN -180 AND 180
    AND dp.last_location_at IS NOT NULL
    AND dp.last_location_at <= pg_catalog.statement_timestamp() + interval '30 seconds'
    AND (p_requested_vehicle IS NULL OR dp.vehicle_type = p_requested_vehicle)
    AND distance_data.distance_km <= GREATEST(COALESCE(p_radius_km, 10), 0)
  ORDER BY distance_data.distance_km ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_drivers(
  double precision, double precision, public.vehicle_type, double precision
) TO authenticated;

-- ============================================================================
-- 2. Storage RLS Policy for Driver Profile Photos
-- ============================================================================
DROP POLICY IF EXISTS driver_documents_public_profile_photo_read ON storage.objects;
CREATE POLICY driver_documents_public_profile_photo_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND (
    (storage.foldername(name))[2] = 'profile'
    OR name LIKE '%/profile/%'
    OR EXISTS (
      SELECT 1 FROM public.driver_documents dd
      JOIN public.drivers d ON d.user_id = dd.driver_id
      WHERE dd.storage_path = storage.objects.name
        AND dd.document_type = 'profile'
        AND d.application_status IN ('approved', 'active')
    )
  )
);

-- ============================================================================
-- 3. Backfill profiles.profile_photo_path and drivers.total_trips
-- ============================================================================
UPDATE public.profiles p
SET profile_photo_path = COALESCE(
  (SELECT dd.storage_path FROM public.driver_documents dd
   WHERE dd.driver_id = p.id AND dd.document_type = 'profile'
   ORDER BY dd.uploaded_at DESC LIMIT 1),
  (SELECT da.doc_profile FROM public.driver_applications da
   WHERE (da.auth_user_id = p.id OR da.id = (SELECT approved_application_id FROM public.drivers WHERE user_id = p.id))
     AND da.doc_profile IS NOT NULL
   ORDER BY da.submitted_at DESC LIMIT 1)
),
updated_at = now()
WHERE p.id IN (SELECT user_id FROM public.drivers WHERE application_status IN ('approved', 'active'))
  AND NULLIF(BTRIM(p.profile_photo_path), '') IS NULL;

UPDATE public.drivers d
SET total_trips = COALESCE((
  SELECT COUNT(DISTINCT r.id)::integer
  FROM public.rides r
  WHERE r.driver_id = d.user_id
    AND r.status = 'completed'
), 0);

-- ============================================================================
-- 4. Update approve_driver RPC to auto-sync profile photo path
-- ============================================================================
CREATE OR REPLACE FUNCTION public.approve_driver(
  target_driver uuid,
  approved boolean,
  rejection_reason text default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin authorization required' USING errcode = '42501';
  END IF;

  UPDATE public.drivers
  SET application_status = CASE
        WHEN $2 THEN 'approved'::public.account_status
        ELSE 'rejected'::public.account_status
      END,
      rejection_reason = CASE WHEN $2 THEN null ELSE $3 END,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      is_online = false,
      is_available = false
  WHERE user_id = $1 AND application_status = 'pending';

  IF NOT found THEN
    IF EXISTS (SELECT 1 FROM public.drivers WHERE user_id = $1) THEN
      RAISE EXCEPTION 'driver application has already been reviewed' USING errcode = '40001';
    END IF;
    RAISE EXCEPTION 'driver not found' USING errcode = 'P0002';
  END IF;

  UPDATE public.profiles
  SET account_status = CASE
        WHEN $2 THEN 'active'::public.account_status
        ELSE 'rejected'::public.account_status
      END,
      profile_photo_path = CASE
        WHEN $2 AND NULLIF(BTRIM(profile_photo_path), '') IS NULL THEN
          COALESCE(
            (SELECT dd.storage_path FROM public.driver_documents dd
             WHERE dd.driver_id = $1 AND dd.document_type = 'profile'
             ORDER BY dd.uploaded_at DESC LIMIT 1),
            (SELECT da.doc_profile FROM public.driver_applications da
             WHERE (da.auth_user_id = $1 OR da.id = (SELECT approved_application_id FROM public.drivers WHERE user_id = $1))
               AND da.doc_profile IS NOT NULL
             ORDER BY da.submitted_at DESC LIMIT 1),
            profile_photo_path
          )
        ELSE profile_photo_path
      END
  WHERE id = $1;

  UPDATE public.driver_presence
  SET is_online = false, is_available = false
  WHERE driver_id = $1;

  INSERT INTO public.notifications (id, user_id, sender_id, type, title, body)
  VALUES (
    gen_random_uuid()::text, $1, auth.uid(), 'driver_verification',
    CASE WHEN $2 THEN 'Application Approved' ELSE 'Application Rejected' END,
    CASE WHEN $2 THEN 'Your driver application was approved.'
         ELSE 'Your driver application was rejected. ' || COALESCE($3, '') END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_driver(uuid, boolean, text) FROM public;
GRANT EXECUTE ON FUNCTION public.approve_driver(uuid, boolean, text) TO authenticated;

