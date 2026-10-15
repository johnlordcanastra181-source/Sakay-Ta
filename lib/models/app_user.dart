import '../core/constants.dart';

class AppUser {
  final String id;
  final String fullName;
  final String mobile;
  final String? email;
  final bool emailVerified;
  final String passwordHash;
  final String role;
  final String status;
  final String? rejectionReason;
  final bool isOnline;
  final DateTime createdAt;
  final double rating;
  final int ratingCount;
  final int acceptanceCount;
  final int acceptanceTotal;
  final int onTimeCount;
  final int totalTrips;
  final double lifetimeEarnings;
  final DateTime? verifiedAt;
  final String? address;

  /// Last known GPS coordinates (set while a driver is online).
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  /// Public URL of the user's profile picture in Supabase Storage.
  final String? profilePhotoUrl;

  /// Index into the shared avatar accent-color palette (0 when unset).
  final int avatarColor;

  const AppUser({
    required this.id,
    required this.fullName,
    this.mobile = '',
    this.email,
    this.emailVerified = false,
    required this.passwordHash,
    required this.role,
    this.status = AccountStatus.approved,
    this.rejectionReason,
    this.isOnline = false,
    required this.createdAt,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.acceptanceCount = 0,
    this.acceptanceTotal = 0,
    this.onTimeCount = 0,
    this.totalTrips = 0,
    this.lifetimeEarnings = 0,
    this.verifiedAt,
    this.address,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.profilePhotoUrl,
    this.avatarColor = 0,
  });

  bool get isDriver => role == UserRole.driver;
  bool get isPassenger => role == UserRole.passenger;
  bool get isAdmin =>
      role == UserRole.admin || role == 'super_admin' || role == 'Super Admin';
  bool get isSuperAdmin =>
      role == 'super_admin' ||
      role == 'Super Admin' ||
      (isAdmin &&
          (id == 'super-admin-root' ||
              id == 'test-admin-1' ||
              id == 'admin-super-001' ||
              email == 'johnlordcanastra@sakayta.app'));

  bool get isActive =>
      status == AccountStatus.approved || status == AccountStatus.active;
  bool get isDeactivated =>
      status == AccountStatus.deactivated ||
      status == 'inactive' ||
      status == 'disabled';

  bool get canGoOnline => !isDriver || isActive;

  String get ratingLabel => rating.toStringAsFixed(1);

  double get acceptanceRate => acceptanceTotal == 0
      ? 100
      : (acceptanceCount / acceptanceTotal * 100).clamp(0, 100);

  double get accuracyRate =>
      totalTrips == 0 ? 100 : (onTimeCount / totalTrips * 100).clamp(0, 100);

  AppUser copyWith({
    String? status,
    String? rejectionReason,
    bool? isOnline,
    double? rating,
    int? ratingCount,
    int? acceptanceCount,
    int? acceptanceTotal,
    int? onTimeCount,
    int? totalTrips,
    double? lifetimeEarnings,
    DateTime? verifiedAt,
    String? address,
    String? id,
    String? fullName,
    String? mobile,
    String? email,
    bool? emailVerified,
    String? passwordHash,
    String? role,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
    String? profilePhotoUrl,
    int? avatarColor,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      acceptanceCount: acceptanceCount ?? this.acceptanceCount,
      acceptanceTotal: acceptanceTotal ?? this.acceptanceTotal,
      onTimeCount: onTimeCount ?? this.onTimeCount,
      totalTrips: totalTrips ?? this.totalTrips,
      lifetimeEarnings: lifetimeEarnings ?? this.lifetimeEarnings,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'mobile': mobile,
        'email': email,
        'email_verified': emailVerified ? 1 : 0,
        'password_hash': passwordHash,
        'role': role,
        'status': status,
        'rejection_reason': rejectionReason,
        'is_online': isOnline ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'rating': rating,
        'rating_count': ratingCount,
        'acceptance_count': acceptanceCount,
        'acceptance_total': acceptanceTotal,
        'on_time_count': onTimeCount,
        'total_trips': totalTrips,
        'lifetime_earnings': lifetimeEarnings,
        'verified_at': verifiedAt?.millisecondsSinceEpoch,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'location_updated_at': locationUpdatedAt?.millisecondsSinceEpoch,
        'profile_photo_url': profilePhotoUrl,
        'avatar_color': avatarColor,
      };

  static String _resolveStatus(Map<String, Object?> map) {
    final s = (map['status'] as String?)?.toLowerCase().trim();
    final vs = (map['verificationStatus'] as String?)?.toLowerCase().trim();
    final verSnake =
        (map['verification_status'] as String?)?.toLowerCase().trim();

    if (s == AccountStatus.suspended ||
        vs == AccountStatus.suspended ||
        verSnake == AccountStatus.suspended) {
      return AccountStatus.suspended;
    }
    // `active` and `approved` are distinct canonical database values. The
    // admin passenger filter operates on `profiles.account_status`, so do not
    // collapse active passengers into approved drivers while parsing a row.
    if (s == AccountStatus.approved ||
        vs == AccountStatus.approved ||
        verSnake == AccountStatus.approved) {
      return AccountStatus.approved;
    }
    if (s == AccountStatus.active ||
        vs == AccountStatus.active ||
        verSnake == AccountStatus.active) {
      return AccountStatus.active;
    }
    if (s == AccountStatus.rejected ||
        vs == AccountStatus.rejected ||
        verSnake == AccountStatus.rejected) {
      return AccountStatus.rejected;
    }
    if (s == AccountStatus.deactivated ||
        vs == AccountStatus.deactivated ||
        verSnake == AccountStatus.deactivated ||
        s == 'suspended' ||
        vs == 'suspended') {
      return AccountStatus.deactivated;
    }
    if (s == AccountStatus.pending ||
        vs == AccountStatus.pending ||
        verSnake == AccountStatus.pending) {
      return AccountStatus.pending;
    }
    return s ?? vs ?? verSnake ?? AccountStatus.approved;
  }

  factory AppUser.fromMap(Map<String, Object?> map) {
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

    int _int(List<String> keys, [int def = 0]) {
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

    bool _bool(List<String> keys, [bool def = false]) {
      for (final k in keys) {
        final val = map[k];
        if (val is bool) return val;
        if (val is num) return val == 1;
        if (val is String) return val.toLowerCase() == 'true';
      }
      return def;
    }

    return AppUser(
      id: _str(['id', 'uid']),
      fullName: _str(['full_name', 'fullName', 'name']),
      mobile: _str(['mobile', 'phoneNumber']),
      email: map['email']?.toString(),
      emailVerified: _bool(['emailVerified', 'email_verified']),
      passwordHash: _str(['password_hash', 'passwordHash']),
      role: _str(['role'], UserRole.passenger),
      status: _resolveStatus(map),
      rejectionReason: map['rejection_reason']?.toString() ??
          map['rejectionReason']?.toString(),
      isOnline: _bool(['isOnline', 'is_online']),
      createdAt: _date(map['created_at'] ?? map['createdAt']),
      rating: _dbl(['rating', 'rating_average'], 0.0),
      ratingCount: _int(['rating_count', 'ratingCount']),
      acceptanceCount: _int(['acceptance_count', 'acceptanceCount']),
      acceptanceTotal: _int(['acceptance_total', 'acceptanceTotal']),
      totalTrips: _int(['totalTrips', 'total_trips', 'rideCount']),
      lifetimeEarnings:
          _dbl(['lifetimeEarnings', 'totalEarnings', 'lifetime_earnings']),
      verifiedAt: map['verified_at'] == null && map['verifiedAt'] == null
          ? null
          : _date(map['verified_at'] ?? map['verifiedAt']),
      address:
          map['address']?.toString() ?? map['formattedAddress']?.toString(),
      latitude: _dbl(['latitude']),
      longitude: _dbl(['longitude']),
      locationUpdatedAt:
          map['locationUpdatedAt'] == null && map['location_updated_at'] == null
              ? null
              : _date(map['locationUpdatedAt'] ?? map['location_updated_at']),
      profilePhotoUrl: map['profile_photo_url']?.toString() ??
          map['profilePhotoUrl']?.toString(),
      avatarColor: _int(['avatar_color', 'avatarColor']),
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
}
