const crypto = require('node:crypto');
const { cooldownMs, hourlyLimit } = require('./store');
const { EmailService } = require('./emailService');

/** API error with a stable machine-readable code + HTTP status. */
class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

const schemas = {
  requestEmailOtp: {
    email: (v) => (typeof v === 'string' && EMAIL_REGEX.test(v.trim()) ? v.trim().toLowerCase() : null),
    purpose: (v) => {
      const p = typeof v === 'string' ? v.trim() : '';
      return p === 'login' || p === 'reset_password' || p === 'signup' ? p : 'signup';
    },
  },
  verifyEmailOtp: {
    email: (v) => (typeof v === 'string' && EMAIL_REGEX.test(v.trim()) ? v.trim().toLowerCase() : null),
    otpCode: (v) => (typeof v === 'string' && /^\d{6}$/.test(v.trim()) ? v.trim() : null),
  },
};

function createAuthRouter({ store, opts, logger, emailService }) {
  const router = require('express').Router();
  const mailer = emailService || new EmailService(opts, logger);

  /** POST /api/auth/request-email-otp
   *  Body: { email: "juan@gmail.com", purpose?: "signup"|"login"|"reset_password" }
   *  Generates 6-digit OTP code, stores in database, sends via Google Gmail SMTP.
   *  Errors: 400 invalid_email, 429 cooldown, 429 rate_limit_exceeded, 500 server_error.
   */
  router.post('/request-email-otp', async (req, res, next) => {
    try {
      const email = schemas.requestEmailOtp.email(req.body?.email);
      if (!email) {
        throw new ApiError(
          400,
          'invalid_email',
          'Invalid email address format. Please enter a valid email.',
        );
      }
      const purpose = schemas.requestEmailOtp.purpose(req.body?.purpose);

      store.purgeExpired();

      // Check 60s cooldown
      if (store.inCooldown(email)) {
        throw new ApiError(
          429,
          'cooldown',
          `Please wait ${Math.ceil(cooldownMs / 1000)} seconds before requesting a new OTP.`,
        );
      }

      // Check max 5 requests per hour
      if (store.isRateLimited(email)) {
        throw new ApiError(
          429,
          'rate_limit_exceeded',
          `Maximum OTP limit reached (${hourlyLimit} requests/hour). Please try again later.`,
        );
      }

      const otpId = crypto.randomUUID();
      const otpCode = EmailService.generateOtpCode();
      const ttlMinutes = opts?.tokenTtlMinutes || 10; // 10 minutes default
      const expiresAt = Date.now() + ttlMinutes * 60 * 1000;
      const createdAt = Date.now();
      const ipAddress = req.ip || req.socket?.remoteAddress;

      store.insert({
        id: otpId,
        email,
        otpCode,
        purpose,
        isUsed: false,
        expiresAt,
        createdAt,
        ipAddress,
      });

      // Dispatch Email via Gmail SMTP
      const sendResult = await mailer.sendOtpEmail({
        email,
        otpCode,
        purpose,
      });

      if (!sendResult.sent) {
        return res.status(503).json({success: false, message: sendResult.message});
      }

      logger.info(
        `email-otp requested email=${email} purpose=${purpose} id=${otpId} ` +
          `expires=${new Date(expiresAt).toISOString()}`,
      );

      res.status(200).json({
        success: true,
        email,
        purpose,
        expiresInSeconds: ttlMinutes * 60,
        message: sendResult.message || `A 6-digit verification code has been sent to ${email}.`,
        fallback: sendResult.fallback || false,
      });
    } catch (err) {
      next(err);
    }
  });

  /** POST /api/auth/verify-email-otp
   *  Body: { email: "juan@gmail.com", otpCode: "123456" }
   *  Validates 6-digit code, expiry, single-use, marks used.
   *  Errors: 400 invalid_request, 401 invalid_otp, 401 otp_expired, 409 already_used.
   */
  router.post('/verify-email-otp', (req, res, next) => {
    try {
      const email = schemas.verifyEmailOtp.email(req.body?.email);
      const otpCode = schemas.verifyEmailOtp.otpCode(req.body?.otpCode);

      if (!email || !otpCode) {
        throw new ApiError(
          400,
          'invalid_request',
          'Please provide a valid email and 6-digit verification code.',
        );
      }

      const record = store.findLatestValid(email, otpCode);
      if (!record) {
        throw new ApiError(
          401,
          'invalid_otp',
          'Invalid verification code. Please check and try again.',
        );
      }

      if (record.isUsed) {
        throw new ApiError(
          409,
          'already_used',
          'This verification code has already been used. Please request a new code.',
        );
      }

      if (Date.now() > record.expiresAt) {
        throw new ApiError(
          401,
          'otp_expired',
          'Verification code has expired (10-minute limit). Please request a new code.',
        );
      }

      store.markUsed(record.id);

      logger.info(`email-otp verified email=${record.email} id=${record.id}`);

      res.status(200).json({
        verified: true,
        email: record.email,
        purpose: record.purpose,
        message: 'Email OTP verified successfully.',
      });
    } catch (err) {
      next(err);
    }
  });

  return router;
}

module.exports = { createAuthRouter, ApiError };
