import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/phone_utils.dart';

void main() {
  group('PhoneUtils.normalizeToInternational', () {
    test('concatenates +63 with the ten typed digits', () {
      expect(PhoneUtils.normalizeToInternational('9123456789'),
          '+639123456789');
    });

    test('strips the leading 0 prefix', () {
      expect(PhoneUtils.normalizeToInternational('09123456789'),
          '+639123456789');
    });

    test('strips a leading 63 prefix', () {
      expect(PhoneUtils.normalizeToInternational('639123456789'),
          '+639123456789');
    });

    test('strips spaces and dashes', () {
      expect(PhoneUtils.normalizeToInternational('912 345-6789'),
          '+639123456789');
    });

    test('accepts an already full +63 number', () {
      expect(PhoneUtils.normalizeToInternational('+639123456789'),
          '+639123456789');
    });

    test('returns null for fewer than ten digits', () {
      expect(PhoneUtils.normalizeToInternational('912345678'), isNull);
    });

    test('returns null for more than ten digits', () {
      expect(PhoneUtils.normalizeToInternational('91234567890'), isNull);
    });

    test('returns null for empty input', () {
      expect(PhoneUtils.normalizeToInternational(''), isNull);
      expect(PhoneUtils.normalizeToInternational('   '), isNull);
    });
  });

  group('PhoneUtils.validateNationalNumber', () {
    test('accepts exactly ten digits', () {
      expect(PhoneUtils.validateNationalNumber('9123456789'), isNull);
    });

    test('rejects fewer than ten digits with a clear message', () {
      final error = PhoneUtils.validateNationalNumber('912345678');
      expect(error, contains('10'));
      expect(error, contains('9/10'));
    });

    test('rejects more than ten digits with a clear message', () {
      final error = PhoneUtils.validateNationalNumber('91234567890');
      expect(error, contains('exactly 10'));
    });

    test('rejects empty input', () {
      expect(PhoneUtils.validateNationalNumber(''), 'Please enter your mobile number');
      expect(PhoneUtils.validateNationalNumber(null), 'Please enter your mobile number');
    });

    test('rejects numbers that do not start with 9', () {
      final error = PhoneUtils.validateNationalNumber('8123456789');
      expect(error, contains('starting with 9'));
    });
  });
}
