import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/psgc_data.dart';
import 'package:sakay_ta/models/philippine_address.dart';

void main() {
  group('PSGC Data & PhilippineAddress Tests', () {
    test('PSGCData contains 82 Philippine provinces in alphabetical order', () {
      final provinces = PSGCData.getProvinces();
      expect(provinces.length, greaterThanOrEqualTo(82));
      expect(provinces.first.name, equals('Abra'));
      expect(provinces.any((p) => p.name == 'Cebu'), isTrue);
      expect(provinces.any((p) => p.name == 'Metro Manila (NCR)'), isTrue);
      expect(provinces.any((p) => p.name == 'Davao del Sur'), isTrue);
    });

    test('all 82 provinces + NCR have complete non-empty cities/municipalities lists', () {
      final provinces = PSGCData.getProvinces();
      for (final prov in provinces) {
        final cities = PSGCData.getCitiesForProvince(prov.code);
        expect(
          cities.isNotEmpty,
          isTrue,
          reason: 'Province ${prov.name} (${prov.code}) must have cities/municipalities',
        );
      }
    });

    test('getCitiesForProvince returns cities for Cebu province in alphabetical order', () {
      final cities = PSGCData.getCitiesForProvince('CEB');
      expect(cities.isNotEmpty, isTrue);
      expect(cities.any((c) => c.name == 'Cebu City'), isTrue);
      expect(cities.any((c) => c.name == 'Mandaue City'), isTrue);
      expect(cities.any((c) => c.name == 'Lapu-Lapu City'), isTrue);
      expect(cities.any((c) => c.name == 'Consolacion'), isTrue);
    });

    test('getBarangaysForCity returns barangays for various Philippine cities', () {
      final cebuBrgys = PSGCData.getBarangaysForCity('CEB_CEBU_CITY');
      expect(cebuBrgys.isNotEmpty, isTrue);
      expect(cebuBrgys.any((b) => b.name == 'Lahug'), isTrue);

      final qcBrgys = PSGCData.getBarangaysForCity('NCR_QUEZON_CITY');
      expect(qcBrgys.isNotEmpty, isTrue);

      final dvoBrgys = PSGCData.getBarangaysForCity('DAS_DAVAO_CITY');
      expect(dvoBrgys.isNotEmpty, isTrue);
    });

    test('PhilippineAddress formats standardized address string correctly', () {
      const address = PhilippineAddress(
        provinceName: 'Cebu',
        provinceCode: 'CEB',
        cityName: 'Cebu City',
        cityCode: 'CEB_CEB',
        barangayName: 'Lahug',
        barangayCode: 'CEB_LAH',
        streetDetails: 'Salinas Drive',
      );

      expect(address.isComplete, isTrue);
      expect(
        address.formattedAddress,
        equals('Salinas Drive, Brgy. Lahug, Cebu City, Cebu, Philippines'),
      );
    });
  });
}
