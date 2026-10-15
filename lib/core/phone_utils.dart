/// Helpers for normalizing and validating Philippine mobile numbers.
///
/// The signup form shows a visual "+63" prefix and asks the user to enter
/// only the remaining ten digits (e.g. "912 345 6789"). The full E.164
/// international number is therefore formed by concatenating "+63" with
/// those ten digits, e.g. "+639123456789".
class PhoneUtils {
  PhoneUtils._();

  static const String countryCode = '+63';
  static const int nationalDigits = 10;

  static final RegExp _digitsOnly = RegExp(r'\D');

  /// Strips spaces, dashes, parentheses, the "0" prefix and the "63" prefix,
  /// then re-applies the country code to produce a clean E.164 number such
  /// as "+639123456789" with no spaces, dashes, or special characters.
  ///
  /// Returns null when the input cannot be resolved to exactly ten digits.
  static String? normalizeToInternational(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    var digits = raw.replaceAll(_digitsOnly, '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('63')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != nationalDigits) return null;
    return '$countryCode$digits';
  }

  /// Validates the ten-digit national part the user types after the "+63"
  /// prefix. Returns a user-facing error string, or null when valid.
  static String? validateNationalNumber(String? input) {
    final raw = (input ?? '').trim();
    if (raw.isEmpty) {
      return 'Please enter your mobile number';
    }
    final digits = raw.replaceAll(_digitsOnly, '');
    if (digits.length < nationalDigits) {
      return 'Enter exactly 10 digits (${digits.length}/10 entered)';
    }
    if (digits.length > nationalDigits) {
      return 'Mobile number must be exactly 10 digits after +63';
    }
    if (!RegExp(r'^9\d{9}$').hasMatch(digits)) {
      return 'Enter a valid Philippine mobile number starting with 9';
    }
    return null;
  }
}
