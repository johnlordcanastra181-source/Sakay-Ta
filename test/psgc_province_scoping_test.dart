import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/psgc_data.dart';

void main() {
  group('PSGC Province-Scoped Barangay Resolution Tests', () {
    test('Clarin, Bohol returns strictly Bohol barangays and excludes Misamis Occidental', () {
      final boholCities = PSGCData.getCitiesForProvince('BOH');
      final clarinBohol = boholCities.firstWhere(
        (c) => c.name.toLowerCase() == 'clarin',
      );
      expect(clarinBohol.code, 'BOH_CLARIN');

      final boholBrgys = PSGCData.getBarangaysForCity(
        clarinBohol.code,
        'BOH',
      );

      // Bohol Clarin has exactly 24 official barangays
      expect(boholBrgys.length, 24);

      final names = boholBrgys.map((b) => b.name).toList();

      // Confirmed Bohol barangays
      expect(names, contains('Nahawan'));
      expect(names, contains('Poblacion Centro'));
      expect(names, contains('Bogtongbod'));
      expect(names, contains('Tubod'));
      expect(names, contains('Bacani'));
      expect(names, contains('Bonbon'));
      expect(names, contains('Villaflor'));

      // Misamis Occidental Clarin barangays MUST NOT be present
      expect(names, isNot(contains('Canibungan Daku')));
      expect(names, isNot(contains('Guba (Ozamis)')));
      expect(names, isNot(contains('Segatic Daku')));
      expect(names, isNot(contains('Lupagan')));
      expect(names, isNot(contains('Penacio')));
      expect(names, isNot(contains('Sebasi')));
      expect(names, isNot(contains('Tinacla-An')));
    });

    test('Clarin, Misamis Occidental returns strictly Misamis Occidental barangays', () {
      final micCities = PSGCData.getCitiesForProvince('MIC');
      final clarinMic = micCities.firstWhere(
        (c) => c.name.toLowerCase() == 'clarin',
      );
      expect(clarinMic.code, 'MIC_CLARIN');

      final micBrgys = PSGCData.getBarangaysForCity(
        clarinMic.code,
        'MIC',
      );

      // Misamis Occidental Clarin has exactly 29 official barangays
      expect(micBrgys.length, 29);

      final names = micBrgys.map((b) => b.name).toList();

      // Confirmed Misamis Occidental barangays
      expect(names, contains('Canibungan Daku'));
      expect(names, contains('Guba (Ozamis)'));
      expect(names, contains('Segatic Daku'));
      expect(names, contains('Lupagan'));
      expect(names, contains('Penacio'));

      // Bohol-only barangays MUST NOT be present
      expect(names, isNot(contains('Nahawan')));
      expect(names, isNot(contains('Bogtongbod')));
      expect(names, isNot(contains('Tontunan')));
      expect(names, isNot(contains('Comaang')));
    });

    test('Infers province code automatically from cityCode prefix if provinceCode is omitted', () {
      final boholBrgys = PSGCData.getBarangaysForCity('BOH_CLARIN');
      expect(boholBrgys.length, 24);
      expect(boholBrgys.map((b) => b.name), contains('Nahawan'));
      expect(boholBrgys.map((b) => b.name), isNot(contains('Guba (Ozamis)')));

      final micBrgys = PSGCData.getBarangaysForCity('MIC_CLARIN');
      expect(micBrgys.length, 29);
      expect(micBrgys.map((b) => b.name), contains('Guba (Ozamis)'));
      expect(micBrgys.map((b) => b.name), isNot(contains('Nahawan')));
    });

    test('San Fernando, Cebu returns strictly Cebu barangays', () {
      final cebBrgys = PSGCData.getBarangaysForCity('CEB_SAN_FERNANDO', 'CEB');
      expect(cebBrgys.isNotEmpty, isTrue);

      final names = cebBrgys.map((b) => b.name).toList();
      // Cebu San Fernando barangays
      expect(names, contains('Pitalo'));
      expect(names, contains('Sangat'));
      expect(names, contains('Ilaya'));
    });

    test('Carmen, Bohol returns strictly Bohol barangays', () {
      final boholCarmen = PSGCData.getBarangaysForCity('BOH_CARMEN', 'BOH');
      expect(boholCarmen.isNotEmpty, isTrue);

      final names = boholCarmen.map((b) => b.name).toList();
      expect(names, contains('Buenos Aires'));
      expect(names, contains('Katipunan'));
      expect(names, contains('Villaflor'));
    });
  });
}

