# Retired passenger-signup function

Passenger and driver registration no longer use this Edge Function. The
Flutter clients call Supabase Auth `signUp` directly, require an authenticated
session, and then write the RLS-protected profile/application rows.

Signup and driver-application email OTP are intentionally retired. The local
handler returns HTTP 410 and performs no Auth, database, SMTP, or service-role
work. Remove any already-deployed copy separately through the Supabase CLI or
dashboard; changing this repository does not change a live project.

Supabase Auth Email > Confirm Email must be disabled in the intended project
for immediate post-registration sessions. Password recovery continues to use
`OtpType.recovery`, and signed-in password changes continue to use Auth
reauthentication OTP.
