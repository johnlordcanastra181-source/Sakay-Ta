import 'dart:math' as math;

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';

/// A driver card shown in the passenger booking search, built from real
/// driver data (users + driver profiles in Firestore / the local database).
class NearbyDriver {
  final String id;
  final String name;
  final String photoUrl;
  final VehicleType vehicleType;
  final String plateNumber;
  final double rating;
  final int ratingCount;
  final int completedTrips;
  final double acceptanceRate;
  final Geo location;
  final double distanceKm;
  final int etaMinutes;
  final bool isOnline;
  final bool isAvailable;
  final bool hasLiveSession;
  final DateTime? locationUpdatedAt;

  NearbyDriver({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.vehicleType,
    required this.plateNumber,
    required this.rating,
    required this.ratingCount,
    required this.completedTrips,
    required this.acceptanceRate,
    required this.location,
    required this.distanceKm,
    required this.etaMinutes,
    required this.isOnline,
    this.isAvailable = true,
    this.hasLiveSession = true,
    this.locationUpdatedAt,
  });

  /// Builds a driver card from a user record + driver verification profile.
  /// When [passenger] is provided, distance/ETA are computed against the
  /// passenger's live location; otherwise the stored coordinates are used.
  factory NearbyDriver.fromUserAndProfile({
    required AppUser user,
    required DriverProfile profile,
    Geo? passenger,
  }) {
    if (user.latitude == null || user.longitude == null) {
      throw StateError('A real driver location is required.');
    }
    final location = Geo(user.latitude!, user.longitude!);
    final distance = passenger != null
        ? DriverMatchingService.calculateDistanceKm(passenger, location)
        : 0.0;
    final speed = profile.vehicleType == VehicleType.tricycle ? 20.0 : 30.0;
    final eta = math.max(1, (distance / speed * 60).round());
    return NearbyDriver(
      id: user.id,
      name: user.fullName,
      photoUrl: profile.docProfile ?? '',
      vehicleType: profile.vehicleType,
      plateNumber: profile.plateNumber,
      rating: user.rating,
      ratingCount: user.ratingCount,
      completedTrips: user.totalTrips,
      acceptanceRate: user.acceptanceRate,
      location: location,
      distanceKm: distance,
      etaMinutes: eta,
      isOnline: user.isOnline,
      isAvailable: user.isOnline &&
          (user.status == AccountStatus.approved ||
              user.status == AccountStatus.active),
      locationUpdatedAt: user.locationUpdatedAt,
    );
  }

  factory NearbyDriver.fromRpcMap(Map<String, dynamic> row) {
    final latitude = _asDouble(row['latitude']);
    final longitude = _asDouble(row['longitude']);
    if (latitude == null || longitude == null) {
      throw const FormatException(
          'Nearby driver row is missing valid coordinates.');
    }
    final distanceKm = _asDouble(row['distance_km']) ?? 0.0;
    return NearbyDriver(
      id: row['user_id']?.toString() ?? '',
      name: row['full_name']?.toString() ?? '',
      photoUrl: row['profile_photo_path']?.toString() ?? '',
      vehicleType: VehicleTypeX.fromKey(row['vehicle_type']?.toString() ?? ''),
      plateNumber: row['plate_number']?.toString() ?? '',
      rating: _asDouble(row['rating_average']) ?? 5.0,
      ratingCount: _asInt(row['rating_count']) ?? 0,
      completedTrips:
          0, // Not provided by RPC, but not strictly needed for UI usually
      acceptanceRate: 1.0,
      location: Geo(latitude, longitude),
      distanceKm: distanceKm,
      etaMinutes: math.max(1, (distanceKm / 30.0 * 60).round()),
      isOnline: _asBool(row['is_online']),
      isAvailable:
          _asBool(row['is_available']) && !_asBool(row['has_active_ride']),
      hasLiveSession: row.containsKey('has_live_session')
          ? _asBool(row['has_live_session'])
          : true,
      locationUpdatedAt: _asDateTime(row['last_location_at']),
    );
  }

  bool get hasUsableLastLocation =>
      location.isValid && locationUpdatedAt != null;

  bool get hasFreshBookableLocation {
    final updatedAt = locationUpdatedAt;
    if (updatedAt == null) return false;
    final now = DateTime.now().toUtc();
    final timestamp = updatedAt.toUtc();
    return !timestamp.isBefore(
          now.subtract(NearbyDriverConfig.bookableLocationMaxAge),
        ) &&
        !timestamp.isAfter(now.add(const Duration(seconds: 30)));
  }

  /// A passenger may create a short-lived pending offer to an intentionally
  /// Online driver who is signed out. The server still requires a live session
  /// and fresh GPS before that driver can accept.
  bool get canSubmitRideRequest =>
      isAvailable && isOnline && hasUsableLastLocation;

  /// Means the driver can respond now, not merely receive a persisted offer.
  bool get isBookable =>
      canSubmitRideRequest && hasLiveSession && hasFreshBookableLocation;

  String get availabilityLabel {
    if (!isOnline) return 'Offline';
    if (!hasUsableLastLocation) return 'Location unavailable';
    if (!isAvailable) return 'Busy';
    if (!hasLiveSession) return 'Online · May respond later';
    if (!hasFreshBookableLocation) return 'Online · Last known location';
    return 'Online · Available';
  }

  bool get isLocationStale =>
      locationUpdatedAt != null &&
      DateTime.now().difference(locationUpdatedAt!).abs() >
          NearbyDriverConfig.offlineLocationMaxAge;

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'true', 't', '1', 'yes'}
        .contains(value?.toString().trim().toLowerCase());
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}

class DriverMatchingService {
  static final DriverMatchingService instance = DriverMatchingService._();
  DriverMatchingService._();

  // Calculate distance in kilometers using Haversine formula
  static double calculateDistanceKm(Geo from, Geo to) {
    const r = 6371.0; // Earth radius in km
    final lat1 = from.lat * math.pi / 180;
    final lat2 = to.lat * math.pi / 180;
    final dLat = (to.lat - from.lat) * math.pi / 180;
    final dLng = (to.lng - from.lng) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // Fare Calculation:
  // Tricycle: Base 15 PHP + 5 PHP/km
  // Habal-Habal: Base 20 PHP + 8 PHP/km
  // Fare Calculation using dynamic rates from RideConfig (synced with Firestore / Admin rates)
  double calculateFare({
    required VehicleType vehicleType,
    required double distanceKm,
  }) {
    return RideConfig.fareFor(vehicleType, distanceKm);
  }

  // Estimated Travel Time in minutes
  int calculateTravelTimeMinutes(VehicleType vehicleType, double distanceKm) {
    final speedKmH = vehicleType == VehicleType.tricycle ? 22.0 : 32.0;
    final hours = distanceKm / speedKmH;
    final mins = (hours * 60).round();
    return math.max(3, mins);
  }
}
