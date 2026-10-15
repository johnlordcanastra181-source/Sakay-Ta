import '../core/constants.dart';

class DriverProfile {
  static const Object _keepLicenseType = Object();

  final String userId;
  final String dob;
  final String sex;
  final String address;
  final String? licenseType;
  final String licenseNumber;
  final String licenseExpiry;
  final List<String> dlCodes;
  final List<String> conditionCodes;
  final VehicleType vehicleType;
  final String plateNumber;
  final String make;
  final String model;
  final int year;
  final String color;
  final String? todaId;
  final String? todaName;
  final String barangay;
  final String municipality;
  final String province;
  final String? docLicenseFront;
  final String? docLicenseBack;
  final String? docOrCr;
  final String? docProfile;
  final DateTime submittedAt;

  const DriverProfile({
    required this.userId,
    this.dob = '',
    this.sex = '',
    this.address = '',
    this.licenseType,
    this.licenseNumber = '',
    this.licenseExpiry = '',
    this.dlCodes = const [],
    this.conditionCodes = const [],
    required this.vehicleType,
    this.plateNumber = '',
    this.make = '',
    this.model = '',
    this.year = 2026,
    this.color = '',
    this.todaId,
    this.todaName,
    this.barangay = '',
    this.municipality = '',
    this.province = '',
    this.docLicenseFront,
    this.docLicenseBack,
    this.docOrCr,
    this.docProfile,
    required this.submittedAt,
  });

  bool get hasAllDocuments =>
      (docLicenseFront?.trim().isNotEmpty ?? false) &&
      (docLicenseBack?.trim().isNotEmpty ?? false) &&
      (docOrCr?.trim().isNotEmpty ?? false) &&
      (docProfile?.trim().isNotEmpty ?? false);

  DriverProfile copyWith({
    String? userId,
    String? dob,
    String? sex,
    String? address,
    Object? licenseType = _keepLicenseType,
    String? licenseNumber,
    String? licenseExpiry,
    List<String>? dlCodes,
    List<String>? conditionCodes,
    VehicleType? vehicleType,
    String? plateNumber,
    String? make,
    String? model,
    int? year,
    String? color,
    String? todaId,
    String? todaName,
    String? barangay,
    String? municipality,
    String? province,
    String? docLicenseFront,
    String? docLicenseBack,
    String? docOrCr,
    String? docProfile,
    DateTime? submittedAt,
  }) {
    return DriverProfile(
      userId: userId ?? this.userId,
      dob: dob ?? this.dob,
      sex: sex ?? this.sex,
      address: address ?? this.address,
      licenseType: identical(licenseType, _keepLicenseType)
          ? this.licenseType
          : licenseType as String?,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      dlCodes: dlCodes ?? this.dlCodes,
      conditionCodes: conditionCodes ?? this.conditionCodes,
      vehicleType: vehicleType ?? this.vehicleType,
      plateNumber: plateNumber ?? this.plateNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      todaId: todaId ?? this.todaId,
      todaName: todaName ?? this.todaName,
      barangay: barangay ?? this.barangay,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      docLicenseFront: docLicenseFront ?? this.docLicenseFront,
      docLicenseBack: docLicenseBack ?? this.docLicenseBack,
      docOrCr: docOrCr ?? this.docOrCr,
      docProfile: docProfile ?? this.docProfile,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'user_id': userId,
        'dob': dob,
        'sex': sex,
        'address': address,
        // SQLite's legacy local cache keeps this column NOT NULL; the
        // Supabase serializer writes an actual SQL NULL for an absent license.
        'license_type': licenseType ?? '',
        'license_number': licenseNumber,
        'license_expiry': licenseExpiry,
        'dl_codes': dlCodes.join(','),
        'condition_codes': conditionCodes.join(','),
        'vehicle_type': vehicleType.key,
        'plate_number': plateNumber,
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'toda_id': todaId,
        'toda_name': todaName,
        'barangay': barangay,
        'municipality': municipality,
        'province': province,
        'doc_license_front': docLicenseFront,
        'doc_license_back': docLicenseBack,
        'doc_or_cr': docOrCr,
        'doc_profile': docProfile,
        'profilePhotoUrl': docProfile,
        'profile_photo_url': docProfile,
        'submitted_at': submittedAt.millisecondsSinceEpoch,
      };

  factory DriverProfile.fromMap(Map<String, Object?> map) {
    String readString(List<String> keys, [String def = '']) {
      for (final k in keys) {
        final val = map[k];
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty) return str;
        }
      }
      return def;
    }

    int readInt(List<String> keys, [int? def]) {
      for (final k in keys) {
        final val = map[k];
        if (val is num) return val.toInt();
        if (val is String) {
          final p = int.tryParse(val);
          if (p != null) return p;
        }
      }
      return def ?? DateTime.now().year;
    }

    return DriverProfile(
      userId: readString(['user_id', 'userId']),
      dob: readString(['dob']),
      sex: readString(['sex']),
      address: readString(['address']),
      licenseType: readString(['license_type']).isEmpty
          ? null
          : readString(['license_type']),
      licenseNumber: readString(['license_number']),
      licenseExpiry: readString(['license_expiry']),
      dlCodes: _split(map['dl_codes'], const []),
      conditionCodes: _split(map['condition_codes'], const []),
      vehicleType: VehicleTypeX.fromKey(
        readString(['vehicle_type', 'vehicleType']).isNotEmpty
            ? readString(['vehicle_type', 'vehicleType'])
            : (map['vehicleInfo'] is Map
                    ? (map['vehicleInfo'] as Map)['type']?.toString()
                    : (map['vehicle_info'] is Map
                        ? (map['vehicle_info'] as Map)['type']?.toString()
                        : readString(['vehicle']))) ??
                'tricycle',
      ),
      plateNumber: readString(['plate_number']),
      make: readString(['make']),
      model: readString(['model']),
      year: readInt(['year']),
      color: readString(['color']),
      todaId: map['toda_id']?.toString(),
      todaName: map['toda_name']?.toString() ?? map['todaName']?.toString(),
      barangay: readString(['barangay']),
      municipality: readString(['municipality']),
      province: readString(['province']),
      docLicenseFront: map['doc_license_front']?.toString(),
      docLicenseBack: map['doc_license_back']?.toString(),
      docOrCr: map['doc_or_cr']?.toString(),
      docProfile: map['doc_profile']?.toString() ??
          map['profilePhotoUrl']?.toString() ??
          map['profile_photo_url']?.toString() ??
          map['docProfile']?.toString(),
      submittedAt: _date(map['submitted_at'] ?? map['submittedAt']),
    );
  }

  static DateTime _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<String> _split(Object? value, List<String> fallback) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return fallback;
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }
}
