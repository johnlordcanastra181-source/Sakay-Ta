# Sakay Ta API

Node.js/Express auth backend for Sakay Ta. Handles Magic Link
generation and verification (the app delivers the link itself via the free
`wa.me` deep link, so the server never sends SMS or WhatsApp messages).

Requires **Node.js >= 22.5** (uses the built-in `node:sqlite` driver â€” no
native compilation needed).

## Quick start

```bash
cd server
npm install
cp .env.example .env      # then edit JWT_SECRET (required for production)
npm start                 # listens on http://0.0.0.0:8080
npm test                  # runs the test suite (node:test)
```

## Endpoints

### `POST /api/auth/request-magic-link`

```json
{ "mobile": "+639123456789", "purpose": "signup" }
```

Returns a signed token (HS256 JWT, 15-min expiry, single-use), the
`sakayta://auth/verify?token=...` deep link, and a ready-to-open
`https://wa.me/63XXXXXXXXXX?text=...` URL.

Errors: `400 invalid_number` Â· `429 cooldown` (30 s between requests for the
same number) Â· `500 server_error`.

### `POST /api/auth/verify-magic-link`

```json
{ "token": "<jwt>" }
```

Validates signature + expiry, marks the link used, and returns
`{ "verified": true, "mobile": "+639123456789", "purpose": "signup" }`.

Errors: `400 invalid_token_request` Â· `401 token_expired` Â· `401 invalid_token`
(signature or unknown) Â· `409 already_used` Â· `500 server_error`.

All errors share one shape so the app can map them cleanly:

```json
{ "error": { "code": "token_expired", "message": "This Magic Link has expired." } }
```

### `GET /health`

Liveness probe: `{ "status": "ok", "uptime": ... }`.

## Configuration

| Env var | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8080` | HTTP port |
| `HOST` | `0.0.0.0` | Bind address |
| `JWT_SECRET` | dev value | **Set a long random string in production** |
| `TOKEN_TTL_MINUTES` | `15` | Link lifetime |
| `RESEND_COOLDOWN_SECONDS` | `30` | Resend lockout |
| `DB_PATH` | `sakay_ta_api.db` | SQLite file |
| `CORS_ORIGINS` | `*` | Comma-separated allowed origins |

## Pointing the Flutter app at this server

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://<your-server-ip>:8080
```

`API_BASE_URL` is read at build time (`lib/core/api_config.dart`). Without it
the app keeps working with on-device Magic Links (free demo mode). When set,
the signup/resend/verify calls go to the server (with a 12 s timeout, one
retry, and server error messages surfaced in the UI).


## Email OTP endpoints (signup / login)

The app can verify signups with a 6-digit email OTP instead of Magic Links.

### `POST /api/auth/request-email-otp`

```json
{ "email": "juan@example.com", "purpose": "signup" }
```

Generates a 6-digit code, stores it in the `email_otps` SQLite table
(10-minute expiry, 60 s resend cooldown, max 5 requests/hour per email) and
sends it via Gmail SMTP with **3 attempts and a 2-second delay between
retries**. Returns `{ "sent": true, "message": "...", "devOtpCode": "123456" }`
(`devOtpCode` is only included when real Gmail credentials are not configured,
i.e. development/demo mode).

Errors: `400 invalid_email` - `429 cooldown` - `429 rate_limit_exceeded` -
`500 server_error`.

### `POST /api/auth/verify-email-otp`

```json
{ "email": "juan@example.com", "otpCode": "123456" }
```

Checks the code exists, is unused and unexpired, marks it used, and returns
`{ "verified": true, "email": "..." }`.

Errors: `400 invalid_request` - `401 invalid_otp` - `401 otp_expired` -
`409 already_used`.

## Sending real OTP emails (Gmail SMTP)

1. Use the Gmail account that will send the OTPs (default `sakayta.app@gmail.com`).
2. Enable **2-Step Verification** on it: Google Account -> Security.
3. Create an **App Password**: Google Account -> Security -> 2-Step
   Verification -> App passwords -> name it "Sakay Ta Server" -> copy the
   16-character code (spaces are fine; they are stripped automatically).
4. Put it in `server/.env`:

   ```ini
   GMAIL_USER=sakayta.app@gmail.com
   GMAIL_APP_PASSWORD=abcd efgh ijkl mnop
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   ```

5. Restart the server (`npm start`). The first attempt logs
   `Gmail SMTP sent verification code to ... (Message ID: ...)`.

Notes:
- Gmail blocks the sign-in if the App Password is wrong (`EAUTH` / 535) -
  the server logs that explicitly and does not retry.
- If the sender account is new, Gmail may hold the first few emails; check
  Spam. Heavy volume triggers Gmail rate limits (the client shows
  "OTP service temporarily unavailable").
- When `GMAIL_APP_PASSWORD` is empty the server runs in **dev mode**: the
  code is logged to the console and returned as `devOtpCode` (also shown by
  the app in debug builds), so the flow is fully testable without sending
  real emails.

## On-device Email OTP (no server needed)

Built without `API_BASE_URL`, the app sends the OTP email directly from the
phone using `package:mailer`. Provide the same Gmail credentials at build
time:

```bash
flutter build apk --release \
  --dart-define=GMAIL_USER=sakayta.app@gmail.com \
  --dart-define=GMAIL_APP_PASSWORD=abcd-efgh-ijkl-mnop
```

Without them the app falls back to dev mode (code shown on the OTP screen).
