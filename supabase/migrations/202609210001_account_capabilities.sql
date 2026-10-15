-- Account capability repair. Authentication remains owned by auth.users.
-- Passenger capability is created explicitly by the passenger signup flow;
-- drivers and admins are not passengers merely because they have a profile.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, mobile, email_verified)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.email,
    new.phone,
    coalesce(new.email_confirmed_at is not null, false)
  )
  on conflict (id) do update set
    email = excluded.email,
    mobile = excluded.mobile,
    email_verified = excluded.email_verified;
  return new;
end;
$$;

-- These rows are provably incorrect only when the same canonical Auth UUID has
-- an active admin role and no driver capability. Driver/passenger dual-role
-- accounts are preserved.
delete from public.passenger_profiles pp
using public.admin_roles ar
where pp.user_id = ar.user_id
  and ar.status = 'active'
  and not exists (
    select 1
    from public.drivers d
    where d.user_id = pp.user_id
  );

-- Keep the trigger definition explicit after replacing the function body.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email, phone, email_confirmed_at on auth.users
for each row execute function public.handle_new_auth_user();
