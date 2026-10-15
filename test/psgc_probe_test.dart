import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/psgc_data.dart';

void main() {
  test('psgc completeness probe', () {
    final provinces = PSGCData.getProvinces();
    var shortCities = 0;
    for (final p in provinces) {
      final cities = PSGCData.getCitiesForProvince(p.code);
      if (cities.length < 50) {
        shortCities++;
        // ignore: avoid_print
        print(
            'SHORT ${p.code} ${p.name}: ${cities.length} cities -> ${cities.map((c) => c.name).take(12).join(', ')}');
      }
    }
    // ignore: avoid_print
    print('---');
    // ignore: avoid_print
    print('Provinces with <50 cities: $shortCities of ${provinces.length}');
    final cebu = PSGCData.getCitiesForProvince('CEB');
    // ignore: avoid_print
    print('CEB cities: ${cebu.length}');
    final benguet = PSGCData.getCitiesForProvince('BEN');
    // ignore: avoid_print
    print('BEN cities: ${benguet.length}');
    final cebuCity = cebu.firstWhere((c) => c.name == 'Cebu City');
    final cebuCityBrgy = PSGCData.getBarangaysForCity(cebuCity.code);
    // ignore: avoid_print
    print('Cebu City barangays: ${cebuCityBrgy.length}');
    final bantayan = cebu.firstWhere((c) => c.name == 'Bantayan');
    final bantayanBrgy = PSGCData.getBarangaysForCity(bantayan.code);
    // ignore: avoid_print
    print('Bantayan barangays: ${bantayanBrgy.length}');
  });
}
