# Sakay Ta Supabase Migration Status

Status date: 2026-10-04  
Supabase project: `kasgyeaedfbcsrhzcnax`  
Overall status: **FOUNDATION COMPLETE; CLOUD MIGRATION AND CUTOVER NOT RUN**

## Firebase inventory

Used: Firebase Core, Authentication, Cloud Firestore, Storage, and Firebase Admin SDK for admin provisioning. Not found: Firebase Messaging, Analytics, Realtime Database, or Crashlytics. Full inventory: `FIREBASE_INVENTORY.md`.

## Database tables prepared

`firebase_user_map`, `profiles`, `admin_roles`, `passenger_profiles`, `todas`, `drivers`, `driver_presence`, `driver_documents`, `toda_associations`, `fare_config`, `rides`, `ride_status_history`, `bookings`, `ratings`, `payments`, `driver_earnings`, `withdrawals`, `chat_messages`, `notifications`, `wallet_transactions`, `reports`, `saved_places`, `email_otps`, `magic_links`.

Applied to cloud: **NOT RUN** — no authenticated dashboard/CLI session or database migration credential was available.

## Storage buckets prepared

- Public `avatars`, owner-only writes.
- Private `driver-documents`, owner/admin reads and owner-only writes.

Created in cloud: **NOT RUN**.

## RLS policies prepared

RLS and FORCE RLS are defined for every application table. Policies cover own-profile access, private driver records, discovery-safe driver presence, ride participants, admin-only configuration/verification, payment participants, reports, notifications, and private Storage objects. Direct client writes to admin roles and rides are revoked; trusted RPC/Edge Function boundaries are used.

Applied/security-tested in cloud: **NOT RUN**.

## RPC functions prepared

`nearby_drivers`, `request_ride`, `accept_ride`, `transition_ride`, `cancel_ride`, `decline_ride`, `approve_driver`, `set_account_status`, `update_fare`, `settle_ride_payment`, `refund_ride_payment`, plus auth/profile, presence, rating, timestamp, and Realtime connection-hardening triggers/functions.

## Realtime features prepared

Publication setup exists for `rides`, `driver_presence`, `profiles`, `notifications`, `chat_messages`, and `payments`. Full private `drivers` rows and `passenger_profiles` are intentionally not published.

Two-device verification: **NOT RUN**.

## Auth migration

Strategy: use Supabase's supported Firebase Auth exporter/importer with Firebase SCRYPT parameters, retain an explicit Firebase UID to Supabase UUID map, and never assign default passwords. The `admin-users` Edge Function securely provisions future admin accounts.

Result: **NOT RUN** — Firebase Admin credential, hash parameters/Auth export, Supabase migration credential, and Auth ID map were unavailable.

## Firestore to Supabase map

| Firestore | Supabase |
|---|---|
| `users` | `profiles` |
| `admins` | `admin_roles` |
| `passengers` | `passenger_profiles` |
| `drivers` | `drivers`, `driver_presence`, `driver_documents` |
| `rides` | `rides`, `ride_status_history` |
| `bookings` | `bookings` |
| `chat_messages` | `chat_messages` |
| `toda` | `todas` |
| `toda_associations` | `toda_associations` |
| `fare_matrix` | `fare_config` |
| `ratings` | `ratings` |
| `payments` | `payments` |
| `driver_earnings` | `driver_earnings` |
| `withdrawals` | `withdrawals` |
| `transactions` | `wallet_transactions` |
| `notifications` | `notifications` |
| `reports` | `reports` |
| `magic_links`, `email_otps` | invalidate active plaintext secrets; issue hashed replacements |

## Firebase Storage to Supabase Storage map

| Firebase Storage | Supabase Storage |
|---|---|
| `profile_photos/*` | `avatars/{supabase_user_uuid}/*` |
| `driver_documents/*` | private `driver-documents/{supabase_user_uuid}/*` + `driver_documents` metadata |

## Migrated record and file counts

Firebase source export completed: Auth users 6; `users` 8; `admins` 4; `drivers` 2; `passengers` 4; `rides` 5; `email_otps` 16; `notifications` 14. All other audited Firestore collections contain 0 records. Firebase Storage contains 0 files and the project has no Storage bucket. Supabase target counts remain **NOT RUN** until the target database credentials are supplied.

## Files created

- `FIREBASE_INVENTORY.md`
- `SUPABASE_MIGRATION.md`
- `SUPABASE_MIGRATION_STATUS.md`
- `supabase/migrations/202609200001_core_schema.sql`
- `supabase/migrations/202609200002_rls.sql`
- `supabase/migrations/202609200003_functions_realtime.sql`
- `supabase/migrations/202610040001_realtime_connection_hardening.sql`
- `supabase/functions/admin-users/index.ts`
- `migration/.env.example`
- `migration/package.json`
- `migration/common.mjs`
- `migration/export_firestore.mjs`
- `migration/import_supabase.mjs`
- `migration/migrate_storage.mjs`
- `migration/validate.mjs`

Modified: `.gitignore` only. Existing `migration/001_schema.sql` and `migration/002_rls.sql` appeared in the workspace during this work and were preserved untouched; the canonical versioned migrations are under `supabase/migrations/`.

## Firebase removal

Packages removed: **NONE (intentional)**.  
Remaining Firebase source/config references: **57 files**.  
Reason: Phase 0 safety gate—Supabase schema has not been applied, data/files/Auth have not been migrated, and feature parity has not been verified. Removing Firebase now would break production behavior.

## Security

| Check | Status |
|---|---|
| RLS defined for every table | PASS (local SQL); cloud application NOT RUN |
| Service-role key absent from Flutter/Web/Android/iOS | PASS |
| Private driver-document policy defined | PASS (local SQL); cloud test NOT RUN |
| Admin authorization server-enforced in design | PASS (local SQL/Edge Function); cloud test NOT RUN |
| Passenger A cannot edit Passenger B | NOT RUN |
| Driver A cannot accept Driver B's assigned ride | NOT RUN |
| Ordinary user cannot self-approve/become admin | NOT RUN |

## Functional status

Passenger Auth/Profile/Avatar/Nearby/Booking/Tracking/Rating: **NOT CUT OVER / NOT RUN**.  
Driver Auth/Availability/Location/Incoming/Accept/Complete/Earnings/Avatar: **NOT CUT OVER / NOT RUN**.  
Admin Login/Overview/Passengers/Drivers/Verification/Rides/Reports/Analytics/Payments/TODAs/Fares/Settings: **NOT CUT OVER / NOT RUN**.  
Realtime ride request/acceptance/status/presence/notifications: **NOT CUT OVER / NOT RUN**.

## Verification

- Migration JavaScript syntax: **PASS** (`npm run check`).
- Realtime source audit and focused contract suite: **PASS** (33 tests; live cloud not run).
- Targeted Flutter analyzer for the Realtime change set: **PASS** (no issues found).
- Dependency installation/runtime module load: **NOT VERIFIED**; `npm install` stalled without output and was stopped, leaving no partial `node_modules` or lockfile.
- `flutter analyze --no-pub`: **FAIL** with 162 repository-wide issues, concentrated in legacy Firebase tests and scratch files; the Realtime change set passes targeted analysis.
- Android build: **NOT RUN** (no client cutover).
- Web build: **NOT RUN** (no client cutover).
- Browser/dashboard inspection: **NOT RUN**; no browser session was connected.
- Git rollback point: **FAIL / UNAVAILABLE**; the workspace root is not a Git repository.

## Required next gate

Provide the migration environment through ignored local files or a connected authenticated tool—do not paste secrets into chat. Required: Firebase Admin service-account path, Firebase Auth export/SCRYPT parameters, Supabase service-role migration environment, client publishable key, and an intended Git repository/rollback point. Then apply the schema in staging, migrate Auth/data/files, validate every count/sample and RLS scenario, and only afterward perform Flutter/Admin cutover and Firebase removal.
