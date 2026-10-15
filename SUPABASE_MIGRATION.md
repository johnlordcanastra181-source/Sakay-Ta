# Sakay Ta Supabase Migration Runbook

Supabase project ref: `kasgyeaedfbcsrhzcnax`  
Project URL: `https://kasgyeaedfbcsrhzcnax.supabase.co`

## Architecture

`auth.users.id` is the canonical account UUID. `profiles.id` shares that UUID. Passenger capability lives in `passenger_profiles`; driver capability lives in `drivers.user_id`; admin authority lives in `admin_roles`. These capabilities are not mutually exclusive.

Ride relationships use `rides.passenger_id -> profiles.id` and `rides.driver_id -> drivers.user_id`. Firebase UIDs are retained only in `firebase_user_map`, `profiles.firebase_uid`, and `drivers.firebase_uid` for migration traceability. New application relationships never use Firebase IDs.

The reproducible migrations are:

1. `supabase/migrations/202609200001_core_schema.sql` — tables, keys, checks, indexes, `avatars` and private `driver-documents` buckets.
2. `supabase/migrations/202609200002_rls.sql` — mandatory database/Storage RLS and column-level restrictions.
3. `supabase/migrations/202609200003_functions_realtime.sql` — triggers, safe driver discovery, atomic business RPCs, rating aggregation, and Realtime publication.
4. `supabase/migrations/202610040001_realtime_connection_hardening.sql` — explicit publication guard, approved presence visibility, reconnect-safe client contract, and text-ID/idempotent ride acceptance.

Tables: `profiles`, `passenger_profiles`, `drivers`, discovery-safe `driver_presence`, `driver_documents`, `admin_roles`, `todas`, `toda_associations`, `fare_config`, `rides`, `ride_status_history`, `bookings`, `ratings`, `payments`, `driver_earnings`, `withdrawals`, `chat_messages`, `notifications`, `wallet_transactions`, `reports`, `saved_places`, plus server-only `firebase_user_map`, `email_otps`, and `magic_links`.

RPCs: `nearby_drivers`, `request_ride`, `accept_ride`, `transition_ride`, `cancel_ride`, `decline_ride`, `approve_driver`, `set_account_status`, `update_fare`, `settle_ride_payment`, `refund_ride_payment`, and helper/trigger functions. `request_ride` calculates fare from the shared fare table and enforces the same-province/one-active-ride rules; clients cannot insert arbitrary fares. `settle_ride_payment` accepts only a trusted server/service role or an authenticated admin.

`supabase/functions/admin-users/index.ts` is the trusted admin-account provisioning boundary. It validates the caller's JWT and database role before using the service role from the Edge Function environment. The service role is never returned to or embedded in Flutter Web.

Realtime tables are limited to `rides`, `driver_presence`, `profiles`, `notifications`, `chat_messages`, and `payments`. PostgreSQL RLS filters Postgres Changes. The full private `drivers` table and `passenger_profiles` are not published to passengers. Static admin/profile/history pages should use normal queries rather than permanent subscriptions.

## Security model

- Flutter mobile/web uses only `SUPABASE_URL` and a client-safe publishable key supplied through `--dart-define-from-file` or the deployment environment.
- `SUPABASE_SERVICE_ROLE_KEY`, the database password, and Firebase service-account JSON are migration/server secrets. They are forbidden in `lib/`, `web/`, `android/`, and `ios/`.
- Passengers cannot read the `drivers` table directly. `nearby_drivers()` and `driver_presence` expose only discovery-safe fields; license/verification data never enters that Realtime row.
- Driver verification records and the `driver-documents` bucket are owner/admin-only. Paths begin with the canonical Auth UUID. The bucket is private.
- Users receive column-level update grants for editable profile and operational driver fields only. Approval, admin role, account status, and rating aggregates are server-controlled.
- Ride lifecycle updates are RPC-only and lock the ride/driver rows to prevent double acceptance.
- Admin access is checked by `is_admin()` against active `admin_roles`; Flutter Web labels do not grant authority.
- In-app notification rows use Supabase Realtime. This repository contains no Firebase Messaging dependency, so there is no existing OS push channel to replace. Add a separate Edge Function/push provider only if device push is a new requirement.

## Required secrets (not committed)

Copy `migration/.env.example` to an ignored local environment file and provide:

- Firebase Admin service-account path for project `sakay-ta`.
- Firebase Storage bucket name.
- Supabase project URL and service-role key for migration scripts only.
- An Auth ID map produced by the supported Firebase-to-Supabase Auth import.

Never paste secrets into SQL, Dart, documentation, logs, or migration reports.

## Execution order

1. Create a source-control rollback point. This workspace currently is not a Git repository, so initialize/restore the intended repository before final cutover.
2. Back up Firestore, Firebase Auth, and Storage. Do not delete the Firebase project/data.
3. Link the Supabase CLI to project `kasgyeaedfbcsrhzcnax`, review migrations in a staging project, then apply them with `supabase db push`.
4. Export Firebase Auth using Supabase's supported `firebase-to-supabase` tooling. Save Firebase SCRYPT hash parameters securely. Import users and create `private/auth-id-map.json` mapping every Firebase UID to the resulting Supabase UUID. Do not assign default passwords.
5. In `migration/`, install pinned dependencies and run `npm run export:firestore` with `DRY_RUN=true`.
6. Review `output/firebase-counts.json` and representative exported records. Export output contains personal data and must remain ignored/encrypted.
7. Set `DRY_RUN=false`; run `npm run import:supabase`. Fix every missing ID mapping or constraint violation—do not silently drop records.
8. Run `npm run migrate:storage`. Review `storage-report.json`; private documents must have no public URL.
9. Run `npm run validate`. Resolve every count mismatch and compare representative identity, status, timestamp, geolocation, fare, passenger, and driver links.
10. Implement and test the Flutter Supabase adapter feature-by-feature: Auth/Profile, Driver, Nearby/Availability, Fare, Booking, Ride Realtime, Ratings, Notifications, Admin.
11. Run the Passenger A/B, Driver A/B, and Admin RLS test matrix, Storage access tests, two-device Realtime test, `flutter analyze`, mobile build, and web build.
12. Only after the gates pass, switch production reads/writes, remove Firebase imports/packages/config/functions, and perform a final repository-wide Firebase/service-role scan.

## Migration utility behavior

- `export_firestore.mjs` exports the 19 actual collections and converts Firestore timestamps/geopoints into JSON-safe ISO/object values.
- `import_supabase.mjs` refuses to run unless `DRY_RUN=false`, resolves all user relationships through the explicit Auth map, normalizes legacy ride states, preserves source record IDs, batches upserts, and writes `import-report.json`.
- `migrate_storage.mjs` maps profile photos to `avatars/{uuid}` and verification documents to private `driver-documents/{uuid}`, then stores paths in relational records. It produces success/skip/failure counts.
- `validate.mjs` compares source/target counts and exits nonzero on mismatches.
- Active raw magic-link and OTP secrets are intentionally not imported. Invalidate and reissue them after cutover; future server code must store hashes rather than plaintext values.

## Client cutover design

Initialize `supabase_flutter` once in both mobile and admin entry points. Fail fast in production when URL/publishable key is missing; tests may inject a fake adapter. Replace `FirebaseAccountRemoteStore` with a Supabase implementation and replace `FirestoreService` at the boundary rather than calling Supabase ad hoc from widgets.

Map model timestamps to UTC ISO-8601/`timestamptz`. Replace Firestore `GeoPoint` with the existing `Geo` model and scalar latitude/longitude columns. Keep SQLite as the explicit offline cache; queued writes must be idempotent.

Store avatar object paths and derive public URLs. Store private document paths and use authenticated download or short-lived signed URLs in the admin reviewer. Unsubscribe Realtime channels in service/controller disposal and avoid one channel per widget rebuild.

## Firebase to Supabase map

| Firebase | Supabase |
|---|---|
| Auth users | `auth.users` + `firebase_user_map` |
| `users` | `profiles` |
| `admins` | `admin_roles` + `profiles` |
| `passengers` | `passenger_profiles` |
| `drivers` | `drivers` + `driver_presence` + `driver_documents` |
| `rides` | `rides` + `ride_status_history` |
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
| `magic_links` / `email_otps` | Invalidate; future hashed rows in server-only tables |
| `profile_photos/*` | Public `avatars/{auth_uuid}/*` |
| `driver_documents/*` | Private `driver-documents/{auth_uuid}/*` + metadata rows |

## Rollback

Keep the pre-cutover Git revision, Firebase exports, Auth mapping, file report, and validation reports. During the cutover window, stop writes briefly rather than maintaining uncontrolled dual writes. If validation fails, redeploy the pre-cutover client against Firebase; do not reverse partially transformed rows manually. Firebase cloud data remains the immutable rollback source until the owner explicitly authorizes retirement.

## Current gate status

Schema/tooling is prepared locally. Cloud application, Auth/data/file migration, client cutover, security tests, and builds against Supabase are not complete because this workspace has no Firebase Admin credential, Auth export/hash parameters, Supabase privileged migration credential, publishable client key, or source-control rollback repository. Firebase production dependencies therefore remain intentionally present.
