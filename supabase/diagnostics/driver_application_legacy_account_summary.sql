-- Read-only production summary for the preapproval Auth-backed driver flow.
-- This returns counts and financial totals only; it performs no writes.
with driver_stats as (
  select
    d.application_status::text as driver_status,
    count(*)::bigint as driver_accounts,
    count(*) filter (
      where exists (select 1 from public.rides r where r.driver_id = d.user_id)
    )::bigint as accounts_with_rides,
    coalesce(sum(d.total_trips), 0)::bigint as recorded_driver_trips,
    coalesce(sum(d.lifetime_earnings), 0)::numeric as recorded_lifetime_earnings,
    coalesce(sum((
      select count(*) from public.driver_earnings e where e.driver_id = d.user_id
    )), 0)::bigint as driver_ledger_rows,
    coalesce(sum((
      select coalesce(sum(e.gross_amount), 0)
      from public.driver_earnings e where e.driver_id = d.user_id
    )), 0)::numeric as driver_ledger_gross,
    coalesce(sum((
      select coalesce(sum(e.net_amount), 0)
      from public.driver_earnings e where e.driver_id = d.user_id
    )), 0)::numeric as driver_ledger_net,
    count(*) filter (
      where exists (
        select 1 from public.passenger_profiles pp where pp.user_id = d.user_id
      )
    )::bigint as also_passenger,
    count(*) filter (
      where exists (select 1 from public.admin_roles ar where ar.user_id = d.user_id)
    )::bigint as also_admin
  from public.drivers d
  group by d.application_status
), unclassified as (
  select
    count(*) filter (where p.id is null)::bigint as auth_users_without_profiles,
    count(*) filter (where p.id is not null)::bigint
      as profiles_without_driver_passenger_or_admin
  from auth.users au
  left join public.profiles p on p.id = au.id
  left join public.drivers d on d.user_id = au.id
  left join public.passenger_profiles pp on pp.user_id = au.id
  left join public.admin_roles ar on ar.user_id = au.id
  where d.user_id is null
    and pp.user_id is null
    and ar.user_id is null
)
select jsonb_build_object(
  'new_driver_applications_table',
    to_regclass('public.driver_applications')::text,
  'legacy_driver_statuses', coalesce(
    (select jsonb_agg(to_jsonb(driver_stats) order by driver_status)
     from driver_stats), '[]'::jsonb
  ),
  'unclassified_auth_accounts', (select to_jsonb(unclassified) from unclassified)
);
