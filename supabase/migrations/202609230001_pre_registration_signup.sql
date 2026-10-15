-- Two-phase passenger registration.  This table is deliberately inaccessible
-- to browser/mobile roles: only the trusted Edge Function may issue, verify,
-- or consume a signup proof.
create table public.pending_signup_verifications (
  id uuid primary key default gen_random_uuid(),
  email_normalized text not null unique,
  otp_hash text not null,
  expires_at timestamptz not null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  request_count integer not null default 1 check (request_count >= 1),
  request_window_started_at timestamptz not null default now(),
  last_sent_at timestamptz not null default now(),
  verified_at timestamptz,
  proof_hash text,
  proof_expires_at timestamptz,
  finalization_started_at timestamptz,
  consumed_at timestamptz,
  finalized_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pending_signup_verifications_email_lowercase
    check (email_normalized = lower(btrim(email_normalized)))
);

create index pending_signup_verifications_expires_at_idx
  on public.pending_signup_verifications (expires_at);

alter table public.pending_signup_verifications enable row level security;
alter table public.pending_signup_verifications force row level security;

revoke all on public.pending_signup_verifications from anon, authenticated;

create trigger set_updated_at
before update on public.pending_signup_verifications
for each row execute function public.set_updated_at();
