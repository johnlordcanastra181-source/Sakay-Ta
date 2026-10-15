const COOLDOWN_MS = 60 * 1000; // 60-second cooldown
const HOURLY_LIMIT = 5; // Max 5 OTP requests per email per hour

/** SQLite storage for Email OTP verification codes. */
class EmailOtpStore {
  constructor(db) {
    this.db = db;
    this._init();
  }

  _init() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS email_otps (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        otp_code TEXT NOT NULL,
        purpose TEXT NOT NULL DEFAULT 'signup',
        is_used INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        ip_address TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_email_otps_email ON email_otps(email);
      CREATE INDEX IF NOT EXISTS idx_email_otps_expires ON email_otps(expires_at);
    `);
  }

  insert(record) {
    this.db
      .prepare(
        `INSERT INTO email_otps (id, email, otp_code, purpose, is_used, expires_at, created_at, ip_address)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        record.id,
        record.email.toLowerCase().trim(),
        record.otpCode,
        record.purpose,
        record.isUsed ? 1 : 0,
        record.expiresAt,
        record.createdAt,
        record.ipAddress || null,
      );
  }

  findLatestValid(email, otpCode, now = Date.now()) {
    const row = this.db
      .prepare(
        `SELECT * FROM email_otps 
         WHERE email = ? AND otp_code = ?
         ORDER BY created_at DESC LIMIT 1`,
      )
      .get(email.toLowerCase().trim(), otpCode.trim());

    if (!row) return null;
    return {
      id: row.id,
      email: row.email,
      otpCode: row.otp_code,
      purpose: row.purpose,
      isUsed: row.is_used === 1,
      expiresAt: row.expires_at,
      createdAt: row.created_at,
      ipAddress: row.ip_address,
    };
  }

  latestForEmail(email) {
    const row = this.db
      .prepare(
        `SELECT * FROM email_otps WHERE email = ? ORDER BY created_at DESC LIMIT 1`,
      )
      .get(email.toLowerCase().trim());
    if (!row) return null;
    return {
      id: row.id,
      email: row.email,
      otpCode: row.otp_code,
      purpose: row.purpose,
      isUsed: row.is_used === 1,
      expiresAt: row.expires_at,
      createdAt: row.created_at,
      ipAddress: row.ip_address,
    };
  }

  countRecentInLastHour(email, now = Date.now()) {
    const oneHourAgo = now - 60 * 60 * 1000;
    const row = this.db
      .prepare(
        `SELECT COUNT(*) as count FROM email_otps 
         WHERE email = ? AND created_at >= ?`,
      )
      .get(email.toLowerCase().trim(), oneHourAgo);
    return row?.count || 0;
  }

  markUsed(id) {
    this.db.prepare('UPDATE email_otps SET is_used = 1 WHERE id = ?').run(id);
  }

  purgeExpired(now = Date.now()) {
    this.db.prepare('DELETE FROM email_otps WHERE expires_at < ?').run(now);
  }

  /** @returns whether the latest request for email is inside the 60s cooldown. */
  inCooldown(email, now = Date.now()) {
    const latest = this.latestForEmail(email);
    if (!latest) return false;
    return now - latest.createdAt < COOLDOWN_MS;
  }

  /** @returns whether the email exceeded the max 5 requests per hour limit. */
  isRateLimited(email, now = Date.now()) {
    return this.countRecentInLastHour(email, now) >= HOURLY_LIMIT;
  }

  static open(db) {
    return new EmailOtpStore(db);
  }
}

module.exports = {
  EmailOtpStore,
  cooldownMs: COOLDOWN_MS,
  hourlyLimit: HOURLY_LIMIT,
};