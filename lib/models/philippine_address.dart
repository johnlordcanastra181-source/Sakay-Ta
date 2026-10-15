/// Structured Philippine address representation based on official PSGC standards.
class PhilippineAddress {
  final String provinceName;
  final String provinceCode;
  final String cityName;
  final String cityCode;
  final String barangayName;
  final String barangayCode;
  final String? streetDetails;

  const PhilippineAddress({
    required this.provinceName,
    required this.provinceCode,
    required this.cityName,
    required this.cityCode,
    required this.barangayName,
    required this.barangayCode,
    this.streetDetails,
  });

  /// Human-readable formatted address string.
  String get formattedAddress {
    final parts = <String>[];
    if (streetDetails != null && streetDetails!.trim().isNotEmpty) {
      parts.add(streetDetails!.trim());
    }
    if (barangayName.isNotEmpty) parts.add('Brgy. $barangayName');
    if (cityName.isNotEmpty) parts.add(cityName);
    if (provinceName.isNotEmpty) parts.add(provinceName);
    parts.add('Philippines');
    return parts.join(', ');
  }

  bool get isComplete =>
      provinceName.isNotEmpty && cityName.isNotEmpty && barangayName.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'province_name': provinceName,
        'province_code': provinceCode,
        'city_name': cityName,
        'city_code': cityCode,
        'barangay_name': barangayName,
        'barangay_code': barangayCode,
        'street_details': streetDetails ?? '',
        'formatted_address': formattedAddress,
      };

  factory PhilippineAddress.fromMap(Map<String, dynamic> map) =>
      PhilippineAddress(
        provinceName: (map['province_name'] ?? map['province'] ?? '') as String,
        provinceCode: (map['province_code'] ?? '') as String,
        cityName: (map['city_name'] ?? map['municipality'] ?? '') as String,
        cityCode: (map['city_code'] ?? '') as String,
        barangayName: (map['barangay_name'] ?? map['barangay'] ?? '') as String,
        barangayCode: (map['barangay_code'] ?? '') as String,
        streetDetails:
            (map['street_details'] ?? map['street'] ?? '') as String?,
      );

  PhilippineAddress copyWith({
    String? provinceName,
    String? provinceCode,
    String? cityName,
    String? cityCode,
    String? barangayName,
    String? barangayCode,
    String? streetDetails,
  }) {
    return PhilippineAddress(
      provinceName: provinceName ?? this.provinceName,
      provinceCode: provinceCode ?? this.provinceCode,
      cityName: cityName ?? this.cityName,
      cityCode: cityCode ?? this.cityCode,
      barangayName: barangayName ?? this.barangayName,
      barangayCode: barangayCode ?? this.barangayCode,
      streetDetails: streetDetails ?? this.streetDetails,
    );
  }

  @override
  String toString() => formattedAddress;
}
