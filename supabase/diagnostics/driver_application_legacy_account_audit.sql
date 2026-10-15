-- Read-only classification of accounts created by the former submit-before-
-- approval flow. Run in the Supabase SQL editor before any cleanup decision.
-- This query intentionally deletes or alters nothing.
select
  d.user_id,
  p.email,
  d.application_status,
  d.submitted_at,
  d.reviewed_at,
  d.reviewed_by,
  d.total_trips,
  d.lifetime_earnings,
  (select count(*) from public.rides r where r.driver_id = d.user_id) as ride_rows,
  (select count(*) from public.driver_earnings e where e.driver_id = d.user_id) as earning_rows,
  exists (select 1 from public.passenger_profiles pp where pp.user_id = d.user_id)
    as also_passenger,
  exists (select 1 from public.admin_roles ar where ar.user_id = d.user_id)
    as also_admin,
  case
    when d.application_status in ('approved', 'active') then 'preserve_approved_driver'
    when d.application_status = 'pending' then 'legacy_pending_auth_account_review_manually'
    when d.application_status = 'rejected' then 'legacy_rejected_auth_account_review_manually'
    else 'preserve_and_review_manually'
  end as recommended_review
from public.drivers d
join public.profiles p on p.id = d.user_id
order by d.submitted_at desc;

-- Candidate Auth accounts with a profile but no recognized role capability.
-- The former preapproval signup wrote no durable "driver applicant" marker,
-- so these rows cannot be safely auto-classified or deleted; review manually.
select
  au.id as auth_user_id,
  au.email,
  au.created_at as auth_created_at,
  au.raw_user_meta_data ->> 'full_name' as metadata_full_name,
  p.account_status,
  case
    when p.id is null then 'auth_user_without_profile_review_manually'
    else 'profile_without_driver_passenger_or_admin_role_review_manually'
  end as recommended_review
from auth.users au
left join public.profiles p on p.id = au.id
left join public.drivers d on d.user_id = au.id
left join public.passenger_profiles pp on pp.user_id = au.id
left join public.admin_roles ar on ar.user_id = au.id
where d.user_id is null
  and pp.user_id is null
  and ar.user_id is null
order by au.created_at desc;

