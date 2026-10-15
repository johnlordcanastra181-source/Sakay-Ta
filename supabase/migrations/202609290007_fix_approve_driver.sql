CREATE OR REPLACE FUNCTION public.approve_driver(target_driver uuid, approved boolean, rejection_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  begin
    if not public.is_admin() then raise exception 'admin authorization required'; end if;
    
    update public.drivers set
      application_status = case when approved then 'approved'::public.account_status else 'rejected'::public.account_status end,
      rejection_reason = case when approved then null else rejection_reason end,
      reviewed_at = now(), reviewed_by = auth.uid(),
      is_online = case when approved then is_online else false end,
      is_available = case when approved then is_available else false end
    where user_id = target_driver;
    
    if not found then raise exception 'driver not found'; end if;

    -- Also update their global profile account_status so they appear in passenger discovery
    update public.profiles set
      account_status = case when approved then 'active'::public.account_status else 'rejected'::public.account_status end
    where id = target_driver;

    update public.driver_presence set
      is_online = case when approved then is_online else false end,
      is_available = case when approved then is_available else false end
    where driver_id = target_driver;
    
    insert into public.notifications (id, user_id, sender_id, type, title, body)
    values (
      gen_random_uuid()::text, target_driver, auth.uid(), 'driver_verification',
      case when approved then 'Application Approved' else 'Application Rejected' end,
      case when approved then 'Your driver application was approved.'
           else 'Your driver application was rejected. ' || coalesce(rejection_reason, '') end
    );
  end;
$$;

-- Also dynamically heal any existing approved drivers whose profiles are still stuck in pending
UPDATE public.profiles p
SET account_status = 'active'::public.account_status
FROM public.drivers d
WHERE p.id = d.user_id 
  AND d.application_status = 'approved'
  AND p.account_status = 'pending';
