import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/driver_profile.dart';
import '../../models/firestore_models.dart';
import '../supabase_database_service.dart';

class SupabaseDriverService {
  SupabaseDriverService._();
  static final SupabaseDriverService instance = SupabaseDriverService._();

  SupabaseClient get _db => Supabase.instance.client;
  SupabaseQueryBuilder get _driversRef => _db.from('drivers');
  SupabaseQueryBuilder get _usersRef => _db.from('profiles');

  // Helpers
  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  AppUser? _appUserFromDriverProfile(Map<String, Object?> data, String userId) {
    final role = (data['role'] ?? 'driver').toString();
    final personalInfo = data['personalInfo'];
    final personalName = personalInfo is Map
        ? (personalInfo['fullName'] ?? personalInfo['full_name'])
        : null;
    final rawName =
        (data['fullName'] ?? data['full_name'] ?? data['name'] ?? personalName)
            ?.toString()
            .trim();
    final name = (rawName != null && rawName.isNotEmpty) ? rawName : 'Driver';
    return AppUser(
      id: userId,
      fullName: name,
      mobile: (data['mobile'] ??
              data['phoneNumber'] ??
              (personalInfo is Map ? personalInfo['mobile'] : null) ??
              '')
          .toString(),
      passwordHash: '',
      role: role,
      status: AccountStatus.approved,
      createdAt: _asDateTime(data['createdAt'] ?? data['created_at']) ??
          DateTime.now(),
      profilePhotoUrl: (data['profilePhotoUrl'] ??
              data['profile_photo_url'] ??
              data['doc_profile'])
          ?.toString(),
      latitude: null,
      longitude: null,
      isOnline: false,
    );
  }

  Future<void> saveDriverLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _usersRef.upsert({
      'id': userId,
      'latitude': latitude,
      'longitude': longitude,
    });

    await _driversRef.upsert({
      'id': userId,
      'userId': userId,
      'currentLocation': {'latitude': latitude, 'longitude': longitude},
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': now,
      'location_updated_at': now,
    });
  }

  Future<void> updateDriverLocation(
      String userId, double latitude, double longitude) async {
    return saveDriverLocation(
        userId: userId, latitude: latitude, longitude: longitude);
  }

  Stream<DriverLiveLocation?> streamDriverLocation(String driverId) {
    return SupabaseDatabaseService.instance.streamDriverLocation(driverId);
  }

  Future<void> setDriverAvailability(String userId, bool isOnline) async {
    final now = DateTime.now().toIso8601String();
    await _usersRef.upsert({
      'id': userId,
      'is_online': isOnline ? 1 : 0,
      'isOnline': isOnline,
      'isAvailable': isOnline,
      'lastSeenAt': now,
    });
    await _driversRef.upsert({
      'id': userId,
      'userId': userId,
      'isOnline': isOnline,
      'isAvailable': isOnline,
      'lastSeenAt': now,
    });
  }

  Future<void> saveDriverProfile(DriverProfile profile) async {
    await SupabaseDatabaseService.instance.saveDriverProfile(profile);
  }

  Future<void> submitDriverApplication({
    required AppUser user,
    required DriverProfile profile,
  }) async {
    throw StateError(
      'Driver applications must use the secure pre-approval endpoint. This method cannot create a Driver profile.',
    );
  }

  Future<void> updateDriverProfile(DriverProfile profile) async {
    try {
      await _driversRef.upsert({
        ...profile.toMap(),
        'id': profile.userId,
        'userId': profile.userId,
        'vehicleType': profile.vehicleType.key,
        'plateNumber': profile.plateNumber,
        'submittedAt': profile.submittedAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('updateDriverProfile error: $e');
    }
  }

  Future<DriverProfile?> getDriverProfile(String userId) async {
    try {
      final snap =
          await _driversRef.select().eq('user_id', userId).maybeSingle();
      if (snap == null) return null;
      return DriverProfile.fromMap(snap);
    } catch (e) {
      return null;
    }
  }

  Future<String?> getDriverVerificationStatus(String userId) async {
    try {
      final snap =
          await _driversRef.select().eq('user_id', userId).maybeSingle();
      if (snap == null) return null;
      return (snap['verificationStatus'] ??
              snap['verification_status'] ??
              snap['status'])
          ?.toString();
    } catch (e) {
      return null;
    }
  }

  Stream<DriverProfile?> streamDriverProfile(String userId) {
    return Stream.fromFuture(getDriverProfile(userId));
  }

  Future<void> setDriverVerificationStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    // If approving or rejecting, call the secure RPC!
    if (status == AccountStatus.approved) {
      await _db.rpc('approve_driver', params: {
        'target_driver': userId,
        'approved': true,
        'rejection_reason': null,
      });
      return;
    } else if (status == AccountStatus.rejected) {
      await _db.rpc('approve_driver', params: {
        'target_driver': userId,
        'approved': false,
        'rejection_reason': reason,
      });
      return;
    }

    // For other statuses (like suspended), just update application_status if Admin
    // Using a direct update since upserting firebase fields will crash PostgREST.
    await _db.from('drivers').update({
      'application_status': status,
    }).eq('user_id', userId);
  }

  Future<void> approveDriver(String driverId) async {
    await setDriverVerificationStatus(driverId, AccountStatus.approved);
  }

  Future<void> rejectDriver(String driverId, {String? reason}) async {
    await setDriverVerificationStatus(driverId, AccountStatus.rejected,
        reason: reason);
  }

  Future<void> suspendDriver(String driverId) async {
    await setDriverVerificationStatus(driverId, AccountStatus.suspended);
  }

  Future<void> reactivateDriver(String driverId) async {
    await setDriverVerificationStatus(driverId, AccountStatus.approved);
  }

  Stream<List<AppUser>> streamDrivers({String? status}) {
    return SupabaseDatabaseService.instance.streamDrivers(status: status);
  }

  Stream<List<AppUser>> streamPendingDrivers() =>
      streamDrivers(status: AccountStatus.pending);

  Stream<List<DriverApplication>> streamPendingDriverApplications() {
    return SupabaseDatabaseService.instance.streamPendingDriverApplications();
  }

  Stream<List<AppUser>> streamNearbyDrivers({
    double? lat,
    double? lng,
    double radiusKm = 5,
  }) {
    return Stream.fromFuture(_driversRef.select().then((snapshot) async {
      final drivers = <AppUser>[];
      for (final doc in snapshot) {
        final appStatus = (doc['applicationStatus'] ??
                doc['verificationStatus'] ??
                doc['verification_status'])
            ?.toString()
            .toLowerCase()
            .trim();
        final accStatus = doc['status']?.toString().toLowerCase().trim();
        final drvStatus = (doc['driverStatus'] ?? doc['driver_status'])
            ?.toString()
            .toLowerCase()
            .trim();

        final isSuspended = doc['isSuspended'] == true ||
            doc['is_suspended'] == 1 ||
            accStatus == 'suspended' ||
            drvStatus == 'suspended';

        final isPending = appStatus == 'pending' ||
            accStatus == 'pending' ||
            drvStatus == 'pending';

        final isRejected = appStatus == 'rejected' ||
            accStatus == 'rejected' ||
            drvStatus == 'rejected';

        final isApproved = !isPending &&
            !isRejected &&
            (doc['isApproved'] == true ||
                doc['is_approved'] == 1 ||
                appStatus == 'approved' ||
                accStatus == 'approved' ||
                accStatus == 'active' ||
                drvStatus == 'approved' ||
                drvStatus == 'active');

        if (!isApproved || isSuspended) {
          continue;
        }

        final point = doc['currentLocation'];
        final driverLat = point is Map
            ? (point['latitude'] as num?)?.toDouble()
            : (doc['latitude'] as num?)?.toDouble();
        final driverLng = point is Map
            ? (point['longitude'] as num?)?.toDouble()
            : (doc['longitude'] as num?)?.toDouble();

        if (driverLat == null || driverLng == null) {
          continue;
        }

        final distanceKm = (lat != null && lng != null)
            ? Geo.distanceKm(Geo(lat, lng), Geo(driverLat, driverLng))
            : 0.0;

        if (lat != null && lng != null && distanceKm > radiusKm) {
          continue;
        }

        final userId = doc['id'] as String;
        AppUser? user;
        try {
          final userSnap =
              await _usersRef.select().eq('id', userId).maybeSingle();
          if (userSnap != null) {
            user = AppUser.fromMap(userSnap);
          }
        } catch (e) {
          debugPrint('DriverService non-fatal note: $e');
        }

        final resolvedUser = user ?? _appUserFromDriverProfile(doc, userId);
        if (resolvedUser != null) {
          final isOnline = doc['isOnline'] == true || doc['is_online'] == 1;
          final isAvailable = doc['isAvailable'] != false;
          final isVisibleOnline = isOnline && isAvailable;

          drivers.add(resolvedUser.copyWith(
            latitude: driverLat,
            longitude: driverLng,
            isOnline: isVisibleOnline,
            locationUpdatedAt: _asDateTime(doc['locationUpdatedAt'] ??
                doc['location_updated_at'] ??
                doc['updatedAt']),
            status: 'approved',
          ));
        }
      }
      return drivers;
    }));
  }

  Future<bool> isDriverBookable(String driverId) async {
    final result = await _db.rpc('is_driver_bookable', params: {
      'target_driver': driverId,
    });
    return result == true;
  }

  Future<void> incrementDriverStats(
    String userId, {
    int trips = 0,
    double earnings = 0,
  }) async {
    try {
      await _db.rpc('increment_driver_stats', params: {
        'driver_id': userId,
        'trips_increment': trips,
        'earnings_increment': earnings,
      });
      // Assuming a custom RPC exists, otherwise we'd need to do a transaction
    } catch (e) {
      debugPrint('incrementDriverStats error: $e');
    }
  }

  Future<void> recalculateDriverRating(String userId) async {
    try {
      final snap = await _db
          .from('ratings')
          .select('stars, rating')
          .eq('toUserId', userId);
      if (snap.isEmpty) return;

      var sum = 0.0;
      for (final doc in snap) {
        sum += (doc['stars'] as num?)?.toDouble() ??
            (doc['rating'] as num?)?.toDouble() ??
            5.0;
      }
      final average = sum / snap.length;

      await _driversRef.upsert({
        'id': userId,
        'rating': average,
        'ratingCount': snap.length,
      });
      await _usersRef.upsert({
        'id': userId,
        'rating': average,
        'rating_count': snap.length,
        'ratingCount': snap.length,
      });
    } catch (e) {
      debugPrint('recalculateDriverRating error: $e');
    }
  }
}
