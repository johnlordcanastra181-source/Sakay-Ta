-- Forward fix for the deployed account-deletion contract.
--
-- Migration 202610100002 created the auditable deletion workflow, but its
-- first version blocked active rides and unresolved financial rows and
-- required a DELETE text token. This migration replaces that RPC in place.
-- Financial rows remain restricted historical records: their real status and
-- amounts are retained, while references to the deleted identity are nulled.

DROP FUNCTION IF EXISTS public.admin_prepare_account_deletion(uuid, text, text);

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

  -- The primary key makes retries idempotent. Once database preparation has
  -- completed, a retry only needs to finish Storage/Auth cleanup.
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
    RAISE EXCEPTION 'Driver account was not found.';
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

  -- Resolve active rides in the same transaction instead of blocking account
  -- removal. This follows the established cancellation semantics: retain the
  -- ride, write status history, restore the surviving driver's availability,
  -- notify a surviving participant, and leave payment statuses unchanged.
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

  -- Delete records owned only by the selected account.
  DELETE FROM public.notifications WHERE user_id = target_user;
  UPDATE public.notifications SET sender_id = NULL WHERE sender_id = target_user;
  UPDATE public.admin_roles SET created_by = NULL WHERE created_by = target_user;
  UPDATE public.drivers SET reviewed_by = NULL WHERE reviewed_by = target_user;
  UPDATE public.driver_documents SET reviewed_by = NULL WHERE reviewed_by = target_user;
  UPDATE public.withdrawals SET processed_by = NULL WHERE processed_by = target_user;
  UPDATE public.reports SET resolved_by = NULL WHERE resolved_by = target_user;
  UPDATE public.fare_matrix SET updated_by = NULL WHERE updated_by = target_user;
  UPDATE public.fare_matrix_history SET changed_by = NULL WHERE changed_by = target_user;
  UPDATE public.account_deletion_audit
  SET initiated_by = NULL
  WHERE initiated_by = target_user;
  UPDATE public.account_deletion_jobs
  SET initiated_by = NULL
  WHERE initiated_by = target_user;
  DELETE FROM public.saved_places WHERE user_id = target_user;
  DELETE FROM public.bookings WHERE passenger_id = target_user;
  DELETE FROM public.chat_messages WHERE sender_id = target_user;
  DELETE FROM public.reports WHERE reporter_id = target_user;

  -- Keep rating scores for platform history while removing the deleted
  -- identity from the rating row.
  UPDATE public.ratings SET passenger_id = NULL WHERE passenger_id = target_user;
  UPDATE public.ratings SET driver_id = NULL WHERE driver_id = target_user;

  -- Preserve other users' reports and ride-status audit rows without retaining
  -- the deleted account as a live identity.
  UPDATE public.reports
  SET reported_user_id = NULL,
      reported_user_name = 'Deleted account',
      reported_user_role = NULL
  WHERE reported_user_id = target_user;
  UPDATE public.ride_status_history SET changed_by = NULL WHERE changed_by = target_user;

  -- Preserve shared payment/earning facts and every original status while
  -- removing ownership links and private payout details.
  UPDATE public.payments
  SET passenger_id = NULL
  WHERE passenger_id = target_user;
  UPDATE public.payments
  SET driver_id = NULL
  WHERE driver_id = target_user;
  UPDATE public.driver_earnings
  SET driver_id = NULL
  WHERE driver_id = target_user;
  UPDATE public.withdrawals
  SET driver_id = NULL, account_details = '{}'::jsonb
  WHERE driver_id = target_user;
  UPDATE public.wallet_transactions
  SET user_id = NULL
  WHERE user_id = target_user;

  -- Keep rides and fare/status history for the remaining party and financial
  -- audit integrity. Remove the deleted passenger's direct PII.
  UPDATE public.rides
  SET passenger_id = NULL,
      passenger_name = 'Deleted passenger',
      passenger_phone = ''
  WHERE passenger_id = target_user;
  UPDATE public.rides SET driver_id = NULL WHERE driver_id = target_user;

  -- Remove driver-owned operational/verification data. The TODA row itself is
  -- shared and is intentionally not touched.
  IF target_is_driver THEN
    DELETE FROM public.driver_online_sessions WHERE driver_id = target_user;
    DELETE FROM public.driver_documents WHERE driver_id = target_user;
    DELETE FROM public.driver_presence WHERE driver_id = target_user;
    DELETE FROM public.toda_associations WHERE driver_id = target_user;
    DELETE FROM public.drivers WHERE user_id = target_user;
  END IF;
  IF target_is_passenger THEN
    DELETE FROM public.passenger_profiles WHERE user_id = target_user;
  END IF;

  -- Scrub the profile before the external Auth call. If Auth deletion has a
  -- transient failure, the retryable job cannot leave usable personal data or
  -- an active passenger/driver capability behind.
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
    target_user_id, target_account_type, initiated_by, audit_id, status,
    storage_paths
  ) VALUES (
    target_user, target_type, caller, new_audit_id, 'db_prepared',
    target_storage_paths
  );

  UPDATE public.account_deletion_audit
  SET status = 'db_prepared'
  WHERE id = new_audit_id;

  RETURN jsonb_build_object(
    'status', 'ready_for_auth_deletion',
    'target_user_id', target_user,
    'target_account_type', target_type,
    'audit_id', new_audit_id,
    'storage_paths', target_storage_paths,
    'shared_ride_count', shared_ride_count,
    'retained_payment_count', retained_payment_count,
    'retained_earning_count', retained_earning_count,
    'cancelled_active_ride_count', cancelled_active_ride_count,
    'idempotent_retry', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_prepare_account_deletion(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_prepare_account_deletion(uuid, text)
  TO authenticated;
