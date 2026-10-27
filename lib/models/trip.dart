import '../core/constants.dart';

class Booking {
  final String id;
  final String passengerId;
  final VehicleType vehicleType;
  final String pickupAddress;
  final String dropoffAddress;
  final Geo pickup;
  final Geo dropoff;
  final String paymentMethod;
  final String status;
  final bool queued;
  final int passengerCount;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.passengerId,
    required this.vehicleType,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickup,
    required this.dropoff,
    this.paymentMethod = PaymentMethod.cash,
    this.status = 'requested',
    this.queued = false,
    this.passengerCount = 1,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'passenger_id': passengerId,
        'vehicle_type': vehicleType.key,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickup.lat,
        'pickup_lng': pickup.lng,
        'dropoff_lat': dropoff.lat,
        'dropoff_lng': dropoff.lng,
        'payment_method': paymentMethod,
        'status': status,
        'queued': queued ? 1 : 0,
        'passenger_count': passengerCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Booking.fromMap(Map<String, Object?> map) {
    double parseVal(Object? val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final p = double.tryParse(val);
        if (p != null) return p;
      }
      return 0.0;
    }

    return Booking(
      id: (map['id'] ?? '').toString(),
      passengerId: (map['passenger_id'] ?? map['passengerId'] ?? '').toString(),
      vehicleType: VehicleTypeX.fromKey(
          (map['vehicle_type'] ?? map['vehicleType'] ?? 'tricycle').toString()),
      pickupAddress: (map['pickup_address'] ?? map['pickupAddress'] ?? '').toString(),
      dropoffAddress: (map['destination_address'] ??
              map['dropoff_address'] ??
              map['destinationAddress'] ??
              map['dropoffAddress'] ??
              '')
          .toString(),
      pickup: Geo(
        parseVal(map['pickup_lat'] ?? map['pickup_latitude'] ?? map['pickupLat']),
        parseVal(map['pickup_lng'] ?? map['pickup_longitude'] ?? map['pickupLng']),
      ),
      dropoff: Geo(
        parseVal(map['dropoff_lat'] ??
            map['destination_latitude'] ??
            map['destination_lat'] ??
            map['dropoff_latitude'] ??
            map['dropoffLat']),
        parseVal(map['dropoff_lng'] ??
            map['destination_longitude'] ??
            map['destination_lng'] ??
            map['dropoff_longitude'] ??
            map['dropoffLng']),
      ),
      paymentMethod:
          (map['payment_method'] ?? map['paymentMethod'] ?? PaymentMethod.cash)
              .toString(),
      status: (map['status'] ?? 'requested').toString(),
      queued: map['queued'] == true || map['queued'] == 1,
      passengerCount: ((map['passenger_count'] ?? map['passengerCount'] ?? 1) as num?)?.toInt() ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }
}

class Trip {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String? driverId;
  final VehicleType vehicleType;
  final String pickupAddress;
  final String dropoffAddress;
  final Geo pickup;
  final Geo dropoff;
  final double distanceKm;
  final int durationMin;
  final double fare;
  final double commission;
  final double net;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? rating;
  final String? ratingComment;
  final bool queued;
  final int passengerCount;

  const Trip({
    required this.id,
    required this.passengerId,
    this.passengerName = '',
    this.passengerPhone = '',
    this.driverId,
    required this.vehicleType,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.commission,
    required this.net,
    this.status = RideStatus.searching,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.rating,
    this.ratingComment,
    this.queued = false,
    this.passengerCount = 1,
  });

  bool get isActive => RideStatus.isActive(status);
  bool get hasValidDropoff => dropoff.isValid;
  bool get hasValidPickup => pickup.isValid;

  String get effectiveDropoffAddress {
    if (dropoffAddress.trim().isNotEmpty) return dropoffAddress.trim();
    if (hasValidDropoff) {
      return 'Coordinates: ${dropoff.lat.toStringAsFixed(5)}, ${dropoff.lng.toStringAsFixed(5)}';
    }
    return 'Destination unavailable';
  }

  String get effectivePickupAddress {
    if (pickupAddress.trim().isNotEmpty) return pickupAddress.trim();
    if (hasValidPickup) {
      return 'Coordinates: ${pickup.lat.toStringAsFixed(5)}, ${pickup.lng.toStringAsFixed(5)}';
    }
    return 'Pickup unavailable';
  }

  Trip copyWith({
    String? driverId,
    String? status,
    String? paymentStatus,
    DateTime? acceptedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? rating,
    String? ratingComment,
    int? passengerCount,
  }) {
    return Trip(
      id: id,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      driverId: driverId ?? this.driverId,
      vehicleType: vehicleType,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickup: pickup,
      dropoff: dropoff,
      distanceKm: distanceKm,
      durationMin: durationMin,
      fare: fare,
      commission: commission,
      net: net,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      queued: queued,
      passengerCount: passengerCount ?? this.passengerCount,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'passenger_id': passengerId,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'driver_id': driverId,
        'vehicle_type': vehicleType.key,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickup.lat,
        'pickup_lng': pickup.lng,
        'dropoff_lat': dropoff.lat,
        'dropoff_lng': dropoff.lng,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'fare': fare,
        'commission': commission,
        'net': net,
        'status': status,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'created_at': createdAt.millisecondsSinceEpoch,
        'accepted_at': acceptedAt?.millisecondsSinceEpoch,
        'arrived_at': arrivedAt?.millisecondsSinceEpoch,
        'started_at': startedAt?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'rating': rating,
        'rating_comment': ratingComment,
        'queued': queued ? 1 : 0,
        'passenger_count': passengerCount,
      };

  factory Trip.fromMap(Map<String, Object?> map) {
    String strVal(List<String> keys, [String def = '']) {
      for (final k in keys) {
        final val = map[k];
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty) return str;
        }
      }
      return def;
    }

    double dblVal(List<String> keys, [double def = 0.0]) {
      for (final k in keys) {
        final val = map[k];
        if (val is num) return val.toDouble();
        if (val is String) {
          final p = double.tryParse(val);
          if (p != null) return p;
        }
      }
      return def;
    }

    int intVal(List<String> keys, [int def = 0]) {
      for (final k in keys) {
        final val = map[k];
        if (val is num) return val.toInt();
        if (val is String) {
          final p = int.tryParse(val);
          if (p != null) return p;
        }
      }
      return def;
    }

    final pickup = _geo(
      map['pickupLocation'] ?? map['pickup_location'],
      map['pickup_lat'] ?? map['pickup_latitude'] ?? map['pickupLat'],
      map['pickup_lng'] ?? map['pickup_longitude'] ?? map['pickupLng'],
    );
    final dropoff = _geo(
      map['destinationLocation'] ??
          map['dropoffLocation'] ??
          map['destination_location'],
      map['dropoff_lat'] ??
          map['destination_latitude'] ??
          map['destination_lat'] ??
          map['dropoff_latitude'] ??
          map['dropoffLat'],
      map['dropoff_lng'] ??
          map['destination_longitude'] ??
          map['destination_lng'] ??
          map['dropoff_longitude'] ??
          map['dropoffLng'],
    );
    return Trip(
      id: (map['id'] ?? '').toString(),
      passengerId: (map['passenger_id'] ?? map['passengerId'] ?? '').toString(),
      passengerName: strVal(['passenger_name', 'passengerName']),
      passengerPhone: strVal(['passenger_phone', 'passengerPhone']),
      driverId: _nullableString(map['driver_id'] ?? map['driverId']),
      vehicleType: VehicleTypeX.fromKey(
          (map['vehicle_type'] ?? map['vehicleType'] ?? 'tricycle').toString()),
      pickupAddress: strVal(['pickup_address', 'pickupAddress', 'pickup']),
      dropoffAddress: strVal([
        'destination_address',
        'dropoff_address',
        'destinationAddress',
        'dropoffAddress',
        'destination',
      ]),
      pickup: pickup,
      dropoff: dropoff,
      distanceKm:
          dblVal(['distance_km', 'distanceKm'], Geo.distanceKm(pickup, dropoff)),
      durationMin: intVal(['duration_min', 'duration_minutes', 'durationMin']),
      fare: dblVal(['fare']),
      commission: dblVal(['commission']),
      net: dblVal(['net']),
      status: RideStatus.normalize(map['status']?.toString()),
      paymentMethod:
          strVal(['payment_method', 'paymentMethod'], PaymentMethod.cash),
      paymentStatus:
          strVal(['payment_status', 'paymentStatus'], PaymentStatus.unpaid),
      createdAt: _date(map['created_at'] ?? map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      acceptedAt: _date(map['accepted_at'] ?? map['acceptedAt']),
      arrivedAt: _date(map['arrived_at'] ?? map['arrivedAt']),
      startedAt: _date(map['started_at'] ?? map['startedAt']),
      completedAt: _date(map['completed_at'] ?? map['completedAt']),
      rating: intVal(['rating'], 0) > 0 ? intVal(['rating']) : null,
      ratingComment: map['rating_comment']?.toString(),
      queued: map['queued'] == true || map['queued'] == 1,
      passengerCount: intVal(['passenger_count', 'passengerCount'], 1).clamp(1, 4),
    );
  }

  static Geo _geo(Object? nested, Object? latitude, Object? longitude) {
    if (nested is Map) {
      final lat = (nested['latitude'] ?? nested['lat']) as num?;
      final lng = (nested['longitude'] ?? nested['lng']) as num?;
      if (lat != null && lng != null) {
        return Geo(lat.toDouble(), lng.toDouble());
      }
    }
    double parseVal(Object? val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final p = double.tryParse(val);
        if (p != null) return p;
      }
      return 0.0;
    }
    return Geo(
      parseVal(latitude),
      parseVal(longitude),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _nullableString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }
}
