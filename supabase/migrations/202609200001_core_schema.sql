-- Sakay Ta Firebase -> Supabase migration
-- Core relational schema derived from the production Flutter models and
-- FirestoreService collection inventory. Apply with the Supabase CLI.

create extension if not exists pgcrypto;

create type public.vehicle_type as enum ('tricycle', 'habal');
create type public.ride_status as enum
  ('searching', 'accepted', 'arrived', 'started', 'completed', 'cancelled');
create type public.account_status as enum
  ('pending', 'approved', 'rejected', 'suspended', 'active', 'deactivated');

create table public.firebase_user_map (
  firebase_uid text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  migrated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  firebase_uid text unique,
  full_name text not null default '',
  email text,
  mobile text,
  email_verified boolean not null default false,
  account_status public.account_status not null default 'active',
  address text,
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  profile_photo_path text,
  avatar_color integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_latitude_check check (latitude is null or latitude between -90 and 90),
  constraint profiles_longitude_check check (longitude is null or longitude between -180 and 180)
);
create unique index profiles_email_unique on public.profiles (lower(email)) where email is not null and email <> '';
create unique index profiles_mobile_unique on public.profiles (mobile) where mobile is not null and mobile <> '';

create table public.admin_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null check (role in ('admin', 'super_admin')),
  status text not null default 'active' check (status in ('active', 'deactivated')),
  department text not null default 'Operations',
  permissions text[] not null default array[]::text[],
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);

create table public.passenger_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  ride_count integer not null default 0 check (ride_count >= 0),
  default_address text,
  saved_addresses jsonb not null default '[]'::jsonb,
  emergency_contacts jsonb not null default '[]'::jsonb,
  payment_methods jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.todas (
  id text primary key,
  name text not null,
  code text not null unique,
  city text not null,
  president text,
  contact_number text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.drivers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  firebase_uid text unique,
  application_status public.account_status not null default 'pending',
  is_online boolean not null default false,
  is_available boolean not null default false,
  vehicle_type public.vehicle_type not null,
  plate_number text not null,
  license_type text,
  license_number text,
  license_expiry date,
  dl_codes text,
  condition_codes text,
  vehicle_make text,
  vehicle_model text,
  vehicle_year integer,
  vehicle_color text,
  date_of_birth date,
  sex text,
  barangay text,
  municipality text,
  province text,
  toda_id text references public.todas(id) on delete set null,
  current_latitude double precision,
  current_longitude double precision,
  last_location_at timestamptz,
  rating_average numeric(3,2),
  rating_count integer not null default 0 check (rating_count >= 0),
  acceptance_count integer not null default 0,
  acceptance_total integer not null default 0,
  on_time_count integer not null default 0,
  total_trips integer not null default 0,
  lifetime_earnings numeric(12,2) not null default 0,
  rejection_reason text,
  suspension_reason text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drivers_location_check check (
    (current_latitude is null and current_longitude is null) or
    (current_latitude between -90 and 90 and current_longitude between -180 and 180)
  ),
  constraint drivers_rating_check check (rating_average is null or rating_average between 1 and 5)
);

create table public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(user_id) on delete cascade,
  document_type text not null check (document_type in (
    'license_front', 'license_back', 'license_selfie', 'or_cr', 'profile',
    'vehicle_front', 'vehicle_side', 'vehicle_back', 'barangay_clearance',
    'police_clearance', 'mayors_permit'
  )),
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  uploaded_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  unique (driver_id, document_type, storage_path)
);

-- Discovery-safe data is deliberately separated from private driver and
-- verification fields so Realtime subscriptions cannot leak license details.
create table public.driver_presence (
  driver_id uuid primary key references public.drivers(user_id) on delete cascade,
  vehicle_type public.vehicle_type not null,
  plate_number text not null default '',
  is_online boolean not null default false,
  is_available boolean not null default false,
  latitude double precision,
  longitude double precision,
  last_location_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint driver_presence_location_check check (
    (latitude is null and longitude is null) or
    (latitude between -90 and 90 and longitude between -180 and 180)
  )
);

create table public.toda_associations (
  id text primary key,
  toda_id text not null references public.todas(id) on delete cascade,
  driver_id uuid not null references public.drivers(user_id) on delete cascade,
  status public.account_status not null default 'pending',
  member_role text not null default 'member',
  created_at timestamptz not null default now(),
  unique (toda_id, driver_id)
);

create table public.fare_config (
  vehicle_type public.vehicle_type primary key,
  base_fare numeric(10,2) not null check (base_fare >= 0),
  base_km numeric(8,2) not null default 1 check (base_km >= 0),
  per_km_rate numeric(10,2) not null check (per_km_rate >= 0),
  commission_percent numeric(5,2) not null default 12 check (commission_percent between 0 and 100),
  night_diff_percent numeric(5,2) not null default 0 check (night_diff_percent between 0 and 100),
  senior_discount_percent numeric(5,2) not null default 20 check (senior_discount_percent between 0 and 100),
  student_discount_percent numeric(5,2) not null default 20 check (student_discount_percent between 0 and 100),
  pwd_discount_percent numeric(5,2) not null default 20 check (pwd_discount_percent between 0 and 100),
  effective_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);
insert into public.fare_config (vehicle_type, base_fare, base_km, per_km_rate)
values ('tricycle', 15, 1, 5), ('habal', 20, 1, 8)
on conflict (vehicle_type) do nothing;

create table public.rides (
  id text primary key,
  passenger_id uuid not null references public.profiles(id),
  driver_id uuid references public.drivers(user_id),
  passenger_name text not null default '',
  passenger_phone text not null default '',
  vehicle_type public.vehicle_type not null,
  pickup_address text not null,
  pickup_latitude double precision not null,
  pickup_longitude double precision not null,
  pickup_province text,
  destination_address text not null,
  destination_latitude double precision not null,
  destination_longitude double precision not null,
  destination_province text,
  distance_km numeric(10,3) not null check (distance_km >= 0),
  duration_minutes integer not null default 0 check (duration_minutes >= 0),
  fare numeric(12,2) not null check (fare >= 0),
  commission numeric(12,2) not null default 0 check (commission >= 0),
  driver_net numeric(12,2) not null default 0 check (driver_net >= 0),
  status public.ride_status not null default 'searching',
  payment_method text not null default 'cash' check (payment_method in ('cash', 'gcash', 'maya', 'card')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'pending', 'pending_payment', 'paid', 'failed', 'cancelled', 'refunded')),
  queued boolean not null default false,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  updated_at timestamptz not null default now(),
  constraint rides_pickup_check check (pickup_latitude between -90 and 90 and pickup_longitude between -180 and 180),
  constraint rides_destination_check check (destination_latitude between -90 and 90 and destination_longitude between -180 and 180)
);

create table public.ride_status_history (
  id bigint generated always as identity primary key,
  ride_id text not null references public.rides(id) on delete cascade,
  from_status public.ride_status,
  to_status public.ride_status not null,
  changed_by uuid references public.profiles(id),
  reason text,
  created_at timestamptz not null default now()
);

create table public.bookings (
  id text primary key,
  passenger_id uuid not null references public.profiles(id),
  vehicle_type public.vehicle_type not null,
  pickup_address text not null,
  destination_address text not null,
  pickup_latitude double precision not null,
  pickup_longitude double precision not null,
  destination_latitude double precision not null,
  destination_longitude double precision not null,
  payment_method text not null default 'cash',
  status text not null default 'requested',
  queued boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.ratings (
  id text primary key,
  ride_id text not null unique references public.rides(id) on delete cascade,
  passenger_id uuid not null references public.profiles(id),
  driver_id uuid not null references public.drivers(user_id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table public.payments (
  id text primary key,
  ride_id text not null unique references public.rides(id),
  passenger_id uuid not null references public.profiles(id),
  driver_id uuid references public.drivers(user_id),
  amount numeric(12,2) not null check (amount >= 0),
  platform_fee numeric(12,2) not null default 0,
  driver_net numeric(12,2) not null default 0,
  method text not null,
  provider text,
  provider_reference text,
  status text not null default 'pending' check (status in ('unpaid', 'pending', 'pending_payment', 'processing', 'paid', 'failed', 'cancelled', 'refunded')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.driver_earnings (
  id text primary key,
  driver_id uuid not null references public.drivers(user_id),
  ride_id text references public.rides(id),
  gross_amount numeric(12,2) not null default 0,
  commission numeric(12,2) not null default 0,
  net_amount numeric(12,2) not null,
  created_at timestamptz not null default now()
);

create table public.withdrawals (
  id text primary key,
  driver_id uuid not null references public.drivers(user_id),
  amount numeric(12,2) not null check (amount > 0),
  method text not null,
  account_details jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'approved', 'rejected', 'paid', 'completed', 'failed')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references public.profiles(id)
);

create table public.chat_messages (
  id text primary key,
  ride_id text not null references public.rides(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  sender_role text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  ride_id text references public.rides(id) on delete cascade,
  type text not null default 'general',
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id text primary key,
  user_id uuid not null references public.profiles(id),
  ride_id text references public.rides(id),
  type text not null,
  amount numeric(12,2) not null,
  description text,
  status text not null default 'completed',
  created_at timestamptz not null default now()
);

create table public.reports (
  id text primary key,
  reporter_id uuid not null references public.profiles(id),
  reporter_name text not null default '',
  reporter_role text not null default 'passenger',
  reporter_mobile text,
  reported_user_id uuid references public.profiles(id),
  reported_user_name text,
  reported_user_role text,
  ride_id text references public.rides(id),
  type text not null,
  title text not null,
  description text not null,
  status text not null default 'pending' check (status in ('pending', 'under_investigation', 'resolved', 'dismissed')),
  priority text not null default 'normal',
  admin_notes jsonb not null default '[]'::jsonb,
  resolution_summary text,
  resolved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.saved_places (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  category text not null default 'custom',
  created_at timestamptz not null default now()
);

-- OTP and magic-link material is server-only. Never expose these tables to
-- the Flutter client through permissive RLS policies.
create table public.email_otps (
  id text primary key,
  email text not null,
  otp_hash text not null,
  purpose text not null default 'signup',
  is_used boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  ip_address inet
);

create table public.magic_links (
  id text primary key,
  mobile text not null,
  token_hash text not null unique,
  purpose text not null default 'signup',
  is_used boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index drivers_discovery_idx on public.drivers (application_status, is_online, is_available, vehicle_type);
create index drivers_location_idx on public.drivers (last_location_at desc) where is_online and is_available;
create index driver_presence_discovery_idx on public.driver_presence (vehicle_type, is_online, is_available, last_location_at desc);
create index rides_passenger_created_idx on public.rides (passenger_id, created_at desc);
create index rides_driver_created_idx on public.rides (driver_id, created_at desc);
create index rides_active_driver_idx on public.rides (driver_id, status) where status in ('accepted', 'arrived', 'started');
create index rides_searching_idx on public.rides (status, vehicle_type, created_at) where status = 'searching';
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index reports_status_created_idx on public.reports (status, created_at desc);
create index payments_status_created_idx on public.payments (status, created_at desc);
create index chat_ride_created_idx on public.chat_messages (ride_id, created_at);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('driver-documents', 'driver-documents', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
