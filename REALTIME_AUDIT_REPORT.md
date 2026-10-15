# Sakay Ta Supabase Realtime Audit

Audit date: 2026-10-04  
Scope: Flutter passenger, driver, and admin flows using the canonical Supabase service.

## Outcome

The active client had Realtime-shaped streams, but they were mostly Supabase
`.stream()` convenience streams with no subscription-status visibility. The
admin ride monitor was one-shot, several streams were created from widget
`build()` methods, and the latest `accept_ride` migration cast text ride IDs
to UUIDs. Those paths are now routed through an explicit channel adapter and
authoritative fetches.

## Findings and fixes

1. Realtime features now covered:

   - Passenger nearby drivers and live driver location: `driver_presence`
     events trigger the authoritative `nearby_drivers` RPC or a canonical
     presence read.
   - Passenger/driver ride lifecycle and request state: `rides` events trigger
     filtered full-row reads; raw event payloads are not parsed as joined models.
   - Driver incoming requests: existing searching rows are fetched immediately,
     then all visible ride changes trigger a serialized refresh. Assigned rows
     bypass discovery-only vehicle/GPS enrichment while unassigned rows retain
     those filters.
   - Admin ride monitoring and payment monitoring: live `rides`/`payments`
     sources with keyed filter changes.
   - Notifications, chat, profiles, and payment detail use the same adapter
     where their tables are published. Private driver verification and
     `passenger_profiles` remain query-only by design.

2. Previously missing or misleading connections:

   - `streamAllRides()` yielded once; it is now a live `rides` source.
   - Status callbacks, reconnect, and channel disposal were hidden by raw
     `.stream()` calls; the active service has no raw `.stream()` calls now.
   - Current-user profile and active-trip screen streams duplicated AppState's
     global listeners; screen paths now read shared AppState state.

3. Publication: the hardening migration idempotently ensures `rides`,
   `driver_presence`, `profiles`, `notifications`, `chat_messages`, and
   `payments` in `supabase_realtime`. The private `drivers` table is not
   published. `passenger_profiles` is intentionally query-only.

4. ID mapping: all live filters and ride RPC calls use the canonical Auth UUID:
   `profiles.id`, `drivers.user_id`, `driver_presence.driver_id`,
   `rides.passenger_id`, and `rides.driver_id`. Ride IDs remain text end to end.

5. RLS: no RLS is disabled. Presence visibility is limited to approved
   authenticated users, the owner, or admins; rides remain participant,
   approved-driver-request, or admin readable; RPC execution is authenticated-only.
   The approved presence policy permits an online-to-offline event to be seen so
   the passenger's authoritative RPC result can remove the driver.

6. Race protection: `realtimeQueryStream()` serializes initial fetches and
   event-triggered refreshes. An event arriving during a fetch queues another
   authoritative read, so an older empty result cannot overwrite a newer one.
   Existing driver request stabilization also retains the exact prior row on a
   transient transport failure.

7. Payload parsing: Postgres Changes are treated only as refresh triggers.
   Models are reconstructed from a full PostgREST query/RPC response, including
   canonical snake_case fields and related profile enrichment.

## Files changed

- `lib/services/supabase/realtime_query.dart`
- `lib/services/supabase_database_service.dart`
- `lib/services/supabase_service.dart`
- `lib/services/supabase/finance_service.dart`
- `lib/services/supabase/profile_service.dart`
- `lib/services/supabase/ride_service.dart`
- `lib/services/supabase/driver_service.dart`
- `lib/state/app_state.dart`
- `lib/pages/driver_home.dart`
- `lib/pages/ride_tracking.dart`
- `lib/pages/my_rides.dart`
- `lib/pages/passenger_profile.dart`
- `lib/pages/wallet_page.dart`
- `lib/pages/admin/views/rides_view.dart`
- `test/realtime_connection_contract_test.dart`
- `test/driver_request_stability_contract_test.dart`

## SQL migration

- `supabase/migrations/202610040001_realtime_connection_hardening.sql`

It repairs publication membership, safe presence SELECT visibility, presence
timestamp mirroring, text-ID/idempotent `accept_ride`, and per-driver-safe
`decline_ride` behavior. It does not grant service-role access to Flutter or
disable RLS.

## PASS/FAIL matrix

| Check | Repository/code result | Live cloud result |
|---|---|---|
| Explicit subscription lifecycle/status | PASS | NOT RUN |
| Passenger ride creation | PASS by RPC contract | NOT RUN |
| Driver sees existing/new request | PASS by fetch/channel contract | NOT RUN |
| Request survives transient empty/error | PASS; focused stability tests | NOT RUN |
| Accept/decline state propagation | PASS by RPC/stream contract | NOT RUN |
| Passenger cancellation reaches driver | PASS by ride RPC/live source wiring | NOT RUN |
| Driver online/offline reaches passenger | PASS by presence policy/source wiring | NOT RUN |
| Start/complete reaches passenger/admin | PASS by transition RPC/live ride source | NOT RUN |
| Restart/reconnect/disposal | PASS by adapter contract | NOT RUN |
| Duplicate subscriptions | PASS by source audit and screen ownership | NOT RUN |
| RLS remains enabled and scoped | PASS in repository SQL | NOT RUN |

## Verification evidence

- Targeted Flutter analyzer: **PASS — no issues found** across all changed
  services, state/UI files, and contract tests.
- Focused tests: **PASS — 33 tests** across Realtime contracts, driver
  incoming/stability, nearby-driver parsing/bookability, and initialization.
- Full-project `flutter analyze --no-pub`: **FAIL — 162 existing issues**,
  concentrated in legacy Firebase tests and scratch files (including missing
  `cloud_firestore`/Firestore service references). The changed Realtime target
  set remains clean under targeted analysis.
- Legacy `test/ride_tracking_reliability_test.dart`: **BLOCKED/FAIL** because
  it imports the removed/unavailable `cloud_firestore` package; this is a
  pre-existing Firebase-era test dependency, not a new analyzer error.
- Live Supabase publication inspection, migration application, two-device
  Realtime, RLS matrix, reconnect, and Vercel/browser deployment verification:
  **NOT RUN**. No Supabase CLI/session or database migration credential is
  available in this workspace, so production PASS is not claimed.
