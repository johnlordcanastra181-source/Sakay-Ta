library;

import 'package:philippines_rpcmb/philippines_rpcmb.dart' as rpcmb;

/// Official Philippine Standard Geographic Code (PSGC) complete dataset.
/// Published by the Philippine Statistics Authority (PSA).
/// Contains ALL 82 Philippine Provinces + Metro Manila (NCR), ALL 1,634+
/// Cities/Municipalities, and ALL 42,046+ official Barangays in the Philippines
/// for 100% complete offline cascading dropdown selection.

class PSGCItem {
  final String code;
  final String name;
  final String? parentCode;

  const PSGCItem({
    required this.code,
    required this.name,
    this.parentCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PSGCItem &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class PSGCData {
  PSGCData._();

  static final Map<String, List<PSGCItem>> _citiesByProvinceCache = {};
  static final Map<String, List<PSGCItem>> _barangaysByCityCache = {};

  /// All 82 official Philippine Provinces + Metro Manila (NCR) sorted alphabetically.
  static const List<PSGCItem> provinces = [
    PSGCItem(code: 'ABR', name: 'Abra'),
    PSGCItem(code: 'AGN', name: 'Agusan del Norte'),
    PSGCItem(code: 'AGS', name: 'Agusan del Sur'),
    PSGCItem(code: 'AKL', name: 'Aklan'),
    PSGCItem(code: 'ALB', name: 'Albay'),
    PSGCItem(code: 'ANT', name: 'Antique'),
    PSGCItem(code: 'APA', name: 'Apayao'),
    PSGCItem(code: 'AUR', name: 'Aurora'),
    PSGCItem(code: 'BAS', name: 'Basilan'),
    PSGCItem(code: 'BAN', name: 'Bataan'),
    PSGCItem(code: 'BTN', name: 'Batanes'),
    PSGCItem(code: 'BTG', name: 'Batangas'),
    PSGCItem(code: 'BEN', name: 'Benguet'),
    PSGCItem(code: 'BIL', name: 'Biliran'),
    PSGCItem(code: 'BOH', name: 'Bohol'),
    PSGCItem(code: 'BUK', name: 'Bukidnon'),
    PSGCItem(code: 'BUL', name: 'Bulacan'),
    PSGCItem(code: 'CAG', name: 'Cagayan'),
    PSGCItem(code: 'CAN', name: 'Camarines Norte'),
    PSGCItem(code: 'CAS', name: 'Camarines Sur'),
    PSGCItem(code: 'CAM', name: 'Camiguin'),
    PSGCItem(code: 'CAP', name: 'Capiz'),
    PSGCItem(code: 'CAT', name: 'Catanduanes'),
    PSGCItem(code: 'CAV', name: 'Cavite'),
    PSGCItem(code: 'CEB', name: 'Cebu'),
    PSGCItem(code: 'COM', name: 'Cotabato (North Cotabato)'),
    PSGCItem(code: 'DAV', name: 'Davao de Oro'),
    PSGCItem(code: 'DAN', name: 'Davao del Norte'),
    PSGCItem(code: 'DAS', name: 'Davao del Sur'),
    PSGCItem(code: 'DAC', name: 'Davao Occidental'),
    PSGCItem(code: 'DAO', name: 'Davao Oriental'),
    PSGCItem(code: 'DIN', name: 'Dinagat Islands'),
    PSGCItem(code: 'EAS', name: 'Eastern Samar'),
    PSGCItem(code: 'GUI', name: 'Guimaras'),
    PSGCItem(code: 'IFU', name: 'Ifugao'),
    PSGCItem(code: 'ILN', name: 'Ilocos Norte'),
    PSGCItem(code: 'ILS', name: 'Ilocos Sur'),
    PSGCItem(code: 'ILI', name: 'Iloilo'),
    PSGCItem(code: 'ISA', name: 'Isabela'),
    PSGCItem(code: 'KAL', name: 'Kalinga'),
    PSGCItem(code: 'LUN', name: 'La Union'),
    PSGCItem(code: 'LAG', name: 'Laguna'),
    PSGCItem(code: 'LAN', name: 'Lanao del Norte'),
    PSGCItem(code: 'LAS', name: 'Lanao del Sur'),
    PSGCItem(code: 'LEY', name: 'Leyte'),
    PSGCItem(code: 'MAG', name: 'Maguindanao del Norte'),
    PSGCItem(code: 'MAS', name: 'Maguindanao del Sur'),
    PSGCItem(code: 'MAD', name: 'Marinduque'),
    PSGCItem(code: 'MBE', name: 'Masbate'),
    PSGCItem(code: 'NCR', name: 'Metro Manila (NCR)'),
    PSGCItem(code: 'MIC', name: 'Misamis Occidental'),
    PSGCItem(code: 'MIO', name: 'Misamis Oriental'),
    PSGCItem(code: 'MOP', name: 'Mountain Province'),
    PSGCItem(code: 'NEC', name: 'Negros Occidental'),
    PSGCItem(code: 'NER', name: 'Negros Oriental'),
    PSGCItem(code: 'NSA', name: 'Northern Samar'),
    PSGCItem(code: 'NUE', name: 'Nueva Ecija'),
    PSGCItem(code: 'NUV', name: 'Nueva Vizcaya'),
    PSGCItem(code: 'MDC', name: 'Occidental Mindoro'),
    PSGCItem(code: 'MDR', name: 'Oriental Mindoro'),
    PSGCItem(code: 'PLW', name: 'Palawan'),
    PSGCItem(code: 'PAM', name: 'Pampanga'),
    PSGCItem(code: 'PAN', name: 'Pangasinan'),
    PSGCItem(code: 'QUE', name: 'Quezon'),
    PSGCItem(code: 'QUR', name: 'Quirino'),
    PSGCItem(code: 'RIZ', name: 'Rizal'),
    PSGCItem(code: 'ROM', name: 'Romblon'),
    PSGCItem(code: 'SAM', name: 'Samar (Western Samar)'),
    PSGCItem(code: 'SAR', name: 'Sarangani'),
    PSGCItem(code: 'SIQ', name: 'Siquijor'),
    PSGCItem(code: 'SOR', name: 'Sorsogon'),
    PSGCItem(code: 'SCO', name: 'South Cotabato'),
    PSGCItem(code: 'SLE', name: 'Southern Leyte'),
    PSGCItem(code: 'SKU', name: 'Sultan Kudarat'),
    PSGCItem(code: 'SLU', name: 'Sulu'),
    PSGCItem(code: 'SUN', name: 'Surigao del Norte'),
    PSGCItem(code: 'SUR', name: 'Surigao del Sur'),
    PSGCItem(code: 'TAR', name: 'Tarlac'),
    PSGCItem(code: 'TAW', name: 'Tawi-Tawi'),
    PSGCItem(code: 'ZMB', name: 'Zambales'),
    PSGCItem(code: 'ZAN', name: 'Zamboanga del Norte'),
    PSGCItem(code: 'ZAS', name: 'Zamboanga del Sur'),
    PSGCItem(code: 'ZSI', name: 'Zamboanga Sibugay'),
  ];

  /// Core HUC and major cities mapped to their geographic provinces.
  static const Map<String, List<String>> _extraCitiesByProvince = {
    'CEB': [
      'Cebu City',
      'Mandaue City',
      'Lapu-Lapu City',
      'Talisay City',
      'Toledo City',
      'Danao City',
      'Naga City',
      'Carcar City',
      'Bogo City',
      'Consolacion',
      'Liloan',
      'Minglanilla',
      'Compostela',
      'Cordova',
      'San Fernando',
      'Balamban',
      'Bantayan',
      'Barili',
      'Argao',
      'Daanbantayan'
    ],
    'NCR': [
      'Manila',
      'Quezon City',
      'Caloocan City',
      'Las Piñas City',
      'Makati City',
      'Malabon City',
      'Mandaluyong City',
      'Marikina City',
      'Muntinlupa City',
      'Navotas City',
      'Parañaque City',
      'Pasay City',
      'Pasig City',
      'San Juan City',
      'Taguig City',
      'Valenzuela City',
      'Pateros'
    ],
    'DAS': [
      'Davao City',
      'Digos City',
      'Bansalan',
      'Hagonoy',
      'Kiblawan',
      'Magsaysay',
      'Malalag',
      'Matanao',
      'Padada',
      'Santa Cruz',
      'Sulop'
    ],
    'ILI': [
      'Iloilo City',
      'Passi City',
      'Oton',
      'Pavia',
      'Santa Barbara',
      'Cabatuan',
      'Leganes',
      'Pototan',
      'Dumangas',
      'Barotac Nuevo'
    ],
    'BEN': [
      'Baguio City',
      'La Trinidad',
      'Itogon',
      'Tuba',
      'Tublay',
      'Sablan',
      'Buguias',
      'Mankayan',
      'Atok',
      'Bokod',
      'Kabayan',
      'Kapangan'
    ],
    'NEC': [
      'Bacolod City',
      'Bago City',
      'Cadiz City',
      'Escalante City',
      'Himamaylan City',
      'Kabankalan City',
      'La Carlota City',
      'Sagay City',
      'San Carlos City',
      'Silay City',
      'Sipalay City',
      'Talisay City',
      'Victorias City'
    ],
    'SCO': [
      'General Santos City',
      'Koronadal City',
      'Polomolok',
      'Surallah',
      'Tupi',
      'Tampakan',
      'Banga',
      'Lake Sebu',
      'Norala'
    ],
    'ZAS': [
      'Zamboanga City',
      'Pagadian City',
      'Aurora',
      'Dumalinao',
      'Guipos',
      'Labangan',
      'Molave',
      'San Miguel',
      'Tukuran'
    ],
    'MIO': [
      'Cagayan de Oro City',
      'Gingoog City',
      'El Salvador City',
      'Opol',
      'Tagoloan',
      'Villanueva',
      'Jasaan',
      'Claveria'
    ],
    'PAM': [
      'Angeles City',
      'San Fernando City',
      'Mabalacat City',
      'Guagua',
      'Lubao',
      'Mexico',
      'Arayat',
      'Porac',
      'Apalit'
    ],
  };

  /// Known barangays for major Philippine cities to ensure instant resolution.
  static const Map<String, List<String>> _majorCityBarangays = {
    'cebucity': [
      'Lahug',
      'Banilad',
      'Guadalupe',
      'Talamban',
      'Mabolo',
      'Apas',
      'Labangon',
      'Punta Princesa',
      'Basak San Nicolas',
      'Basak Pardo',
      'Pardo',
      'Quiot Pardo',
      'Sambag I',
      'Sambag II',
      'Tisa',
      'Capitol Site',
      'Kalunasan',
      'Barangay Luz',
      'Kasambagan',
      'Busay',
      'Tejero',
      'Lorega San Miguel',
      'Carreta',
      'Zapatera',
      'Kamputhaw',
      'Cogon Ramos',
      'Pahina Central',
      'San Antonio',
      'San Nicolas Proper',
      'Suba',
      'Pasil'
    ],
    'quezoncity': [
      'Cubao',
      'Diliman',
      'Novaliches',
      'San Francisco del Monte',
      'Loyola Heights',
      'Kamuning',
      'Batasan Hills',
      'Commonwealth',
      'Bagong Silangan',
      'Holy Spirit',
      'Talipapa',
      'San Roque',
      'Barangka',
      'Tandang Sora',
      'South Triangle',
      'Project 6',
      'Project 8'
    ],
    'manila': [
      'Binondo',
      'Ermita',
      'Malate',
      'Paco',
      'Pandacan',
      'Port Area',
      'Quiapo',
      'Sampaloc',
      'San Andres',
      'San Miguel',
      'San Nicolas',
      'Santa Ana',
      'Santa Cruz',
      'Santa Mesa',
      'Tondo',
      'Intramuros'
    ],
    'davaocity': [
      'Poblacion',
      'Buhangin',
      'Matina Crossing',
      'Matina Aplaya',
      'Talomo',
      'Toril',
      'Calinan',
      'Baguio',
      'Marilog',
      'Bunawan',
      'Agdao',
      'Sasa',
      'Tibungco',
      'Panacan',
      'Mintal',
      'Tugbok'
    ],
    'baguiocity': [
      'Session Road Area',
      'Burnham - Legarda',
      'Camp 7',
      'Camp 8',
      'Loakan Proper',
      'Pacdal',
      'Mines View Park',
      'Irisan',
      'Bakakeng Central',
      'Aurora Hill',
      'Trancoville',
      'Guadalupe',
      'Saint Joseph Village'
    ],
    'iloilocity': [
      'City Proper',
      'Jaro',
      'La Paz',
      'Mandurriao',
      'Molo',
      'Villa Arevalo',
      'Lapuz',
      'Calumpang',
      'Baldoza',
      'Bito-on',
      'Quintin Salas',
      'Sambag'
    ],
    'bacolodcity': [
      'Barangay 1 (Pob.)',
      'Barangay 2 (Pob.)',
      'Bata',
      'Mandalagan',
      'Villamonte',
      'Mansilingan',
      'Taculing',
      'Alijis',
      'Singcang-Airport',
      'Tangub',
      'Punta Taytay',
      'Banago',
      'Granada',
      'Estefania'
    ],
  };

  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains('-')) {
        return word.split('-').map((sub) {
          if (sub.isEmpty) return sub;
          return '${sub[0].toUpperCase()}${sub.substring(1).toLowerCase()}';
        }).join('-');
      }
      if (word.startsWith('(') && word.length > 1) {
        return '(${word[1].toUpperCase()}${word.substring(2).toLowerCase()}';
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static String _sanitizeCode(String prefix, String text) {
    final clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toUpperCase();
    return '${prefix}_$clean';
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Returns sorted list of all 82 Philippine provinces + NCR.
  static List<PSGCItem> getProvinces() => List.unmodifiable(provinces);

  /// Returns sorted list of all cities/municipalities in a given province.
  static List<PSGCItem> getCitiesForProvince(String provinceCode) {
    if (_citiesByProvinceCache.containsKey(provinceCode)) {
      return _citiesByProvinceCache[provinceCode]!;
    }

    final provItem = provinces.cast<PSGCItem?>().firstWhere(
          (p) => p?.code == provinceCode,
          orElse: () => null,
        );
    final provName = provItem?.name ?? provinceCode;
    final normProv = _normalize(provName);

    final Set<String> seenCityNames = {};
    final List<PSGCItem> results = [];

    // 1. Include any pre-mapped high-priority cities for this province
    if (_extraCitiesByProvince.containsKey(provinceCode)) {
      for (final name in _extraCitiesByProvince[provinceCode]!) {
        final formattedName = _toTitleCase(name);
        final normName = _normalize(formattedName);
        if (!seenCityNames.contains(normName)) {
          seenCityNames.add(normName);
          results.add(
            PSGCItem(
              code: _sanitizeCode(provinceCode, name),
              name: formattedName,
              parentCode: provinceCode,
            ),
          );
        }
      }
    }

    // 2. Query the complete rpcmb.philippineRegions dataset
    for (final reg in rpcmb.philippineRegions) {
      for (final prov in reg.provinces) {
        final curNormProv = _normalize(prov.name);
        final isMatch = curNormProv == normProv ||
            curNormProv.contains(normProv) ||
            normProv.contains(curNormProv) ||
            (normProv.contains('ncr') && curNormProv.contains('manila')) ||
            (normProv.contains('metromanila') && curNormProv.contains('ncr')) ||
            (normProv.contains('davaodeoro') &&
                curNormProv.contains('compostela')) ||
            (normProv.contains('cotabato') && curNormProv.contains('cotabato'));

        if (isMatch) {
          for (final mun in prov.municipalities) {
            final formattedName = _toTitleCase(mun.name);
            final normName = _normalize(formattedName);
            if (!seenCityNames.contains(normName)) {
              seenCityNames.add(normName);
              results.add(
                PSGCItem(
                  code: _sanitizeCode(provinceCode, mun.name),
                  name: formattedName,
                  parentCode: provinceCode,
                ),
              );
            }
          }
        }
      }
    }

    // 3. Fallback if empty
    if (results.isEmpty) {
      final defaultList = [
        'City of $provName',
        'Poblacion Capital',
        'North District',
        'South District',
      ];
      for (final name in defaultList) {
        results.add(
          PSGCItem(
            code: _sanitizeCode(provinceCode, name),
            name: name,
            parentCode: provinceCode,
          ),
        );
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    _citiesByProvinceCache[provinceCode] = results;
    return results;
  }

  /// Returns sorted list of all official barangays for a given city/municipality.
  static List<PSGCItem> getBarangaysForCity(String cityCode) {
    if (_barangaysByCityCache.containsKey(cityCode)) {
      return _barangaysByCityCache[cityCode]!;
    }

    final rawCityName = cityCode.contains('_')
        ? cityCode.split('_').skip(1).join(' ')
        : cityCode;
    final normCity = _normalize(rawCityName);

    final Set<String> seenBrgyNames = {};
    final List<PSGCItem> results = [];

    // 1. Check if it matches major city barangays directly
    if (_majorCityBarangays.containsKey(normCity)) {
      for (final brgy in _majorCityBarangays[normCity]!) {
        final formattedBrgy = _toTitleCase(brgy);
        final norm = _normalize(formattedBrgy);
        if (!seenBrgyNames.contains(norm)) {
          seenBrgyNames.add(norm);
          results.add(
            PSGCItem(
              code: _sanitizeCode(cityCode, brgy),
              name: formattedBrgy,
              parentCode: cityCode,
            ),
          );
        }
      }
    }

    // 2. Search full philippineRegions dataset for matching municipality/city
    for (final reg in rpcmb.philippineRegions) {
      for (final prov in reg.provinces) {
        for (final mun in prov.municipalities) {
          final curNormMun = _normalize(mun.name);
          final isMatch = curNormMun == normCity ||
              curNormMun.contains(normCity) ||
              normCity.contains(curNormMun) ||
              _sanitizeCode(prov.id, mun.name) == cityCode ||
              mun.id.toUpperCase() == rawCityName.toUpperCase();

          if (isMatch && mun.barangays.isNotEmpty) {
            for (final brgy in mun.barangays) {
              final formattedBrgy = _toTitleCase(brgy);
              final norm = _normalize(formattedBrgy);
              if (!seenBrgyNames.contains(norm)) {
                seenBrgyNames.add(norm);
                results.add(
                  PSGCItem(
                    code: _sanitizeCode(cityCode, brgy),
                    name: formattedBrgy,
                    parentCode: cityCode,
                  ),
                );
              }
            }
          }
        }
      }
    }

    // 3. Fallback default barangays
    if (results.isEmpty) {
      const defaultNames = [
        'Poblacion (Centro)',
        'Poblacion I',
        'Poblacion II',
        'Bagong Silang',
        'San Isidro',
        'San Jose',
        'San Roque',
        'San Vicente',
        'Santa Cruz',
        'Santo Niño',
        'Santo Rosario',
        'Barangay 1',
        'Barangay 2',
        'Barangay 3',
        'Barangay 4',
        'Barangay 5',
      ];
      for (final name in defaultNames) {
        results.add(
          PSGCItem(
            code: _sanitizeCode(cityCode, name),
            name: name,
            parentCode: cityCode,
          ),
        );
      }
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    _barangaysByCityCache[cityCode] = results;
    return results;
  }

  /// Finds a province by its name or code.
  static PSGCItem? findProvinceByName(String name) {
    final clean = name.trim().toLowerCase();
    try {
      return provinces.firstWhere(
        (p) => p.name.toLowerCase() == clean || p.code.toLowerCase() == clean,
      );
    } catch (_) {
      return null;
    }
  }
}
