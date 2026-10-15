import '../core/constants.dart';

class FareMatrix {
  final String id;
  final VehicleType vehicleType;
  final double baseFare;

  /// Distance covered by [baseFare] before the per-kilometre rate applies.
  final double includedBaseDistance;
  final double perKmRate;

  // These fields are retained for backwards-compatible reads of older rows.
  // The active fare formula intentionally does not use them.
  final double perMinuteRate;
  final double minimumFare;
  final double bookingFee;
  final double surgeMultiplier;
  final double commissionPercent;
  final bool isActive;
  final DateTime updatedAt;

  FareMatrix({
    required this.id,
    required this.vehicleType,
    required this.baseFare,
    this.includedBaseDistance = 1.0,
    required this.perKmRate,
    required this.perMinuteRate,
    required this.minimumFare,
    required this.bookingFee,
    required this.surgeMultiplier,
    required this.commissionPercent,
    required this.isActive,
    required this.updatedAt,
  });

  factory FareMatrix.fromJson(Map<String, dynamic> json) {
    return FareMatrix(
      id: json['id'] as String,
      vehicleType: _parseVehicleType(json['vehicle_type']),
      baseFare: _parseDouble(json['base_fare']),
      includedBaseDistance:
          _parseDouble(json['included_base_distance'], fallback: 1.0),
      perKmRate: _parseDouble(json['per_km_rate']),
      perMinuteRate: _parseDouble(json['per_minute_rate']),
      minimumFare: _parseDouble(json['minimum_fare']),
      bookingFee: _parseDouble(json['booking_fee']),
      surgeMultiplier: _parseDouble(json['surge_multiplier']),
      commissionPercent: _parseDouble(json['commission_percent']),
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_type': vehicleType.key,
      'base_fare': baseFare,
      'included_base_distance': includedBaseDistance,
      'per_km_rate': perKmRate,
      'minimum_fare': minimumFare,
      'is_active': isActive,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FareMatrix copyWith({
    String? id,
    VehicleType? vehicleType,
    double? baseFare,
    double? includedBaseDistance,
    double? perKmRate,
    double? perMinuteRate,
    double? minimumFare,
    double? bookingFee,
    double? surgeMultiplier,
    double? commissionPercent,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return FareMatrix(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      baseFare: baseFare ?? this.baseFare,
      includedBaseDistance: includedBaseDistance ?? this.includedBaseDistance,
      perKmRate: perKmRate ?? this.perKmRate,
      perMinuteRate: perMinuteRate ?? this.perMinuteRate,
      minimumFare: minimumFare ?? this.minimumFare,
      bookingFee: bookingFee ?? this.bookingFee,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static VehicleType _parseVehicleType(dynamic val) {
    if (val == 'tricycle') return VehicleType.tricycle;
    return VehicleType.habal;
  }

  static double _parseDouble(dynamic val, {double fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }
}
