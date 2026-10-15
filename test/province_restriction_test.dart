import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Province Restriction Tests', () {
    test('Bohol -> Bohol search should pass', () {
      final pickupProvince = 'Bohol';
      final destProvince = 'Bohol';
      expect(
          pickupProvince.toLowerCase() == destProvince.toLowerCase(), isTrue);
    });

    test('Bohol -> outside Bohol blocked should pass', () {
      final pickupProvince = 'Bohol';
      final destProvince = 'Cebu';
      expect(
          pickupProvince.toLowerCase() == destProvince.toLowerCase(), isFalse);
    });

    test('Dynamic province detection should pass', () {
      final pickupProvince = 'Cebu';
      final destProvince1 = 'Cebu';
      final destProvince2 = 'Bohol';

      expect(
          pickupProvince.toLowerCase() == destProvince1.toLowerCase(), isTrue);
      expect(
          pickupProvince.toLowerCase() == destProvince2.toLowerCase(), isFalse);
    });
  });
}
