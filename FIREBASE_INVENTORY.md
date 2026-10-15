# Sakay Ta Firebase Inventory

Audit date: 2026-09-20  
Firebase project: `sakay-ta`  
Scope: `lib/`, `functions/`, `server/`, Android/iOS/Web configuration, Firestore and Storage rules.

This inventory was generated from the application source and rules. It does not claim cloud record counts because no Firebase Admin credential or export was present in the workspace.

## Services and packages

| Service/package | Production usage | Files/features |
|---|---|---|
| `firebase_core` | App and admin-web initialization | `lib/main.dart`, `lib/admin_main.dart`, `lib/firebase_options.dart`, setup guards |
| `firebase_auth` | Passenger/driver/admin email-password auth; mobile numbers are converted to synthetic `...@sakayta.app` emails; secondary app creates admins | `lib/services/firebase_auth_service.dart`, `lib/services/auth_service.dart`, `lib/services/account_remote_store.dart`, `lib/state/app_state.dart`, driver and tracking pages |
| `cloud_firestore` | All shared cloud records, realtime listeners, ride transactions, admin data | `lib/services/firestore_service.dart`, `lib/services/account_remote_store.dart`, `lib/services/magic_link_service.dart`, model timestamp/geopoint parsing, app state and tests |
| `firebase_storage` | Public profile photos and driver verification images | `lib/services/firebase_storage_service.dart`, `lib/pages/driver_registration.dart`, `lib/widgets/edit_profile_modal.dart` |
| Firebase Admin SDK | Admin-account Cloud Functions/CLI | `functions/index.js`, `functions/create-admin-cli.js`, `functions/package.json` |
| `firebase-admin` in `server/package.json` | Declared but not imported by `server/src/` | Remove only when the server dependency lock is regenerated during final cutover |
| Messaging / Analytics / Realtime Database / Crashlytics | Not found | No FCM device-push implementation exists in this repository. Current notifications are database/in-app notifications only. |

Firebase-dependent model imports exist in `admin_account.dart`, `app_user.dart`, `driver_profile.dart`, `email_otp.dart`, `firestore_models.dart`, `report_model.dart`, and `trip.dart`. They only adapt `Timestamp`, `GeoPoint`, or `FirebaseException` and must be changed to PostgreSQL/ISO timestamp parsing during client cutover.

## Authentication and identity

- Passenger and driver registration uses Firebase email/password. A real email is preferred; otherwise a normalized Philippine mobile number becomes a synthetic email such as `639123456789@sakayta.app`.
- Admin login uses Firebase email/password and checks the `admins/{auth.uid}` record.
- Admin creation is implemented both as Firebase Cloud Functions and a secondary Firebase client app. The latter is not suitable for Supabase: new Auth users must be provisioned by a trusted Edge Function/server using an admin secret, never by Flutter Web.
- Driver application documents use the authenticated Firebase UID as the intended canonical document ID, but compatibility lookups also search a `uid` field because older local UUID records can exist.
- Roles are represented in `users.role`, a separate `admins` document, and a `drivers` document/application status. A user can begin as a passenger and later gain driver capability.
- Magic links and email OTP records are custom application records, not Firebase phone auth. Current raw token/code records must not be copied as reusable credentials; invalidate them at cutover and issue new, hashed tokens.
- Passwords can be migrated using Supabase's supported Firebase Auth migration tooling and Firebase SCRYPT parameters. No default passwords may be assigned.

## Firestore collections

There are no nested subcollections in the source or security rules. Document IDs are either the Auth UID, an application-generated text ID, or a Firestore auto-ID.

| Firebase collection | Purpose / ID strategy | Principal fields found | Readers / writers | Realtime |
|---|---|---|---|---|
| `users` | Canonical account profile; Firebase UID intended as document ID | identity/contact, role/status, avatar, online/location, rating/stats | own user, admins; app/auth/admin writers | user profile, driver/passenger lists |
| `admins` | Admin authorization/profile; Auth UID document ID | role, status, permissions, department, login timestamps | own admin/admins; Cloud Function/admin UI writes | admin account list |
| `drivers` | Driver application, vehicle, status, online/location/stats; UID document ID | personal/license/vehicle/TODA data, document URLs, availability, coordinates, rating | owner/admin; discovery uses a safe subset | verification, nearby, live location |
| `passengers` | Passenger preferences/profile extension; UID document ID | saved addresses, emergency contacts, payment methods, ride count | owner/admin | current passenger profile |
| `rides` | Booking and ride lifecycle; app text ID | passenger/driver, vehicle, pickup/destination geodata, fare split, lifecycle/payment timestamps | passenger, assigned/eligible driver, admin | incoming requests, active ride, tracking, history, admin monitor |
| `bookings` | Legacy/pre-ride booking record; app text ID | passenger, vehicle, pickup/drop-off, status/payment method | participant/admin | no dedicated listener found |
| `chat_messages` | Ride chat; app text ID | trip, sender, role, body, read/time | ride participants/admin | ride chat |
| `toda` | TODA directory; app text ID | name/code/city/president/contact/active | signed-in users; admin writes | admin TODA list |
| `toda_associations` | Driver membership; app text ID | TODA, driver, status, member role | driver/admin | TODA members |
| `fare_matrix` | Shared fare source; vehicle type is logical ID | base/per-km/minimum/commission/discounts/effective time | all signed-in; admin writes | mobile fare cache and admin fare UI |
| `ratings` | One review of a driver for a ride; generated text ID | ride, reviewer, reviewee, stars/comment/time | related user/admin; passenger writes | driver rating list/aggregate |
| `payments` | Ride payment; payment ID | payer/payee/ride, amount/method/status/provider refs | participants/admin/server | payment status and admin payments |
| `driver_earnings` | Driver ledger; generated ID | driver/ride, fare/commission/net/method/time | driver/admin | earnings and analytics |
| `withdrawals` | Driver payout request; generated ID | driver, amount/method/account details/status/time | driver/admin | wallet/admin workflow |
| `transactions` | Wallet activity; app text ID | user/ride/type/amount/description/status | owner/admin | no dedicated listener found |
| `notifications` | In-app notifications; mixed app/auto ID | recipient/sender/type/title/body/ride/read/time | recipient/admin/authorized sender | yes |
| `reports` | Support/safety reports; app text ID | reporter/subject/ride/category/status/notes/resolution | related user/admin | admin reports |
| `magic_links` | Custom short-lived auth token | mobile, raw token, purpose, used/expiry | custom service | no |
| `email_otps` | Custom short-lived email code | email, raw code, purpose, used/expiry/IP | custom service | no |

Collection security rules are in `firestore.rules`; composite indexes are in `firestore.indexes.json`.

## Firebase Storage

| Firebase path | Type / owner | Database reference | Existing access | Supabase target |
|---|---|---|---|---|
| `profile_photos/{uid}_{timestamp}.jpg` | Passenger/driver avatar | `users.profilePhotoUrl/profile_photo_url`; driver mirrors | Authenticated owner write; existing URL is public-style download URL | Public `avatars/{supabase_uid}/...`; store object path in `profiles.profile_photo_path` |
| `driver_documents/{uid}/license/{kind}_{timestamp}.jpg` | License images | driver legacy/nested document fields | Owner write; admin/owner read by Storage rules | Private `driver-documents/{supabase_uid}/license/...` plus `driver_documents` row |
| `driver_documents/{uid}/orcr/{kind}_{timestamp}.jpg` | OR/CR | driver document fields | Owner write; admin/owner read | Private `driver-documents` |
| `driver_documents/{uid}/profile/{kind}_{timestamp}.jpg` | Driver application profile image | driver profile fields | Owner write; admin/owner read | Private `driver-documents` (a separately chosen public avatar may go to `avatars`) |

The existing comments incorrectly imply that reviewers can rely on stored Firebase download URLs without Storage read permission. The Supabase design stores private object paths and generates authenticated downloads/signed URLs only for the owner/admin.

## Read/write/listen classification

- True realtime requirements: incoming ride requests, ride status/tracking, driver online/location, notifications, chat, and payment status.
- Realtime currently used but not essential: fare matrix, admin lists/dashboards, profile pages, history/earnings. These can use one-shot queries plus explicit refresh unless live UX is required.
- Atomic operations requiring PostgreSQL functions: accept ride, transition/cancel ride, approve/reject driver, settle payment and driver ledger, rating aggregate, and fare updates.
- Firestore offline persistence is enabled. Supabase does not provide equivalent transparent offline persistence; the existing SQLite/cache/sync queue remains the offline UX layer and requires conflict/retry testing during client cutover.

## Cutover gate

Firebase packages and configuration must remain until: Auth users are imported, every collection/file count is validated, the Flutter Supabase data service is complete, two-account RLS tests pass, and mobile/web builds pass. The Firebase project and cloud data must not be deleted.
