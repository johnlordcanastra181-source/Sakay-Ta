-- Optimized Admin Database Endpoints (Pagination, Server-side filtering, No N+1)
-- This migration introduces RPC functions to dramatically speed up the Admin Web Portal.

-- 1. Admin Passengers List (Paginated)
create or replace function public.get_admin_passengers_paginated(
  search_term text,
  status_filter text,
  limit_val int,
  offset_val int
)
returns table (
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
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin(auth.uid()) then
    raise exception 'administrator authorization required'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  select 
    p.id,
    p.full_name,
    p.email,
    p.mobile,
    p.email_verified,
    p.account_status as status,
    p.address,
    p.created_at,
    p.updated_at,
    array['passenger']::text[] as roles
  from public.passenger_profiles pp
  join public.profiles p on p.id = pp.user_id
  left join public.drivers d on d.user_id = pp.user_id
  left join public.admin_roles ar on ar.user_id = pp.user_id
  where d.user_id is null
    and ar.user_id is null
    and (status_filter = 'all' or p.account_status = status_filter)
    and (
      search_term = '' or 
      p.full_name ilike '%' || search_term || '%' or
      p.email ilike '%' || search_term || '%' or
      p.mobile ilike '%' || search_term || '%'
    )
  order by p.created_at desc
  limit limit_val
  offset offset_val;
end;
$$;

revoke all on function public.get_admin_passengers_paginated(text, text, int, int) from public;
grant execute on function public.get_admin_passengers_paginated(text, text, int, int) to authenticated;

