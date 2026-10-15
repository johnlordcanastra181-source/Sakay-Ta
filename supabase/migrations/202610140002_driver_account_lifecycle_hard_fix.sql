-- ============================================================================
-- Migration: 202610140002_driver_account_lifecycle_hard_fix.sql
-- Description:
-- 1. Updates get_admin_drivers_paginated to reflect authoritative driver status
--    (Approved, Pending, Rejected) and include rejected applications.
-- 2. Updates can_delete_accounts to permit all active administrators.
-- 3. Updates admin_prepare_account_deletion to clean up linked driver_applications.
-- ============================================================================

-- 0. Expand driver_applications status check to allow approved and deleted
ALTER TABLE public.driver_applications DROP CONSTRAINT IF EXISTS driver_applications_status_check;
ALTER TABLE public.driver_applications ADD CONSTRAINT driver_applications_status_check
  CHECK (status IN ('uploading', 'pending', 'provisioning', 'provisioning_failed', 'awaiting_activation', 'approved', 'active', 'rejected', 'deleted'));


-- 1. Permissive administrator check for account deletion (Active admin or super_admin)
CREATE OR REPLACE FUNCTION public.can_delete_accounts(check_user uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT check_user IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.admin_roles ar
    WHERE ar.user_id = check_user
      AND ar.status = 'active'
      AND ar.role IN ('admin', 'super_admin')
  );
$$;

REVOKE ALL ON FUNCTION public.can_delete_accounts(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.can_delete_accounts(uuid) TO authenticated;

-- 2. Account deletion preparation: Disassociate driver_applications and clear driver records
CREATE OR REPLACE FUNCTION public.admin_prepare_account_deletion(
  target_user uuid,
  target_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  target_is_passenger boolean;
  target_is_driver boolean;
  existing_job public.account_deletion_jobs%ROWTYPE;
  new_audit_id uuid;
  shared_ride_count integer := 0;
  retained_payment_count integer := 0;
  retained_earning_count integer := 0;
  cancelled_active_ride_count integer := 0;
  active_ride record;
  target_profile_photo_path text;
  target_document_paths jsonb := '[]'::jsonb;
  target_storage_paths jsonb := '{}'::jsonb;
BEGIN
  IF caller IS NULL OR NOT public.can_delete_accounts(caller) THEN
    RAISE EXCEPTION 'Administrator account-deletion permission is required.';
  END IF;
  IF target_user IS NULL THEN
    RAISE EXCEPTION 'A valid target account is required.';
  END IF;
  IF target_user = caller THEN
    RAISE EXCEPTION 'An administrator cannot delete the account currently in use.';
  END IF;
  IF target_type NOT IN ('passenger', 'driver') THEN
    RAISE EXCEPTION 'Unsupported account type.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.admin_roles ar WHERE ar.user_id = target_user
  ) THEN
    RAISE EXCEPTION 'Administrator accounts must be managed from Admin Accounts.';
  END IF;

  SELECT *
  INTO existing_job
  FROM public.account_deletion_jobs
  WHERE target_user_id = target_user
  FOR UPDATE;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', CASE WHEN existing_job.status = 'completed'
        THEN 'completed' ELSE 'ready_for_auth_deletion' END,
      'target_user_id', target_user,
      'target_account_type', existing_job.target_account_type,
      'audit_id', existing_job.audit_id,
      'storage_paths', existing_job.storage_paths,
      'storage_deleted', existing_job.storage_deleted,
      'idempotent_retry', true
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.passenger_profiles pp WHERE pp.user_id = target_user
  ) INTO target_is_passenger;
  SELECT EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.user_id = target_user
  ) INTO target_is_driver;

  IF target_type = 'passenger' AND NOT target_is_passenger THEN
    RAISE EXCEPTION 'Passenger account was not found.';
  END IF;
  IF target_type = 'driver' AND NOT target_is_driver THEN
    -- Check if target exists in profiles or driver_applications before raising not found
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = target_user) AND
       NOT EXISTS (SELECT 1 FROM public.driver_applications da WHERE da.auth_user_id = target_user) THEN
      RAISE EXCEPTION 'Driver account was not found.';
    END IF;
  END IF;

  SELECT p.profile_photo_path
  INTO target_profile_photo_path
  FROM public.profiles p
  WHERE p.id = target_user;

  IF target_is_driver THEN
    SELECT COALESCE(jsonb_agg(dd.storage_path), '[]'::jsonb)
    INTO target_document_paths
    FROM public.driver_documents dd
    WHERE dd.driver_id = target_user;
  END IF;

  target_storage_paths := jsonb_build_object(
    'avatars', jsonb_build_array(format('%s/profile.jpg', target_user)) ||
      CASE WHEN NULLIF(BTRIM(target_profile_photo_path), '') IS NULL
        THEN '[]'::jsonb
        ELSE jsonb_build_array(target_profile_photo_path)
      END,
    'driver_documents', target_document_paths
  );

  SELECT count(*)::integer INTO shared_ride_count
  FROM public.rides r
  WHERE r.passenger_id = target_user OR r.driver_id = target_user;

  SELECT count(*)::integer INTO retained_payment_count
  FROM public.payments p
  WHERE p.passenger_id = target_user OR p.driver_id = target_user;

  IF target_is_driver THEN
    SELECT count(*)::integer INTO retained_earning_count
    FROM public.driver_earnings e
    WHERE e.driver_id = target_user;
  END IF;

  INSERT INTO public.account_deletion_audit (
    target_user_id, target_account_type, initiated_by, status, details
  ) VALUES (
    target_user, target_type, caller, 'started',
    jsonb_build_object(
      'shared_ride_count', shared_ride_count,
      'retained_payment_count', retained_payment_count,
      'retained_earning_count', retained_earning_count
    )
  ) RETURNING id INTO new_audit_id;

  -- Cancel active rides
  FOR active_ride IN
    SELECT r.id, r.status, r.passenger_id, r.driver_id
    FROM public.rides r
    WHERE (r.passenger_id = target_user OR r.driver_id = target_user)
      AND r.status IN ('searching', 'accepted', 'arrived', 'started')
    ORDER BY r.created_at, r.id
    FOR UPDATE
  LOOP
    UPDATE public.rides
    SET status = 'cancelled',
        cancelled_at = now(),
        cancellation_reason = 'Account removed by administrator',
        updated_at = now()
    WHERE id = active_ride.id;

    INSERT INTO public.ride_status_history
      (ride_id, from_status, to_status, changed_by, reason)
    VALUES (
      active_ride.id,
      active_ride.status,
      'cancelled',
      caller,
      'Account removed by administrator'
    );

    IF active_ride.driver_id IS NOT NULL
       AND active_ride.driver_id <> target_user THEN
      UPDATE public.drivers
      SET is_available = is_online, updated_at = now()
      WHERE user_id = active_ride.driver_id;
      UPDATE public.driver_presence
      SET is_available = is_online, updated_at = now()
      WHERE driver_id = active_ride.driver_id;
      INSERT INTO public.notifications
        (id, user_id, sender_id, ride_id, type, title, body)
      VALUES (
        gen_random_uuid()::text,
        active_ride.driver_id,
        caller,
        active_ride.id,
        'ride_cancelled',
        'Ride cancelled',
        'This ride was cancelled because the passenger account was removed.'
      );
    END IF;

    IF active_ride.passenger_id IS NOT NULL
       AND active_ride.passenger_id <> target_user THEN
      INSERT INTO public.notifications
        (id, user_id, sender_id, ride_id, type, title, body)
      VALUES (
        gen_random_uuid()::text,
        active_ride.passenger_id,
        caller,
        active_ride.id,
        'ride_cancelled',
        'Ride cancelled',
        'This ride was cancelled because the driver account was removed.'
      );
    END IF;

    cancelled_active_ride_count := cancelled_active_ride_count + 1;
  END LOOP;

  UPDATE public.account_deletion_audit
  SET details = details || jsonb_build_object(
    'cancelled_active_ride_count', cancelled_active_ride_count
  )
  WHERE id = new_audit_id;

  -- Delete owned records
  DELETE FROM public.notifications WHERE user_id = target_user;
  UPDATE public.notifications SET sender_id = NULL WHERE sender_id = target_user;
  UPDATE public.admin_roles SET created_by = NULL WHERE created_by = target_user;
  UPDATE public.drivers SET reviewed_by = NULL WHERE reviewed_by = target_user;
  UPDATE public.driver_documents SET reviewed_by = NULL WHERE reviewed_by = target_user;
  UPDATE public.withdrawals SET processed_by = NULL WHERE processed_by = target_user;
  UPDATE public.reports SET resolved_by = NULL WHERE resolved_by = target_user;
  UPDATE public.fare_matrix SET updated_by = NULL WHERE updated_by = target_user;
  UPDATE public.fare_matrix_history SET changed_by = NULL WHERE changed_by = target_user;
  UPDATE public.account_deletion_audit SET initiated_by = NULL WHERE initiated_by = target_user;
  UPDATE public.account_deletion_jobs SET initiated_by = NULL WHERE initiated_by = target_user;
  DELETE FROM public.saved_places WHERE user_id = target_user;
  DELETE FROM public.bookings WHERE passenger_id = target_user;
  DELETE FROM public.chat_messages WHERE sender_id = target_user;
  DELETE FROM public.reports WHERE reporter_id = target_user;

  UPDATE public.ratings SET passenger_id = NULL WHERE passenger_id = target_user;
  UPDATE public.ratings SET driver_id = NULL WHERE driver_id = target_user;

  UPDATE public.reports
  SET reported_user_id = NULL,
      reported_user_name = 'Deleted account',
      reported_user_role = NULL
  WHERE reported_user_id = target_user;
  UPDATE public.ride_status_history SET changed_by = NULL WHERE changed_by = target_user;

  UPDATE public.payments SET passenger_id = NULL WHERE passenger_id = target_user;
  UPDATE public.payments SET driver_id = NULL WHERE driver_id = target_user;
  UPDATE public.driver_earnings SET driver_id = NULL WHERE driver_id = target_user;
  UPDATE public.withdrawals SET driver_id = NULL, account_details = '{}'::jsonb WHERE driver_id = target_user;
  UPDATE public.wallet_transactions SET user_id = NULL WHERE user_id = target_user;

  UPDATE public.rides
  SET passenger_id = NULL,
      passenger_name = 'Deleted passenger',
      passenger_phone = ''
  WHERE passenger_id = target_user;
  UPDATE public.rides SET driver_id = NULL WHERE driver_id = target_user;

  IF target_is_driver OR target_type = 'driver' THEN
    -- Clean up application links and operational records
    UPDATE public.driver_applications
    SET auth_user_id = NULL, status = 'deleted', updated_at = now()
    WHERE auth_user_id = target_user
       OR id IN (SELECT approved_application_id FROM public.drivers WHERE user_id = target_user);

    DELETE FROM public.driver_online_sessions WHERE driver_id = target_user;
    DELETE FROM public.driver_documents WHERE driver_id = target_user;
    DELETE FROM public.driver_presence WHERE driver_id = target_user;
    DELETE FROM public.toda_associations WHERE driver_id = target_user;
    DELETE FROM public.drivers WHERE user_id = target_user;
  END IF;

  IF target_is_passenger THEN
    DELETE FROM public.passenger_profiles WHERE user_id = target_user;
  END IF;

  UPDATE public.profiles
  SET firebase_uid = NULL,
      full_name = 'Deleted account',
      email = NULL,
      mobile = NULL,
      email_verified = false,
      account_status = 'deactivated',
      address = NULL,
      latitude = NULL,
      longitude = NULL,
      location_updated_at = NULL,
      profile_photo_path = NULL,
      avatar_color = 0,
      updated_at = now()
  WHERE id = target_user;

  INSERT INTO public.account_deletion_jobs (
    target_user_id, target_account_type, initiated_by, audit_id,
    status, storage_paths, storage_deleted
  ) VALUES (
    target_user, target_type, caller, new_audit_id,
    'ready_for_auth_deletion', target_storage_paths, false
  ) ON CONFLICT (target_user_id) DO UPDATE SET
    status = 'ready_for_auth_deletion',
    storage_paths = excluded.storage_paths,
    storage_deleted = false,
    last_error_code = null,
    updated_at = now();

  UPDATE public.account_deletion_audit
  SET status = 'db_prepared'
  WHERE id = new_audit_id;

  RETURN jsonb_build_object(
    'status', 'ready_for_auth_deletion',
    'target_user_id', target_user,
    'target_account_type', target_type,
    'audit_id', new_audit_id,
    'storage_paths', target_storage_paths,
    'storage_deleted', false,
    'cancelled_active_ride_count', cancelled_active_ride_count,
    'shared_ride_count', shared_ride_count,
    'retained_payment_count', retained_payment_count,
    'retained_earning_count', retained_earning_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_prepare_account_deletion(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_prepare_account_deletion(uuid, text) TO authenticated;

-- 3. Authoritative Drivers List with proper Approved, Pending, and Rejected Statuses
CREATE OR REPLACE FUNCTION public.get_admin_drivers_paginated(
  search_term text,
  status_filter text,
  limit_val int,
  offset_val int
)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  mobile text,
  email_verified boolean,
  status text,
  address text,
  created_at timestamptz,
  updated_at timestamptz,
  roles text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'administrator authorization required'
      USING errcode = 'insufficient_privilege';
  END IF;

  RETURN QUERY
  WITH combined_drivers AS (
    -- Approved and active drivers from drivers table
    SELECT 
      p.id,
      p.full_name,
      p.email,
      p.mobile,
      p.email_verified,
      CASE 
        WHEN d.application_status::text IN ('approved', 'active') THEN 'approved'
        WHEN d.application_status::text = 'suspended' THEN 'suspended'
        WHEN d.application_status::text = 'rejected' THEN 'rejected'
        ELSE COALESCE(d.application_status::text, p.account_status::text, 'pending')
      END AS status,
      p.address,
      p.created_at,
      p.updated_at,
      ARRAY['driver']::text[] AS roles
    FROM public.drivers d
    JOIN public.profiles p ON p.id = d.user_id

    UNION ALL

    -- Rejected driver applications that have not been cleared from history
    -- and do not have an active driver profile
    SELECT
      da.id,
      da.full_name,
      da.email,
      da.mobile,
      false AS email_verified,
      'rejected' AS status,
      da.address,
      da.submitted_at AS created_at,
      da.updated_at,
      ARRAY['driver']::text[] AS roles
    FROM public.driver_applications da
    WHERE da.status = 'rejected'
      AND da.history_cleared_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.drivers d2
        WHERE d2.approved_application_id = da.id
           OR (da.auth_user_id IS NOT NULL AND d2.user_id = da.auth_user_id)
      )
  )
  SELECT 
    cd.id,
    cd.full_name,
    cd.email,
    cd.mobile,
    cd.email_verified,
    cd.status,
    cd.address,
    cd.created_at,
    cd.updated_at,
    cd.roles
  FROM combined_drivers cd
  WHERE (
    status_filter = 'all' OR
    (status_filter = 'active' AND cd.status IN ('active', 'approved')) OR
    (status_filter = 'approved' AND cd.status IN ('active', 'approved')) OR
    (status_filter = cd.status)
  )
  AND (
    search_term = '' OR 
    cd.full_name ILIKE '%' || search_term || '%' OR
    cd.email ILIKE '%' || search_term || '%' OR
    cd.mobile ILIKE '%' || search_term || '%'
  )
  ORDER BY cd.created_at DESC
  LIMIT limit_val
  OFFSET offset_val;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_drivers_paginated(text, text, int, int) FROM public;
GRANT EXECUTE ON FUNCTION public.get_admin_drivers_paginated(text, text, int, int) TO authenticated;
