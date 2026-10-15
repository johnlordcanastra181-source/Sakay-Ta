import 'app_user.dart';
import 'driver_profile.dart';
import '../core/constants.dart';

/// Remote PostgreSQL data models for Sakay Ta.
///
/// These bridge the app's local SQLite models and Supabase rows.
///
/// Collections covered:
///   users, drivers, trips, bookings, chat_messages, toda, transactions
///   ratings, payments, driver_earnings, withdrawals, toda_associations,
///   fare_matrix, magic_links, notifications

class FireRating {
  final String id;
  final String rideId;
  final String fromUserId;
  final String toUserId;
  final int stars;
  final String comment;
  final DateTime createdAt;

  const FireRating({
    required this.id,
    required this.rideId,
    required this.fromUserId,
    required this.toUserId,
    required this.stars,
    this.comment = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'rideId': rideId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'stars': stars,
        'comment': comment,
        'createdAt': createdAt,
      };

  factory FireRating.fromMap(Map<String, dynamic> map) => FireRating(
        id: map['id'] as String? ?? '',
        rideId: map['rideId'] as String? ?? '',
        fromUserId: map['fromUserId'] as String? ?? '',
        toUserId: map['toUserId'] as String? ?? '',
        stars: (map['stars'] as num?)?.toInt() ?? 5,
        comment: map['comment'] as String? ?? '',
        createdAt: _asDate(map['createdAt']),
      );
}

class FirePayment {
  final String id;
  final String rideId;
  final String payerId;
  final String payeeId;
  final double amount;
  final String method; // cash | gcash | maya | card
  final String
      status; // unpaid | pending_payment | paid | failed | cancelled | refunded
  final String? reference;
  final String? sessionId;
  final String? checkoutUrl;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const FirePayment({
    required this.id,
    required this.rideId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.method,
    required this.status,
    this.reference,
    this.sessionId,
    this.checkoutUrl,
    this.verifiedAt,
    required this.createdAt,
  });

  FirePayment copyWith({
    String? id,
    String? rideId,
    String? payerId,
    String? payeeId,
    double? amount,
    String? method,
    String? status,
    String? reference,
    String? sessionId,
    String? checkoutUrl,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) =>
      FirePayment(
        id: id ?? this.id,
        rideId: rideId ?? this.rideId,
        payerId: payerId ?? this.payerId,
        payeeId: payeeId ?? this.payeeId,
        amount: amount ?? this.amount,
        method: method ?? this.method,
        status: status ?? this.status,
        reference: reference ?? this.reference,
        sessionId: sessionId ?? this.sessionId,
        checkoutUrl: checkoutUrl ?? this.checkoutUrl,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'rideId': rideId,
        'payerId': payerId,
        'payeeId': payeeId,
        'amount': amount,
        'method': method,
        'status': status,
        'reference': reference,
        if (sessionId != null) 'sessionId': sessionId,
        if (checkoutUrl != null) 'checkoutUrl': checkoutUrl,
        if (verifiedAt != null) 'verifiedAt': verifiedAt,
        'createdAt': createdAt,
      };

  factory FirePayment.fromMap(Map<String, dynamic> map) => FirePayment(
        id: map['id'] as String? ?? '',
        rideId: map['rideId'] as String? ?? '',
        payerId: map['payerId'] as String? ?? '',
        payeeId: map['payeeId'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? 'cash',
        status: map['status'] as String? ?? 'unpaid',
        reference: map['reference'] as String?,
        sessionId: map['sessionId'] as String?,
        checkoutUrl: map['checkoutUrl'] as String?,
        verifiedAt: _asDateOrNull(map['verifiedAt']),
        createdAt: _asDate(map['createdAt']),
      );
}

class DriverEarning {
  final String id;
  final String driverId;
  final String rideId;
  final double fare;
  final double commission;
  final double net;
  final String paymentMethod;
  final String settlementStatus;
  final DateTime createdAt;

  const DriverEarning({
    required this.id,
    required this.driverId,
    required this.rideId,
    required this.fare,
    required this.commission,
    required this.net,
    this.paymentMethod = 'cash',
    this.settlementStatus = 'confirmed',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'driverId': driverId,
        'rideId': rideId,
        'fare': fare,
        'commission': commission,
        'net': net,
        'paymentMethod': paymentMethod,
        'settlementStatus': settlementStatus,
        'createdAt': createdAt,
      };

  factory DriverEarning.fromMap(Map<String, dynamic> map) {
    String _str(List<String> keys, [String def = '']) {
      for (final k in keys) {
        final val = map[k];
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty) return str;
        }
      }
      return def;
    }

    double _dbl(List<String> keys, [double def = 0.0]) {
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

    return DriverEarning(
      id: _str(['id']),
      driverId: _str(['driverId', 'driver_id']),
      rideId: _str(['rideId', 'ride_id']),
      fare: _dbl(['fare']),
      commission: _dbl(['commission']),
      net: _dbl(['net']),
      paymentMethod: _str(['paymentMethod', 'payment_method'], 'cash'),
      settlementStatus:
          _str(['settlementStatus', 'settlement_status'], 'confirmed'),
      createdAt: _asDate(map['createdAt'] ?? map['created_at']),
    );
  }
}

class Withdrawal {
  final String id;
  final String driverId;
  final double amount;
  final String method; // gcash | bank | maya
  final String status; // pending | processing | completed | failed
  final String? reference;
  final String? note;
  final DateTime createdAt;
  final DateTime? processedAt;

  const Withdrawal({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.method,
    this.status = 'pending',
    this.reference,
    this.note,
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'driverId': driverId,
        'amount': amount,
        'method': method,
        'status': status,
        'reference': reference,
        'note': note,
        'createdAt': createdAt,
        'processedAt': processedAt,
      };

  factory Withdrawal.fromMap(Map<String, dynamic> map) => Withdrawal(
        id: map['id'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? 'gcash',
        status: map['status'] as String? ?? 'pending',
        reference: map['reference'] as String?,
        note: map['note'] as String?,
        createdAt: _asDate(map['createdAt']),
        processedAt: _asDateOrNull(map['processedAt']),
      );
}

class FareMatrix {
  final String id; // e.g. 'tricycle' | 'habal'
  final String vehicleType;
  final double baseFare;
  final double includedBaseDistance;
  final double perKm;
  final double minimumFare;
  final double commissionRate;
  final DateTime updatedAt;

  const FareMatrix({
    required this.id,
    required this.vehicleType,
    required this.baseFare,
    this.includedBaseDistance = 1.0,
    required this.perKm,
    required this.minimumFare,
    required this.commissionRate,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleType': vehicleType,
        'baseFare': baseFare,
        'includedBaseDistance': includedBaseDistance,
        'perKm': perKm,
        'minimumFare': minimumFare,
        'commissionRate': commissionRate,
        'updatedAt': updatedAt,
      };

  factory FareMatrix.fromMap(Map<String, dynamic> map) => FareMatrix(
        id: map['id'] as String? ?? '',
        vehicleType: map['vehicleType'] as String? ?? 'tricycle',
        baseFare: (map['baseFare'] as num?)?.toDouble() ?? 0,
        includedBaseDistance:
            (map['includedBaseDistance'] as num?)?.toDouble() ?? 1.0,
        perKm: (map['perKm'] as num?)?.toDouble() ?? 0,
        minimumFare: (map['minimumFare'] as num?)?.toDouble() ?? 0,
        // Legacy field retained for old snapshots; new fare flows do not use it.
        commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.0,
        updatedAt: _asDate(map['updatedAt']),
      );
}

class TodaAssociation {
  final String id;
  final String todaId;
  final String driverId;
  final String status; // pending | approved | removed
  final String role; // member | officer | leader
  final DateTime createdAt;

  const TodaAssociation({
    required this.id,
    required this.todaId,
    required this.driverId,
    this.status = 'approved',
    this.role = 'member',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'todaId': todaId,
        'driverId': driverId,
        'status': status,
        'role': role,
        'createdAt': createdAt,
      };

  factory TodaAssociation.fromMap(Map<String, dynamic> map) => TodaAssociation(
        id: map['id'] as String? ?? '',
        todaId: map['todaId'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        status: map['status'] as String? ?? 'approved',
        role: map['role'] as String? ?? 'member',
        createdAt: _asDate(map['createdAt']),
      );
}

/// Parses a PostgreSQL ISO timestamp / DateTime / epoch-millis.
DateTime _asDate(Object? value) {
  final parsed = _asDateOrNull(value);
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asDateOrNull(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class DriverLiveLocation {
  const DriverLiveLocation({
    required this.position,
    required this.updatedAt,
    required this.fromCache,
  });

  final Geo position;
  final DateTime? updatedAt;
  final bool fromCache;

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!).abs() <=
          const Duration(seconds: 90);
}

class PassengerCloudProfile {
  final String userId;
  final String? defaultAddress;
  final List<String> savedAddresses;

  const PassengerCloudProfile({
    required this.userId,
    this.defaultAddress,
    this.savedAddresses = const [],
  });

  factory PassengerCloudProfile.fromMap(Map<String, Object?> map) {
    final addresses = map['savedAddresses'] ?? map['saved_addresses'];
    return PassengerCloudProfile(
      userId: (map['userId'] ?? map['user_id'] ?? map['id']) as String,
      defaultAddress:
          (map['defaultAddress'] ?? map['default_address']) as String?,
      savedAddresses: addresses is Iterable
          ? addresses.whereType<String>().toList()
          : const [],
    );
  }
}

class DriverApplication {
  final AppUser user;
  final DriverProfile profile;
  final String verificationStatus;

  /// Non-null for the pre-Auth application record introduced by the secure
  /// approval workflow. Legacy records continue to use the Auth UUID.
  final String? applicationId;
  final DateTime? reviewedAt;
  final String notificationStatus;
  final String? reviewedBy;
  final String? reviewerName;

  const DriverApplication({
    required this.user,
    required this.profile,
    required this.verificationStatus,
    this.applicationId,
    this.reviewedAt,
    this.notificationStatus = 'not_sent',
    this.reviewedBy,
    this.reviewerName,
  });
}

/// Active ride statuses used by trip queries.
const kActiveRideStatuses = [
  RideStatus.searching,
  RideStatus.accepted,
  RideStatus.arrived,
  RideStatus.started,
];
