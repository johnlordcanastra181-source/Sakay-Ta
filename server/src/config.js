require('dotenv').config();

/** Central configuration. All values can be overridden via environment or a
 *  .env file (see .env.example). Secrets live only in the environment. */
module.exports = {
  port: Number(process.env.PORT || 8080),
  host: process.env.HOST || '0.0.0.0',

  /** Used to sign Magic Link tokens. MUST be set in production. */
  jwtSecret: process.env.JWT_SECRET || 'dev-only-secret-change-me',

  /** How long a Magic Link token stays valid. */
  tokenTtlMinutes: Number(process.env.TOKEN_TTL_MINUTES || 15),

  /** Minimum wait between two requests for the same number. */
  resendCooldownSeconds: Number(process.env.RESEND_COOLDOWN_SECONDS || 30),

  /** Registry (better-sqlite style) file used for real runs. */
  dbPath: process.env.DB_PATH || 'sakay_ta_api.db',

  /** Comma-separated list of allowed origins; '*' opens the API to any app. */
  corsOrigins: (process.env.CORS_ORIGINS || '*').split(',').map((s) => s.trim()),

  /** Deep link scheme the mobile app intercepts. */
  deepLinkScheme: process.env.DEEP_LINK_SCHEME || 'sakayta',
  deepLinkHost: process.env.DEEP_LINK_HOST || 'auth',

  /** Node 22.5+ ships a built-in sqlite driver; we use it to avoid native
   *  compile requirements (works with: node >=22.5). */
  isSqliteSupported() {
    return typeof require('node:sqlite').DatabaseSync === 'function';
  },
};