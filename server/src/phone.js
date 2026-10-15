/** Philippine mobile number helpers - mirrors lib/core/phone_utils.dart. */
const NATIONAL_DIGITS = 10;

/**
 * Normalizes user input to a clean E.164 number such as "+639123456789".
 * Accepts "+63...", "63...", "09...", or plain 10 digits.
 * Returns null when the input cannot be resolved to exactly ten digits
 * starting with 9.
 */
function normalizeToInternational(input) {
  if (typeof input !== 'string') return null;
  const raw = input.trim();
  if (!raw) return null;

  let digits = raw.replace(/\D/g, '');
  if (!digits) return null;

  if (digits.startsWith('63')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length !== NATIONAL_DIGITS) return null;
  if (!/^9\d{9}$/.test(digits)) return null;
  return `+63${digits}`;
}

/** "+639123456789" -> "639123456789" (used by the wa.me URL). */
function waMeDigits(e164) {
  return e164.replace('+', '');
}

module.exports = { normalizeToInternational, waMeDigits };