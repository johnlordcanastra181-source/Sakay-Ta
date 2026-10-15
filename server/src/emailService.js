/**
 * Google-powered Email Service using Gmail SMTP / Gmail API transport.
 * Eliminates SMS costs by sending free transactional verification emails.
 * Includes automated 3-attempt retries, credential sanitization, and structured error diagnostics.
 */

class EmailService {
  constructor(config = {}, logger = console) {
    this.config = config;
    this.logger = logger;
    
    // Resolve email user from GMAIL_USER or GMAIL_EMAIL or config
    const rawUser = config.gmailUser || process.env.GMAIL_USER || process.env.GMAIL_EMAIL || 'sakayta.app@gmail.com';
    this.user = rawUser.trim();

    // Sanitize Gmail App Password (strip all spaces from Google 16-character format "xxxx xxxx xxxx xxxx")
    const rawPass = config.gmailAppPassword || process.env.GMAIL_APP_PASSWORD || '';
    this.pass = rawPass.replace(/\s+/g, '').trim();

    this.host = config.smtpHost || process.env.SMTP_HOST || 'smtp.gmail.com';
    this.port = parseInt(config.smtpPort || process.env.SMTP_PORT || '465', 10);
    this.secure = this.port === 465;
  }

  /**
   * Generates a 6-digit cryptographically random numeric OTP code.
   */
  static generateOtpCode() {
    const crypto = require('node:crypto');
    return crypto.randomInt(100000, 1000000).toString();
  }

  /**
   * Sends an OTP verification email to the user with automatic 3-attempt retries.
   */
  async sendOtpEmail({ email, otpCode, purpose = 'signup' }) {
    const cleanEmail = email.trim().toLowerCase();
    this.logger.info(`[EmailService] Initiating OTP send to ${cleanEmail} for purpose: ${purpose}`);

    const title = purpose === 'login'
      ? 'Login Verification Code'
      : (purpose === 'reset_password' ? 'Password Reset Code' : 'Welcome to Sakay Ta');

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sakay Ta Verification</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f4f6f9; font-family: 'Segoe UI', Arial, sans-serif; color: #1e293b;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #f4f6f9; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08); max-width: 500px; width: 100%;">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); padding: 32px 24px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 26px; font-weight: 800; letter-spacing: 0.5px;">Sakay Ta</h1>
              <p style="margin: 6px 0 0 0; color: #e0f2fe; font-size: 14px; font-weight: 500;">Philippine Ride-Hailing Super App</p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 36px 32px; text-align: center;">
              <h2 style="margin: 0 0 12px 0; color: #0f172a; font-size: 20px; font-weight: 700;">${title}</h2>
              <p style="margin: 0 0 28px 0; color: #64748b; font-size: 15px; line-height: 1.5;">
                Use the 6-digit verification code below to verify your email address. This code is valid for <strong>10 minutes</strong>.
              </p>

              <!-- OTP Code Display Card -->
              <div style="background-color: #f0f9ff; border: 2px dashed #0284c7; border-radius: 12px; padding: 20px; margin: 0 auto 28px auto; display: inline-block;">
                <span style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #0369a1; display: block;">${otpCode}</span>
              </div>

              <p style="margin: 0 0 16px 0; color: #475569; font-size: 13px; line-height: 1.5;">
                ⏳ This code expires in <strong>10 minutes</strong>. Do not share this code with anyone.
              </p>
              
              <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />

              <p style="margin: 0; color: #94a3b8; font-size: 12px; line-height: 1.4;">
                If you did not request this verification code, please ignore this email. Your Sakay Ta account remains secure.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8fafc; padding: 20px; text-align: center; border-top: 1px solid #f1f5f9;">
              <p style="margin: 0; color: #94a3b8; font-size: 12px;">© ${new Date().getFullYear()} Sakay Ta App. All rights reserved.</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;

    // Check if real SMTP credentials are provided
    if (this.pass && this.pass.length > 0) {
      let nodemailer;
      try {
        nodemailer = require('nodemailer');
      } catch {
        nodemailer = null;
      }

      if (nodemailer) {
        const maxAttempts = 3;
        let lastError = null;

        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            this.logger.info(`[EmailService] Attempt ${attempt}/${maxAttempts} connecting to ${this.host}:${this.port} as ${this.user}`);

            const transporter = nodemailer.createTransport({
              host: this.host,
              port: this.port,
              secure: this.secure,
              auth: {
                user: this.user,
                pass: this.pass,
              },
              connectionTimeout: 10000,
              greetingTimeout: 5000,
              socketTimeout: 10000,
            });

            const info = await transporter.sendMail({
              from: `"Sakay Ta Ride-Hailing" <${this.user}>`,
              to: cleanEmail,
              subject: `${otpCode} is your Sakay Ta verification code`,
              html,
            });

            this.logger.info(`[EmailService] Gmail SMTP sent verification code to ${cleanEmail} (Message ID: ${info.messageId})`);
            return {
              sent: true,
              fallback: false,
              messageId: info.messageId,
              message: `Verification code sent to ${cleanEmail}`,
            };
          } catch (err) {
            lastError = err;
            this.logger.warn(`[EmailService] Attempt ${attempt}/${maxAttempts} failed: ${err.message} (code: ${err.code})`);

            // If it's a fatal authentication error (invalid App Password), don't retry pointlessly
            if (err.code === 'EAUTH' || err.responseCode === 535) {
              this.logger.error(`[EmailService] Gmail SMTP Authentication failed. Check GMAIL_USER and 16-character GMAIL_APP_PASSWORD.`);
              break;
            }

            if (attempt < maxAttempts) {
              await new Promise((resolve) => setTimeout(resolve, 2000));
            }
          }
        }

        this.logger.error(`[EmailService] All SMTP attempts failed for ${cleanEmail}: ${lastError ? lastError.message : 'Unknown error'}`);
      }
    } else {
      this.logger.error('[EmailService] Gmail SMTP credentials are not configured.');
    }

    return {
      sent: false,
      fallback: false,
      message: 'Unable to deliver the verification email. Please try again later.',
    };
  }
}

module.exports = { EmailService };
