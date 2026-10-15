create or replace function public.get_admin_drivers_paginated(
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
    array['driver']::text[] as roles
  from public.drivers d
  join public.profiles p on p.id = d.user_id
  where (status_filter = 'all' or p.account_status = status_filter)
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

revoke all on function public.get_admin_drivers_paginated(text, text, int, int) from public;
grant execute on function public.get_admin_drivers_paginated(text, text, int, int) to authenticated;

