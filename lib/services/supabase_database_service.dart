import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../core/supabase_config.dart';
import '../models/admin_account.dart';
import '../models/app_user.dart';
import '../models/driver_application_rules.dart';
import 'driver_matching_service.dart';
import '../models/driver_profile.dart';
import '../models/firestore_models.dart';
import '../models/philippine_address.dart';
import '../models/report_model.dart';
import '../models/saved_place.dart';
import '../models/transaction.dart';
import '../models/trip.dart';
import 'driver_earnings_summary.dart';
import 'database_service.dart';
import 'supabase/realtime_query.dart';

/// Production PostgreSQL/Realtime gateway for all Sakay Ta clients.
class SupabaseDatabaseService {
  SupabaseDatabaseService._() : _testClient = null;
  @visibleForTesting
  SupabaseDatabaseService.test(this._testClient);
  static final SupabaseDatabaseService instance = SupabaseDatabaseService._();
  static const _uuid = Uuid();

  final SupabaseClient? _testClient;
  SupabaseClient get _client => _testClient ?? Supabase.instance.client;

  static const _rideWithRatingSelect =
      '*,ratings(id,ride_id,passenger_id,driver_id,rating,comment,created_at)';

  static bool get isConfigured {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (!isConfigured) {
      throw StateError('Supabase is not initialized.');
    }
  }

  Future<T> _adminRead<T>(
    String section,
    String query,
    Future<T> Function() operation,
  ) async {
    final startTime = DateTime.now();
    debugPrint('\\n--- ADMIN OVERVIEW QUERY START ---');
    debugPrint('Widget: $section');
    debugPrint('Query/table/RPC: $query');
    final user = _client.auth.currentUser;
    debugPrint('Authenticated: ${user != null}');
    debugPrint('Admin UID: ${user?.id ?? 'none'}');
    final projectHost =
        Uri.tryParse(SupabaseConfig.projectUrl)?.host ?? 'unavailable';
    debugPrint('Supabase project: $projectHost');
    debugPrint('Role/session: ${user?.role ?? 'unknown'}');

    try {
      final result = await operation();
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('Query result: success');
      debugPrint('Duration: ${duration}ms');
      debugPrint('--- ADMIN OVERVIEW QUERY END ---\\n');
      return result;
    } on PostgrestException catch (error) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('HTTP/status code: ${error.code}');
      debugPrint('Postgres/Supabase code: ${error.code}');
      debugPrint('Error message: ${error.message}');
      debugPrint('Error details: ${error.details}');
      debugPrint('Error hint: ${error.hint}');
      debugPrint('Query result: failure');
      debugPrint('Duration: ${duration}ms');
      debugPrint('--- ADMIN OVERVIEW QUERY END ---\\n');
      rethrow;
    } catch (error) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('Error message: $error');
      debugPrint('Query result: failure');
      debugPrint('Duration: ${duration}ms');
      debugPrint('--- ADMIN OVERVIEW QUERY END ---\\n');
      rethrow;
    }
  }

  Future<int> adminTotalRidesOnce() => _adminRead(
        'total_rides',
        'rides exact count',
        () async => await _client.from('rides').count(CountOption.exact),
      );

  Future<int> adminActiveRidesOnce() => _adminRead(
        'active_rides',
        'rides active count',
        () async => await _client
            .from('rides')
            .count(CountOption.exact)
            .inFilter('status',
                const ['searching', 'accepted', 'arrived', 'started']),
      );

  Future<int> adminCompletedRidesOnce() => _adminRead(
        'completed_rides',
        'rides completed count',
        () async => await _client
            .from('rides')
            .count(CountOption.exact)
            .eq('status', 'completed'),
      );

  Future<int> adminCancelledRidesOnce() => _adminRead(
        'cancelled_rides',
        'rides cancelled count',
        () async => await _client
            .from('rides')
            .count(CountOption.exact)
            .eq('status', 'cancelled'),
      );

  Stream<int> streamAdminTotalRides() => realtimeQueryStream<int>(
        client: _client,
        feature: 'admin_total_rides',
        table: 'rides',
        filterDescription: 'all ride changes',
        fetch: adminTotalRidesOnce,
      );

  Stream<int> streamAdminActiveRides() => realtimeQueryStream<int>(
        client: _client,
        feature: 'admin_active_rides',
        table: 'rides',
        filterDescription: 'all ride changes',
        fetch: adminActiveRidesOnce,
      );

  Stream<int> streamAdminCompletedRides() => realtimeQueryStream<int>(
        client: _client,
        feature: 'admin_completed_rides',
        table: 'rides',
        filterDescription: 'all ride changes',
        fetch: adminCompletedRidesOnce,
      );

  Stream<int> streamAdminCancelledRides() => realtimeQueryStream<int>(
        client: _client,
        feature: 'admin_cancelled_rides',
        table: 'rides',
        filterDescription: 'all ride changes',
        fetch: adminCancelledRidesOnce,
      );

  Future<int> adminTotalDriversOnce() => _adminRead(
        'total_drivers',
        'drivers exact count',
        () async => await _client.from('drivers').count(CountOption.exact),
      );

  Future<int> adminTotalPassengersOnce() => _adminRead(
        'total_passengers',
        'passenger_profiles.user_id -> profiles.id canonical passenger count',
        () async => (await streamPassengers().first).length,
      );

  Future<int> adminActiveDriversOnce() => _adminRead(
        'active_drivers',
        'driver_presence is_online=true count',
        () async => await _client
            .from('driver_presence')
            .count(CountOption.exact)
            .eq('is_online', true),
      );

  Future<double> adminRevenueTodayOnce() => _adminRead(
        'revenue_today',
        'completed ride gross fares today',
        () async {
          // The platform operates in the Philippines; an administrator's
          // browser timezone must not change the definition of "today".
          final manilaNow =
              DateTime.now().toUtc().add(const Duration(hours: 8));
          final todayStartUtc =
              DateTime.utc(manilaNow.year, manilaNow.month, manilaNow.day)
                  .subtract(const Duration(hours: 8));
          final tomorrowStartUtc = todayStartUtc.add(const Duration(days: 1));
          final earnings = await _client
              .from('rides')
              .select('fare,driver_id')
              .eq('status', 'completed')
              .gte('completed_at', todayStartUtc.toIso8601String())
              .lt('completed_at', tomorrowStartUtc.toIso8601String());
          return earnings.fold<double>(0, (sum, row) {
            if (row['driver_id'] == null) return sum;
            final value = row['fare'];
            if (value is num) return sum + value.toDouble();
            return sum + (double.tryParse(value?.toString() ?? '') ?? 0);
          });
        },
      );

  Future<bool> adminHealthOnce() => _adminRead(
        'platform_status',
        'admin_dashboard_authorization() RPC',
        () async {
          final rows = await _client.rpc('admin_dashboard_authorization');
          if (rows is! List || rows.isEmpty) {
            throw const AuthException('Administrator authorization failed.');
          }
          return true;
        },
      );

  static Future<void> ensureCurrentAdminAuthorized(
      [String? explicitUid]) async {
    if (!isConfigured) return;
    final client = Supabase.instance.client;
    final uid = explicitUid ?? client.auth.currentUser?.id;
    if (uid == null) return;
    final role = await client
        .from('admin_roles')
        .select('status')
        .eq('user_id', uid)
        .maybeSingle();
    if (role == null || role['status'] != 'active') {
      throw const AuthException('Administrator authorization required.');
    }
  }

  Map<String, dynamic>? _one(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _millis(Object? value) => _date(value)?.millisecondsSinceEpoch ?? 0;

  @visibleForTesting
  static final Map<String, ({String url, DateTime expiresAt})>
      driverPhotoUrlCache = {};

  Future<String> resolveDriverPhotoUrl(String? rawPath) async {
    final trimmed = rawPath?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    var cleanPath = trimmed;
    if (cleanPath.startsWith('avatars/')) {
      cleanPath = cleanPath.substring('avatars/'.length);
    }
    final isDriverDocs = cleanPath.startsWith('driver-documents/') ||
        cleanPath.startsWith('applications/') ||
        cleanPath.contains('/profile/') ||
        cleanPath.contains('profile_');
    if (cleanPath.startsWith('driver-documents/')) {
      cleanPath = cleanPath.substring('driver-documents/'.length);
    }

    if (isDriverDocs) {
      final cached = driverPhotoUrlCache[cleanPath];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        return cached.url;
      }
      try {
        final signed = await _client.storage
            .from('driver-documents')
            .createSignedUrl(cleanPath, 3600);
        driverPhotoUrlCache[cleanPath] = (
          url: signed,
          expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        );
        return signed;
      } catch (error) {
        debugPrint(
            '[SakayTa][Storage] createSignedUrl fallback for $cleanPath: $error');
        return _client.storage.from('driver-documents').getPublicUrl(cleanPath);
      }
    }

    return _client.storage.from('avatars').getPublicUrl(cleanPath);
  }

  String? _avatarUrl(Object? path, [Object? updatedAt]) {
    final value = path?.toString().trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    var cleanPath = value;
    if (cleanPath.startsWith('driver-documents/') ||
        cleanPath.startsWith('applications/')) {
      if (cleanPath.startsWith('driver-documents/')) {
        cleanPath = cleanPath.substring('driver-documents/'.length);
      }
      final cached = driverPhotoUrlCache[cleanPath];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        return cached.url;
      }
    }
    if (cleanPath.startsWith('avatars/')) {
      cleanPath = cleanPath.substring('avatars/'.length);
    }
    String url = _client.storage.from('avatars').getPublicUrl(cleanPath);
    if (updatedAt != null) {
      final ms = _millis(updatedAt);
      if (ms > 0) {
        url += '?v=$ms';
      }
    }
    return url;
  }

  AppUser _appUser(Map<String, dynamic> row) {
    final driver = _one(row['drivers']);
    final admin = _one(row['admin_roles']);
    final role = admin != null
        ? (admin['role']?.toString() ?? UserRole.admin)
        : driver != null
            ? UserRole.driver
            : UserRole.passenger;
    final status = driver?['application_status']?.toString() ??
        admin?['status']?.toString() ??
        row['account_status']?.toString() ??
        AccountStatus.active;
    return AppUser.fromMap({
      ...row,
      'id': row['id']?.toString() ?? '',
      'role': role,
      'status': status,
      'is_online': driver?['is_online'] ?? false,
      'rating_average': driver?['rating_average'],
      'rating_count': driver?['rating_count'] ?? 0,
      'acceptance_count': driver?['acceptance_count'] ?? 0,
      'acceptance_total': driver?['acceptance_total'] ?? 0,
      'on_time_count': driver?['on_time_count'] ?? 0,
      'total_trips': driver?['total_trips'] ?? 0,
      'lifetime_earnings': driver?['lifetime_earnings'] ?? 0,
      'rejection_reason': driver?['rejection_reason'],
      'latitude': driver?['current_latitude'] ?? row['latitude'],
      'longitude': driver?['current_longitude'] ?? row['longitude'],
      'location_updated_at':
          driver?['last_location_at'] ?? row['location_updated_at'],
      'profile_photo_url':
          _avatarUrl(row['profile_photo_path'], row['updated_at']),
    });
  }

  Future<AppUser?> _userWhere(String column, Object value) async {
    final row = await _client
        .from('profiles')
        .select(
            '*,drivers:drivers!drivers_user_id_fkey(*),admin_roles:admin_roles!admin_roles_user_id_fkey(*)')
        .eq(column, value)
        .maybeSingle();
    return row == null ? null : _appUser(Map<String, dynamic>.from(row));
  }

  Future<List<AppUser>> _usersForIds(Iterable<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select(
            '*,drivers:drivers!drivers_user_id_fkey(*),admin_roles:admin_roles!admin_roles_user_id_fkey(*)')
        .inFilter('id', unique);
    return rows.map((row) => _appUser(Map<String, dynamic>.from(row))).toList();
  }

  /// Resolves the passenger management list from the canonical two-table
  /// contract: `passenger_profiles.user_id` identifies the capability and
  /// `profiles.id` owns the identity fields visible to administrators.
  ///
  /// Admin and driver capability rows are deliberately excluded. Earlier
  /// versions of the Auth trigger created a passenger row for every account,
  /// so treating a bare profile as a passenger could show staff or drivers in
  /// this screen. Existing ambiguous rows are left untouched and reported in
  /// development logs for a manual data review.
  Future<List<AppUser>> _passengerUsersForIds(Iterable<String> ids) async {
    final candidateIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (candidateIds.isEmpty) return const [];

    // Keep IN filters below typical proxy URL limits. The source table is
    // paged separately by streamPassengers so neither read silently stops at
    // PostgREST's default row limit.
    if (candidateIds.length > 100) {
      final passengers = <AppUser>[];
      for (var start = 0; start < candidateIds.length; start += 100) {
        final end = start + 100 < candidateIds.length
            ? start + 100
            : candidateIds.length;
        passengers.addAll(
            await _passengerUsersForIds(candidateIds.sublist(start, end)));
      }
      passengers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return passengers;
    }

    final excluded = <String>{};
    final capabilityReads = await Future.wait([
      _client
          .from('drivers')
          .select('user_id')
          .inFilter('user_id', candidateIds),
      _client
          .from('admin_roles')
          .select('user_id')
          .inFilter('user_id', candidateIds),
    ]);
    for (final rows in capabilityReads) {
      for (final row in rows) {
        final id = row['user_id']?.toString();
        if (id != null && id.isNotEmpty) excluded.add(id);
      }
    }

    final passengerIds =
        candidateIds.where((id) => !excluded.contains(id)).toList();
    if (passengerIds.isEmpty) return const [];

    final rows = await _client
        .from('profiles')
        .select(
            'id,full_name,email,mobile,email_verified,account_status,address,'
            'profile_photo_path,avatar_color,created_at,updated_at')
        .inFilter('id', passengerIds);
    final foundIds = <String>{};
    final passengers = <AppUser>[];
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow);
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        debugPrint('[PASSENGER CONTRACT] ignoring profile with an empty id');
        continue;
      }
      foundIds.add(id);
      try {
        passengers.add(AppUser.fromMap({
          ...row,
          'role': UserRole.passenger,
          'status': row['account_status']?.toString() ?? AccountStatus.active,
          'profile_photo_url':
              _avatarUrl(row['profile_photo_path'], row['updated_at']),
        }));
      } catch (error, stackTrace) {
        // One legacy row must never make the entire administrative list fail.
        debugPrint(
            '[PASSENGER CONTRACT] malformed profile id=$id error=$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final orphanIds =
        passengerIds.where((id) => !foundIds.contains(id)).toList();
    if (orphanIds.isNotEmpty) {
      debugPrint('[PASSENGER CONTRACT] passenger_profiles without profiles: '
          '${orphanIds.join(',')}');
    }
    passengers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return passengers;
  }

  Map<String, dynamic> _profileRow(AppUser user) => {
        'full_name': user.fullName,
        'mobile': user.mobile.trim().isEmpty ? null : user.mobile.trim(),
        // Supabase Auth's trigger owns the mirrored email and verification
        // fields. Sending either in a profile upsert would permit identity
        // drift or require privileges the signed-in user must not have.
        'address': user.address,
        'latitude': user.latitude,
        'longitude': user.longitude,
        'location_updated_at':
            user.locationUpdatedAt?.toUtc().toIso8601String(),
        'avatar_color': user.avatarColor,
      };

  Future<void> saveUser(AppUser user) async {
    // Auth's trigger owns creation and the mirrored email. An upsert sends
    // the primary key through ON CONFLICT UPDATE, which is incompatible with
    // the column-limited profile UPDATE grant and can obscure a missing row.
    await _client
        .from('profiles')
        .update(_profileRow(user))
        .eq('id', user.id)
        .select('id')
        .single();
  }

  Future<void> updateUser(String userId, Map<String, Object?> fields) async {
    const aliases = <String, String>{
      'fullName': 'full_name',
      'phoneNumber': 'mobile',
      'emailVerified': 'email_verified',
      'profilePhotoUrl': 'profile_photo_path',
      'avatarColor': 'avatar_color',
      'locationUpdatedAt': 'location_updated_at',
    };
    const allowed = {
      'full_name',
      'mobile',
      'address',
      'latitude',
      'longitude',
      'location_updated_at',
      'profile_photo_path',
      'avatar_color',
    };
    final updates = <String, Object?>{};
    for (final entry in fields.entries) {
      final key = aliases[entry.key] ?? entry.key;
      if (!allowed.contains(key)) continue;
      updates[key] = _databaseValue(entry.value);
    }
    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', userId);
    }
  }

  Stream<AppUser?> streamUser(String userId) => realtimeQueryStream<AppUser?>(
        client: _client,
        feature: 'user_profile',
        table: 'profiles',
        filterDescription: 'id=$userId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
        ],
        fetch: () => getUser(userId),
      );

  Future<AppUser?> getUser(String userId) => _userWhere('id', userId);
  Future<AppUser?> getUserByEmail(String email) =>
      _userWhere('email', email.trim().toLowerCase());
  Future<AppUser?> getUserByMobile(String mobile) =>
      _userWhere('mobile', mobile.trim());

  Future<void> deleteUser(String userId) async {
    final response = await _client.functions.invoke(
      'admin-users',
      body: {'action': 'delete', 'userId': userId},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Unable to delete the account securely.');
    }
  }

  Future<List<Trip>> getPassengerTrips(String passengerId) async {
    final rows = await _client
        .from('rides')
        .select()
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false);
    return rows.map((row) => _trip(Map<String, dynamic>.from(row))).toList();
  }

  /// Driver records include private licence and vehicle information, so they
  /// deliberately do not participate in the public Realtime publication.
  /// Admin lists refresh through an authenticated query instead.
  Stream<List<AppUser>> streamDrivers({String? status}) =>
      Stream.fromFuture(() async {
        return _adminRead(
          'drivers',
          'drivers.user_id with profiles via explicit ownership keys',
          () async {
            final rows = status == null
                ? await _client.from('drivers').select('user_id')
                : await _client
                    .from('drivers')
                    .select('user_id')
                    .eq('application_status', status);
            return _usersForIds(rows.map((row) => row['user_id'].toString()));
          },
        );
      }());

  Stream<List<AppUser>> streamPendingDrivers() =>
      streamDrivers(status: AccountStatus.pending);

  Stream<List<DriverApplication>> streamPendingDriverApplications(
          {int? limit}) =>
      Stream.fromFuture(_pendingDriverApplicationsOnce(limit: limit));

  Future<List<DriverApplication>> _pendingDriverApplicationsOnce(
          {int? limit}) =>
      _adminRead(
        'pending_registrations',
        'drivers.application_status=pending -> profiles.id',
        () async {
          const pageSize = 500;
          final driverRows = <Map<String, dynamic>>[];
          for (var offset = 0;; offset += pageSize) {
            final fetchSize = limit != null && (limit - offset) < pageSize
                ? limit - offset
                : pageSize;
            if (fetchSize <= 0) break;

            final page = await _client
                .from('drivers')
                .select()
                .eq('application_status', AccountStatus.pending)
                .order('submitted_at', ascending: false)
                .order('user_id')
                .range(offset, offset + fetchSize - 1);
            driverRows
                .addAll(page.map((row) => Map<String, dynamic>.from(row)));
            if (page.length < fetchSize ||
                (limit != null && driverRows.length >= limit)) {
              break;
            }
          }
          if (driverRows.isEmpty) {
            return _fetchSecurePendingDriverApplications();
          }

          final profilesById = <String, Map<String, dynamic>>{};
          for (var start = 0; start < driverRows.length; start += 100) {
            final batch = driverRows.skip(start).take(100).toList();
            final profiles = await _client.from('profiles').select().inFilter(
                'id', batch.map((row) => row['user_id'].toString()).toList());
            for (final profile in profiles) {
              profilesById[profile['id'].toString()] =
                  Map<String, dynamic>.from(profile);
            }
          }

          final todaNamesById = <String, String>{};
          final todaIds = driverRows
              .map((row) => row['toda_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          for (var start = 0; start < todaIds.length; start += 100) {
            final todas = await _client
                .from('todas')
                .select('id,name')
                .inFilter('id', todaIds.skip(start).take(100).toList());
            for (final toda in todas) {
              todaNamesById[toda['id'].toString()] =
                  toda['name']?.toString() ?? '';
            }
          }

          final legacyApplications = driverRows.map((driverRow) {
            final userId = driverRow['user_id'].toString();
            final profileRow = profilesById[userId];
            if (profileRow == null) {
              throw StateError('Missing profile for pending driver $userId.');
            }
            return DriverApplication(
              user: _appUser({...profileRow, 'drivers': driverRow}),
              profile: DriverProfile.fromMap({
                ...driverRow,
                'dob': driverRow['date_of_birth'],
                'address': profileRow['address'],
                'make': driverRow['vehicle_make'],
                'model': driverRow['vehicle_model'],
                'year': driverRow['vehicle_year'],
                'color': driverRow['vehicle_color'],
                'toda_name': todaNamesById[driverRow['toda_id']?.toString()],
              }),
              verificationStatus: driverRow['application_status'].toString(),
            );
          }).toList();
          final secureApplications =
              await _fetchSecurePendingDriverApplications();
          return [...legacyApplications, ...secureApplications]
            ..sort((left, right) =>
                right.profile.submittedAt.compareTo(left.profile.submittedAt));
        },
      );

  Future<List<DriverApplication>> _fetchSecurePendingDriverApplications() =>
      _fetchSecureDriverApplications(status: 'pending');

  Future<List<DriverApplication>> fetchRejectedDriverApplications() =>
      _adminRead(
        'rejected_driver_applications',
        'drivers.application_status=rejected plus private driver_applications history',
        () async {
          final driverRows = await _client
              .from('drivers')
              .select()
              .eq('application_status', AccountStatus.rejected)
              .isFilter('history_cleared_at', null)
              .order('submitted_at', ascending: false)
              .limit(500);
          final secureApplications =
              await _fetchSecureDriverApplications(status: 'rejected');
          if (driverRows.isEmpty) return secureApplications;

          final driverMaps =
              driverRows.map((row) => Map<String, dynamic>.from(row)).toList();
          final userIds = driverMaps
              .map((row) => row['user_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          final reviewerIds = driverMaps
              .map((row) => row['reviewed_by']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          final allProfileIds = {...userIds, ...reviewerIds}.toList();
          final profiles = allProfileIds.isEmpty
              ? <Map<String, dynamic>>[]
              : (await _client.from('profiles').select().inFilter('id', allProfileIds))
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
          final profilesById = {
            for (final profile in profiles) profile['id'].toString(): profile,
          };
          final legacyApplications = driverMaps.map((driverRow) {
            final userId = driverRow['user_id']?.toString() ?? '';
            final profileRow = profilesById[userId];
            if (profileRow == null) {
              throw StateError('Missing profile for rejected driver $userId.');
            }
            final reviewerId = driverRow['reviewed_by']?.toString();
            final reviewerProfile =
                reviewerId != null ? profilesById[reviewerId] : null;
            return DriverApplication(
              user: _appUser({...profileRow, 'drivers': driverRow}),
              profile: DriverProfile.fromMap({
                ...driverRow,
                'dob': driverRow['date_of_birth'],
                'address': profileRow['address'],
                'make': driverRow['vehicle_make'],
                'model': driverRow['vehicle_model'],
                'year': driverRow['vehicle_year'],
                'color': driverRow['vehicle_color'],
              }),
              verificationStatus: AccountStatus.rejected,
              reviewedAt: DateTime.tryParse(
                driverRow['reviewed_at']?.toString() ?? '',
              ),
              reviewedBy: reviewerId,
              reviewerName: reviewerProfile?['full_name']?.toString(),
            );
          }).toList();
          return [...legacyApplications, ...secureApplications]
            ..sort((left, right) =>
                right.profile.submittedAt.compareTo(left.profile.submittedAt));
        },
      );

  Future<List<DriverApplication>> _fetchSecureDriverApplications({
    required String status,
  }) async {
    final data = await _invokeDriverApplications({
      'action': 'list',
      'status': status,
    });
    if (data is! List) {
      throw StateError('The Admin application list response was invalid.');
    }
    return data.map((value) {
      if (value is! Map) {
        throw StateError('An Admin application row was invalid.');
      }
      final row = Map<String, dynamic>.from(value);
      final applicationId = row['id']?.toString() ?? '';
      if (applicationId.isEmpty) {
        throw StateError('An application ID is missing.');
      }
      final submittedAt = row['submitted_at'];
      final user = AppUser.fromMap({
        'id': applicationId,
        'full_name': row['full_name'],
        'email': row['email'],
        'mobile': row['mobile'],
        'address': row['address'],
        'role': UserRole.driver,
        'status': status == 'rejected'
            ? AccountStatus.rejected
            : AccountStatus.pending,
        'password_hash': '',
        'rejection_reason': row['rejection_reason'],
        'created_at': submittedAt,
        'email_verified': false,
      });
      final profile = DriverProfile.fromMap({
        ...row,
        'user_id': applicationId,
        'dob': row['date_of_birth'],
        'make': row['vehicle_make'],
        'model': row['vehicle_model'],
        'year': row['vehicle_year'],
        'color': row['vehicle_color'],
      });
      return DriverApplication(
        user: user,
        profile: profile,
        verificationStatus: row['status']?.toString() ?? status,
        applicationId: applicationId,
        reviewedAt: DateTime.tryParse(row['reviewed_at']?.toString() ?? ''),
        notificationStatus:
            row['applicant_notification_status']?.toString() ?? 'not_sent',
        reviewedBy: row['reviewed_by']?.toString(),
        reviewerName: row['reviewer_name']?.toString(),
      );
    }).toList();
  }

  Stream<List<AppUser>> streamPassengers() => Stream.fromFuture(() async {
        return _adminRead(
          'passengers',
          'passenger_profiles.user_id -> profiles.id canonical passenger contract',
          () async {
            const pageSize = 500;
            final ids = <String>[];
            for (var offset = 0;; offset += pageSize) {
              final rows = await _client
                  .from('passenger_profiles')
                  .select('user_id')
                  .order('user_id')
                  .range(offset, offset + pageSize - 1);
              ids.addAll(rows.map((row) => row['user_id']?.toString() ?? ''));
              if (rows.length < pageSize) break;
            }
            return _passengerUsersForIds(ids);
          },
        );
      }());

  Stream<List<NearbyDriver>> streamNearbyDrivers({
    double? lat,
    double? lng,
    double radiusKm = 5,
    VehicleType? vehicleType,
  }) {
    if (lat == null || lng == null) {
      return Stream.error(ArgumentError('Passenger coordinates are required.'));
    }

    return realtimeQueryStream<List<NearbyDriver>>(
      client: _client,
      feature: 'nearby_drivers',
      table: 'driver_presence',
      throttle: const Duration(seconds: 3),
      pollInterval: const Duration(seconds: 8),
      filterDescription:
          'approved presence changes; vehicle=${vehicleType?.key ?? 'any'}',
      fetch: () => _fetchNearbyDrivers(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        vehicleType: vehicleType,
        source: 'authoritative',
      ),
    );
  }

  Future<List<NearbyDriver>> _fetchNearbyDrivers({
    required double lat,
    required double lng,
    required double radiusKm,
    required VehicleType? vehicleType,
    required String source,
  }) async {
    debugPrint('[SakayTa][NearbyDrivers][query] source=$source '
        'origin=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)} '
        'radiusKm=${radiusKm.toStringAsFixed(1)} '
        'vehicle=${vehicleType?.key ?? 'any'}');
    dynamic result;
    try {
      result = await _client.rpc('nearby_drivers', params: {
        'passenger_latitude': lat,
        'passenger_longitude': lng,
        'requested_vehicle': vehicleType?.key,
        'radius_km': radiusKm,
      });
    } on PostgrestException catch (e, s) {
      if (e.code == 'PGRST202' ||
          e.code == '42883' ||
          e.message.toLowerCase().contains('nearby_drivers')) {
        AppLogger.warn(
          'SupabaseDatabaseService: nearby_drivers RPC missing (${e.code}); falling back to direct driver_presence query.',
          error: e,
          stackTrace: s,
        );
        return _fetchNearbyDriversDirectFallback(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          vehicleType: vehicleType,
        );
      }
      rethrow;
    }
    final rawRows = result is List ? result : const <dynamic>[];
    final drivers = <NearbyDriver>[];
    var invalidRows = 0;
    for (final rawRow in rawRows) {
      try {
        final row = Map<String, dynamic>.from(rawRow as Map);
        var rawPhoto = row['profile_photo_path']?.toString().trim();
        if (rawPhoto == null || rawPhoto.isEmpty) {
          final driverId = row['user_id']?.toString() ?? '';
          if (driverId.isNotEmpty) {
            rawPhoto = '$driverId/profile.jpg';
          }
        }
        final photoUrl = await resolveDriverPhotoUrl(rawPhoto);
        row['profile_photo_path'] = photoUrl;
        drivers.add(NearbyDriver.fromRpcMap(row));
      } catch (error) {
        invalidRows++;
        debugPrint('[SakayTa][NearbyDrivers][invalid-row] $error');
      }
    }

    // Resilient fallback: If RPC result did not include completed_trips (e.g. older RPC deployment),
    // batch fetch completed trip count from public.rides.
    if (drivers.isNotEmpty &&
        rawRows.isNotEmpty &&
        rawRows.first is Map &&
        !(rawRows.first as Map).containsKey('completed_trips')) {
      final driverIds = drivers
          .map((d) => d.id)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (driverIds.isNotEmpty) {
        try {
          final ridesResult = await _client
              .from('rides')
              .select('driver_id')
              .inFilter('driver_id', driverIds)
              .eq('status', 'completed');
          final counts = <String, int>{};
          for (final r in ridesResult) {
            final dId = r['driver_id']?.toString();
            if (dId != null && dId.isNotEmpty) {
              counts[dId] = (counts[dId] ?? 0) + 1;
            }
          }
          for (var i = 0; i < drivers.length; i++) {
            final count = counts[drivers[i].id] ?? 0;
            drivers[i] = drivers[i].copyWith(completedTrips: count);
          }
        } catch (e) {
          debugPrint(
              '[SakayTa][NearbyDrivers][completed_trips_fallback] error: $e');
        }
      }
    }

    drivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final online = drivers.where((driver) => driver.isOnline).length;
    final available = drivers.where((driver) => driver.isAvailable).length;
    final bookable = drivers.where((driver) => driver.isBookable).length;
    debugPrint('[SakayTa][NearbyDrivers][result] source=$source '
        'rpcRows=${rawRows.length} parsed=${drivers.length} '
        'invalid=$invalidRows online=$online available=$available '
        'bookable=$bookable');
    return drivers;
  }

  Future<List<NearbyDriver>> _fetchNearbyDriversDirectFallback({
    required double lat,
    required double lng,
    required double radiusKm,
    required VehicleType? vehicleType,
  }) async {
    try {
      final rows = await _client
          .from('driver_presence')
          .select(
            'driver_id, is_online, is_available, latitude, longitude, updated_at, '
            'drivers!inner(vehicle_type, plate_number, rating_average, rating_count, total_trips, application_status), '
            'profiles!inner(full_name, avatar_path)',
          )
          .eq('drivers.application_status', 'approved');

      final origin = Geo(lat, lng);
      final drivers = <NearbyDriver>[];
      for (final raw in rows) {
        try {
          final row = Map<String, dynamic>.from(raw as Map);
          final dMap = row['drivers'] is Map
              ? Map<String, dynamic>.from(row['drivers'] as Map)
              : <String, dynamic>{};
          final pMap = row['profiles'] is Map
              ? Map<String, dynamic>.from(row['profiles'] as Map)
              : <String, dynamic>{};
          final dLat = (row['latitude'] as num?)?.toDouble();
          final dLng = (row['longitude'] as num?)?.toDouble();
          if (dLat == null || dLng == null) continue;
          final distKm = Geo.distanceKm(origin, Geo(dLat, dLng));
          if (distKm > radiusKm) continue;
          final vTypeStr = dMap['vehicle_type']?.toString() ?? '';
          if (vehicleType != null &&
              vTypeStr.toLowerCase() != vehicleType.key.toLowerCase()) {
            continue;
          }
          final driverId = row['driver_id']?.toString() ?? '';
          final rawPhoto =
              pMap['avatar_path']?.toString() ?? '$driverId/profile.jpg';
          final photoUrl = await resolveDriverPhotoUrl(rawPhoto);
          drivers.add(
            NearbyDriver.fromRpcMap({
              'user_id': driverId,
              'full_name': pMap['full_name']?.toString() ?? 'Driver',
              'profile_photo_path': photoUrl,
              'vehicle_type': vTypeStr,
              'plate_number': dMap['plate_number']?.toString() ?? '',
              'rating_average': dMap['rating_average'] ?? 0.0,
              'rating_count': dMap['rating_count'] ?? 0,
              'completed_trips': dMap['total_trips'] ?? 0,
              'latitude': dLat,
              'longitude': dLng,
              'distance_km': distKm,
              'is_online': row['is_online'] == true,
              'is_available': row['is_available'] == true,
              'has_active_ride': false,
              'last_location_at': row['updated_at'],
            }),
          );
        } catch (e, s) {
          AppLogger.debug('NearbyDrivers direct fallback row note: $e',
              error: e, stackTrace: s);
        }
      }
      drivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return drivers;
    } catch (e, s) {
      AppLogger.warn('NearbyDrivers direct fallback failed: $e',
          error: e, stackTrace: s);
      return const <NearbyDriver>[];
    }
  }

  Future<void> saveDriverLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    await _client.from('drivers').update({
      'current_latitude': latitude,
      'current_longitude': longitude,
      'last_location_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }

  Stream<DriverLiveLocation?> streamDriverLocation(String driverId) =>
      realtimeQueryStream<DriverLiveLocation?>(
        client: _client,
        feature: 'driver_location',
        table: 'driver_presence',
        filterDescription: 'driver_id=$driverId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
        ],
        fetch: () async {
          final row = await _client
              .from('driver_presence')
              .select()
              .eq('driver_id', driverId)
              .maybeSingle();
          if (row == null) return null;
          final lat = (row['latitude'] as num?)?.toDouble();
          final lng = (row['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return DriverLiveLocation(
            position: Geo(lat, lng),
            updatedAt: _date(row['last_location_at']),
            fromCache: false,
          );
        },
        pollInterval: const Duration(seconds: 4),
      );

  Future<void> setDriverAvailability(String userId, bool isOnline) async {
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('A driver can only change their own availability.');
    }
    if (isOnline) {
      await startDriverOnlineSession();
    } else {
      final changed = await setDriverOffline();
      if (!changed) throw StateError('Driver could not be set Offline.');
    }
  }

  Future<String?> startDriverOnlineSession() async {
    final result = await _client.rpc('start_driver_online_session');
    return result?.toString();
  }

  Future<bool> stopDriverOnlineSession() async {
    final result = await _client.rpc('stop_driver_online_session');
    return result == true;
  }

  Future<bool> setDriverOffline() async {
    final result = await _client.rpc('set_driver_offline');
    return result == true;
  }

  Future<bool> heartbeatDriverOnlineSession() async {
    final result = await _client.rpc('heartbeat_driver_online_session');
    return result == true;
  }

  Future<double> driverOnlineHoursToday(String driverId) async {
    final result = await _client.rpc(
      'driver_online_hours_today',
      params: {'target_driver': driverId},
    );
    if (result is num) return result.toDouble();
    return double.tryParse(result?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _driverRow(DriverProfile profile) => {
        'user_id': profile.userId,
        'vehicle_type': profile.vehicleType.key,
        'plate_number': profile.plateNumber,
        'license_type': profile.licenseType?.trim().isNotEmpty == true
            ? profile.licenseType!.trim()
            : null,
        'license_number': profile.licenseNumber.trim().isEmpty
            ? null
            : profile.licenseNumber.trim(),
        'license_expiry':
            profile.licenseExpiry.isEmpty ? null : profile.licenseExpiry,
        'dl_codes': profile.dlCodes.isEmpty ? null : profile.dlCodes.join(','),
        'condition_codes': profile.conditionCodes.isEmpty
            ? null
            : profile.conditionCodes.join(','),
        'vehicle_make': profile.make,
        'vehicle_model': profile.model,
        'vehicle_year': profile.year,
        'vehicle_color': profile.color,
        'date_of_birth': profile.dob.isEmpty ? null : profile.dob,
        'sex': profile.sex,
        'barangay': profile.barangay,
        'municipality': profile.municipality,
        'province': profile.province,
        // `drivers.toda_id` is a foreign key. A vehicle with no TODA must
        // write null, never an empty string.
        'toda_id': DriverApplicationRules.todaIdForVehicle(
          profile.vehicleType,
          profile.todaId,
        ),
        'submitted_at': profile.submittedAt.toUtc().toIso8601String(),
      };

  Future<void> saveDriverProfile(DriverProfile profile) async {
    final row = _driverRow(profile)..remove('user_id');
    final updated = await _client
        .from('drivers')
        .update(row)
        .eq('user_id', profile.userId)
        .select('user_id');
    if (updated.isEmpty) {
      throw StateError(
        'A Driver profile can only be created after Admin approval.',
      );
    }
  }

  Future<Object?> _invokeDriverApplications(
    Map<String, Object?> body,
  ) async {
    final action = body['action']?.toString() ?? 'unknown';
    try {
      final response = await _client.functions.invoke(
        'driver-applications',
        body: body,
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final message = data is Map ? data['error']?.toString() : null;
        throw StateError(
          'driver-applications action=$action failed '
          '(HTTP ${response.status}): '
          '${message ?? 'Driver application request failed.'}',
        );
      }
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final message =
          details is Map ? details['error']?.toString() : details?.toString();
      throw StateError(
        'driver-applications action=$action failed '
        '(HTTP ${error.status}): '
        '${message ?? error.reasonPhrase ?? 'Driver application request failed.'}',
      );
    }
  }

  Future<({String applicationId, String statusToken, String status})>
      submitUnlinkedDriverApplication({
    required String fullName,
    required String email,
    required String mobile,
    required DriverProfile profile,
    required String submissionKey,
    required String statusToken,
    required Map<String, Uint8List> documentBytes,
    required Map<String, String> documentContentTypes,
  }) async {
    const maxDocumentBytes = 10 * 1024 * 1024;
    final descriptors = <String, Object?>{};
    for (final entry in documentBytes.entries) {
      final mime = (documentContentTypes[entry.key] ?? 'image/jpeg')
          .toLowerCase()
          .split(';')
          .first
          .trim();
      if (entry.value.isEmpty || entry.value.length > maxDocumentBytes) {
        throw StateError('Each driver document must be smaller than 10 MB.');
      }
      final extension = switch (mime) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => throw StateError('Use a JPEG, PNG, or WebP image for documents.'),
      };
      descriptors[entry.key] = {
        'content_type': mime,
        'extension': extension,
      };
    }
    if (!descriptors.containsKey('profile')) {
      throw StateError('A profile photo is required.');
    }

    final begun = _asFunctionMap(await _invokeDriverApplications({
      'action': 'begin',
      'submission_key': submissionKey,
      'status_token': statusToken,
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'mobile': mobile.trim(),
      'address': profile.address.trim(),
      'date_of_birth': profile.dob.trim(),
      'sex': profile.sex,
      'vehicle_type': profile.vehicleType.key,
      'plate_number': profile.plateNumber.trim(),
      'vehicle_make': profile.make.trim(),
      'vehicle_model': profile.model.trim(),
      'vehicle_year': profile.year,
      'vehicle_color': profile.color.trim(),
      'license_type': profile.licenseType,
      'license_number': profile.licenseNumber.trim().isEmpty
          ? null
          : profile.licenseNumber.trim(),
      'license_expiry': profile.licenseExpiry.trim().isEmpty
          ? null
          : profile.licenseExpiry.trim(),
      'dl_codes': profile.dlCodes.isEmpty ? null : profile.dlCodes.join(','),
      'condition_codes': profile.conditionCodes.isEmpty
          ? null
          : profile.conditionCodes.join(','),
      'toda_id': profile.todaId,
      'barangay': profile.barangay.trim(),
      'municipality': profile.municipality.trim(),
      'province': profile.province.trim(),
      'documents': descriptors,
    }));
    final applicationId = begun['applicationId']?.toString();
    final returnedToken = begun['statusToken']?.toString();
    if (applicationId == null ||
        applicationId.isEmpty ||
        returnedToken == null) {
      throw StateError(
          'The application service returned an incomplete receipt.');
    }

    if (begun['status'] == 'uploading') {
      final uploads = begun['uploads'];
      if (uploads is! List) {
        throw StateError('The private upload grants were invalid.');
      }
      for (final value in uploads) {
        if (value is! Map) {
          throw StateError('A private upload grant was invalid.');
        }
        final upload = Map<String, dynamic>.from(value);
        final kind = upload['kind']?.toString() ?? '';
        final path = upload['path']?.toString() ?? '';
        final token = upload['token']?.toString() ?? '';
        final bytes = documentBytes[kind];
        final contentType = upload['contentType']?.toString() ?? '';
        if (bytes == null ||
            path.isEmpty ||
            token.isEmpty ||
            contentType.isEmpty) {
          throw StateError(
              'A document upload grant did not match the application.');
        }
        await _client.storage.from('driver-documents').uploadBinaryToSignedUrl(
              path,
              token,
              bytes,
              FileOptions(contentType: contentType, upsert: true),
            );
      }
      final finalized = _asFunctionMap(await _invokeDriverApplications({
        'action': 'finalize',
        'application_id': applicationId,
        'status_token': returnedToken,
      }));
      return (
        applicationId: applicationId,
        statusToken: returnedToken,
        status: finalized['status']?.toString() ?? 'pending',
      );
    }
    return (
      applicationId: applicationId,
      statusToken: returnedToken,
      status: begun['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> _asFunctionMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('The driver application service returned invalid data.');
  }

  Future<Map<String, dynamic>> getUnlinkedDriverApplicationStatus({
    required String applicationId,
    required String statusToken,
  }) async =>
      _asFunctionMap(await _invokeDriverApplications({
        'action': 'status',
        'application_id': applicationId,
        'status_token': statusToken,
      }));

  Future<Map<String, dynamic>> reviewUnlinkedDriverApplication({
    required String applicationId,
    required String decision,
    String? reason,
  }) async =>
      _asFunctionMap(await _invokeDriverApplications({
        'action': decision,
        'application_id': applicationId,
        if (reason != null) 'reason': reason,
      }));

  Future<void> activateInvitedDriver() async {
    await _invokeDriverApplications({'action': 'activate'});
  }

  Future<bool> clearRejectedDriverApplication(String applicationId) async {
    final result = await _client.rpc(
      'clear_rejected_driver_application',
      params: {'p_application_id': applicationId},
    );
    return result == true;
  }

  Future<int> clearAllRejectedDriverApplications() async {
    final result = await _client.rpc('clear_all_rejected_driver_applications');
    return (result is num) ? result.toInt() : 0;
  }

  Future<void> submitDriverApplication({
    required AppUser user,
    required DriverProfile profile,
  }) async {
    throw StateError(
      'Use the secure pre-approval application submission workflow. An Auth user or Driver profile is not created during application.',
    );
  }

  Future<void> updateDriverProfile(DriverProfile profile) =>
      saveDriverProfile(profile);

  Future<DriverProfile?> getDriverProfile(String userId) async {
    final row = await _client
        .from('drivers')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final data = Map<String, Object?>.from(row);
    final docs = await _client
        .from('driver_documents')
        .select('document_type,storage_path')
        .eq('driver_id', userId);
    for (final doc in docs) {
      final type = doc['document_type']?.toString();
      final path = doc['storage_path']?.toString();
      if (type == null || path == null) continue;
      final signed = await _client.storage
          .from('driver-documents')
          .createSignedUrl(path, 60 * 15);
      switch (type) {
        case 'license_front':
          data['doc_license_front'] = signed;
        case 'license_back':
          data['doc_license_back'] = signed;
        case 'or_cr':
          data['doc_or_cr'] = signed;
        case 'profile':
          data['doc_profile'] = signed;
      }
    }
    data.addAll({
      'dob': data['date_of_birth']?.toString() ?? '',
      'make': data['vehicle_make'],
      'model': data['vehicle_model'],
      'year': data['vehicle_year'],
      'color': data['vehicle_color'],
    });
    final todaId = data['toda_id']?.toString().trim() ?? '';
    if (todaId.isNotEmpty) {
      final toda = await _client
          .from('todas')
          .select('name')
          .eq('id', todaId)
          .maybeSingle();
      data['toda_name'] = toda?['name'];
    }
    return DriverProfile.fromMap(data);
  }

  Future<String?> getDriverVerificationStatus(String userId) async {
    final row = await _client
        .from('drivers')
        .select('application_status')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['application_status']?.toString();
  }

  Stream<DriverProfile?> streamDriverProfile(String userId) =>
      Stream.fromFuture(getDriverProfile(userId));

  Future<void> setDriverVerificationStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    final isAdmin = await getAdminUserId() != null;
    final approved = status == 'approved' || status == 'active';

    debugPrint('============================================================');
    debugPrint('DRIVER APPROVAL START');
    debugPrint('Driver ID: $userId');
    debugPrint('Admin UID: ${_client.auth.currentUser?.id}');
    debugPrint('Admin authenticated: ${_client.auth.currentUser != null}');
    debugPrint('Admin verified in admin_roles: $isAdmin');
    debugPrint('Requested status: $status');
    debugPrint('Database operation: RPC approve_driver');

    try {
      await _client.rpc('approve_driver', params: {
        'target_driver': userId,
        'approved': approved,
        'rejection_reason': reason,
      });
      debugPrint('Database update: SUCCESS');
      debugPrint('DRIVER APPROVAL END');
      debugPrint(
          '============================================================');
    } on PostgrestException catch (error) {
      debugPrint('Exception type: PostgrestException');
      debugPrint('Supabase/Postgres/PostgREST code: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      debugPrint('DRIVER APPROVAL END');
      debugPrint(
          '============================================================');
      rethrow;
    } catch (e, st) {
      debugPrint('Exception type: ${e.runtimeType}');
      debugPrint('Message: $e');
      debugPrint('Stack trace: $st');
      debugPrint('DRIVER APPROVAL END');
      debugPrint(
          '============================================================');
      rethrow;
    }
  }

  /// `passenger_profiles` is intentionally outside the Realtime publication;
  /// this remains an authoritative one-shot read rather than a false live
  /// stream that can never receive a channel event.
  Stream<PassengerCloudProfile?> streamPassengerProfile(String userId) =>
      Stream.fromFuture(_client
          .from('passenger_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .then((row) => row == null
              ? null
              : PassengerCloudProfile.fromMap(Map<String, Object?>.from(row))));

  Future<void> savePassengerProfile(
    String userId, {
    List<String>? savedAddresses,
    String? defaultAddress,
    List<String>? paymentMethods,
    PhilippineAddress? address,
    bool initialize = false,
  }) async {
    await _client.from('passenger_profiles').upsert({
      'user_id': userId,
      if (savedAddresses != null) 'saved_addresses': savedAddresses,
      if (defaultAddress != null) 'default_address': defaultAddress,
      if (paymentMethods != null) 'payment_methods': paymentMethods,
    });
    final formatted = address?.formattedAddress;
    if (formatted != null && formatted.isNotEmpty) {
      await _client
          .from('profiles')
          .update({'address': formatted}).eq('id', userId);
    }
  }

  // --- Saved Places (public.saved_places) ---

  Future<List<SavedPlace>> getSavedPlaces(String userId) async {
    final rows = await _client
        .from('saved_places')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SavedPlace.fromMap(Map<String, Object?>.from(row as Map)))
        .toList();
  }

  Future<void> saveSavedPlace(SavedPlace place) async {
    await _client.from('saved_places').upsert(
          place.toDatabaseRow(),
          onConflict: 'id',
        );
  }

  Future<void> deleteSavedPlace(String userId, String placeId) async {
    await _client
        .from('saved_places')
        .delete()
        .eq('user_id', userId)
        .eq('id', placeId);
  }

  Future<void> incrementPassengerRideCount(String userId) async {
    final row = await _client
        .from('passenger_profiles')
        .select('ride_count')
        .eq('user_id', userId)
        .single();
    await _client.from('passenger_profiles').update({
      'ride_count': ((row['ride_count'] as num?)?.toInt() ?? 0) + 1,
    }).eq('user_id', userId);
  }

  Trip _trip(Map<String, dynamic> row) {
    final rating = _one(row['ratings']);
    return Trip.fromMap({
      ...row,
      if (rating != null) ...{
        'rating': rating['rating'],
        'rating_comment': rating['comment'],
      },
      'pickup_lat': row['pickup_latitude'] ?? row['pickup_lat'],
      'pickup_lng': row['pickup_longitude'] ?? row['pickup_lng'],
      'dropoff_lat': row['destination_latitude'] ?? row['dropoff_lat'],
      'dropoff_lng': row['destination_longitude'] ?? row['dropoff_lng'],
      'pickup_address': row['pickup_address'],
      'destination_address':
          row['destination_address'] ?? row['dropoff_address'],
      'dropoff_address': row['destination_address'] ?? row['dropoff_address'],
      'duration_min': row['duration_minutes'] ?? row['duration_min'],
      'net': row['driver_net'] ?? row['net'],
    });
  }

  Future<Trip?> saveTrip(Trip trip) async {
    final response = await _client.rpc('request_ride_with_id', params: {
      'client_ride_id': trip.id,
      'requested_driver': trip.driverId,
      'requested_vehicle': trip.vehicleType.key,
      'passenger_name': trip.passengerName,
      'passenger_phone': trip.passengerPhone,
      'pickup_address': trip.pickupAddress,
      'pickup_latitude': trip.pickup.lat,
      'pickup_longitude': trip.pickup.lng,
      'pickup_province': null,
      'destination_address': trip.dropoffAddress,
      'destination_latitude': trip.dropoff.lat,
      'destination_longitude': trip.dropoff.lng,
      'destination_province': null,
      'distance_km': trip.distanceKm,
      'duration_minutes': trip.durationMin,
      'payment_method': trip.paymentMethod,
      'estimated_fare': trip.fare,
    });

    if (response is Map) {
      return _trip(Map<String, dynamic>.from(response));
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return _trip(Map<String, dynamic>.from(response.first as Map));
    }
    return null;
  }

  Future<void> updateTrip(String tripId, Map<String, Object?> fields) async {
    final status = fields['status']?.toString();
    if (status == RideStatus.cancelled) {
      await cancelRide(rideId: tripId);
      return;
    }
    if (status == RideStatus.accepted) {
      final ok = await _client.rpc('accept_ride', params: {'ride_id': tripId});
      if (ok != true) throw StateError('Ride could not be accepted.');
      return;
    }
    if ({RideStatus.arrived, RideStatus.started, RideStatus.completed}
        .contains(status)) {
      final ok = await _client.rpc('transition_ride', params: {
        'ride_id': tripId,
        'next_status': status,
      });
      if (ok != true) throw StateError('Invalid ride status transition.');
      return;
    }
    throw StateError(
        'Direct ride updates are blocked; use a secured ride operation.');
  }

  Stream<Trip?> streamActiveTripForPassenger(String passengerId) =>
      realtimeQueryStream<Trip?>(
        client: _client,
        feature: 'passenger_active_trip',
        table: 'rides',
        filterDescription: 'passenger_id=$passengerId;active_only',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: passengerId,
          ),
        ],
        fetch: () async {
          final rows = await _client
              .from('rides')
              .select(_rideWithRatingSelect)
              .eq('passenger_id', passengerId)
              .inFilter('status', kActiveRideStatuses.toList())
              .order('created_at', ascending: false)
              .limit(1);
          if (rows.isEmpty) return null;
          return _trip(Map<String, dynamic>.from(rows.first));
        },
        pollInterval: const Duration(seconds: 3),
      );

  Stream<Trip?> streamActiveTripForDriver(String driverId) =>
      realtimeQueryStream<Trip?>(
        client: _client,
        feature: 'driver_active_trip',
        table: 'rides',
        filterDescription: 'driver_id=$driverId;active_only',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
        ],
        fetch: () async {
          final rows = await _client
              .from('rides')
              .select(_rideWithRatingSelect)
              .eq('driver_id', driverId)
              .inFilter('status', kActiveRideStatuses.toList())
              .order('created_at', ascending: false)
              .limit(1);
          if (rows.isEmpty) return null;
          return _trip(Map<String, dynamic>.from(rows.first));
        },
        pollInterval: const Duration(seconds: 3),
      );

  Future<List<Trip>> fetchRideHistoryForPassengerOnce(
    String passengerId, {
    int limit = 100,
  }) async {
    final sw = Stopwatch()..start();
    final rows = await _client
        .from('rides')
        .select(_rideWithRatingSelect)
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false)
        .limit(limit);
    final result =
        rows.map((row) => _trip(Map<String, dynamic>.from(row))).toList();
    sw.stop();
    debugPrint('[SakayTa][Perf][History] role=passenger uid=$passengerId '
        'rows=${result.length} queryMs=${sw.elapsedMilliseconds}');
    return result;
  }

  Future<List<Trip>> fetchRideHistoryForDriverOnce(
    String driverId, {
    int limit = 100,
  }) async {
    final sw = Stopwatch()..start();
    final rows = await _client
        .from('rides')
        .select(_rideWithRatingSelect)
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);
    final result =
        rows.map((row) => _trip(Map<String, dynamic>.from(row))).toList();
    sw.stop();
    debugPrint('[SakayTa][Perf][History] role=driver uid=$driverId '
        'rows=${result.length} queryMs=${sw.elapsedMilliseconds}');
    return result;
  }

  Stream<List<Trip>> streamRideHistoryForPassenger(
    String passengerId, {
    int limit = 100,
  }) =>
      realtimeQueryStream<List<Trip>>(
        client: _client,
        feature: 'passenger_ride_history',
        table: 'rides',
        filterDescription: 'passenger_id=$passengerId;limit=$limit',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: passengerId,
          ),
        ],
        fetch: () => fetchRideHistoryForPassengerOnce(
          passengerId,
          limit: limit,
        ),
        pollInterval: const Duration(seconds: 20),
      );

  Stream<List<Trip>> streamRideHistoryForDriver(
    String driverId, {
    int limit = 100,
  }) =>
      realtimeQueryStream<List<Trip>>(
        client: _client,
        feature: 'driver_ride_history',
        table: 'rides',
        filterDescription: 'driver_id=$driverId;limit=$limit',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
        ],
        fetch: () => fetchRideHistoryForDriverOnce(
          driverId,
          limit: limit,
        ),
        pollInterval: const Duration(seconds: 30),
      );

  Future<Map<String, ({String name, String plate, String? photoUrl, int avatarColor})>>
      getDriverDisplayInfoBatch(Iterable<String> driverIds) async {
    final uniqueIds = driverIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return const {};

    final sw = Stopwatch()..start();
    final result =
        <String, ({String name, String plate, String? photoUrl, int avatarColor})>{};

    String? resolvePublicAvatar(String? rawPath) {
      final trimmed = rawPath?.trim() ?? '';
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      var cleanPath = trimmed;
      if (cleanPath.startsWith('driver-documents/')) {
        cleanPath = cleanPath.substring('driver-documents/'.length);
      }
      final cached = driverPhotoUrlCache[cleanPath];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        return cached.url;
      }
      if (cleanPath.contains('/profile/') || cleanPath.contains('profile_')) {
        return _client.storage.from('driver-documents').getPublicUrl(cleanPath);
      }
      if (cleanPath.startsWith('avatars/')) {
        cleanPath = cleanPath.substring('avatars/'.length);
      }
      return _client.storage.from('avatars').getPublicUrl(cleanPath);
    }

    try {
      final rpcRows = await _client.rpc(
        'get_ride_driver_display_info',
        params: {'target_driver_ids': uniqueIds},
      );
      if (rpcRows is List) {
        for (final item in rpcRows) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final id = row['driver_id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          result[id] = (
            name: row['full_name']?.toString().trim() ?? '',
            plate: row['plate_number']?.toString().trim() ?? '',
            photoUrl: resolvePublicAvatar(row['profile_photo_path']?.toString()),
            avatarColor: (row['avatar_color'] as num?)?.toInt() ?? 0,
          );
        }
      }
    } catch (e) {
      debugPrint('[SakayTa][Perf][History] RPC get_ride_driver_display_info '
          'fallback triggered: $e');
    }

    final remainingIds =
        uniqueIds.where((id) => !result.containsKey(id)).toList();
    if (remainingIds.isNotEmpty) {
      final platesById = <String, String>{};
      final namesById = <String, String>{};
      final photosById = <String, String?>{};
      final colorsById = <String, int>{};

      try {
        final presenceRows = await _client
            .from('driver_presence')
            .select('driver_id,plate_number')
            .inFilter('driver_id', remainingIds);
        for (final raw in presenceRows) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['driver_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            platesById[id] = row['plate_number']?.toString().trim() ?? '';
          }
        }
      } catch (e, s) {
        AppLogger.debug('SupabaseDatabaseService non-fatal note: $e',
            error: e, stackTrace: s);
      }

      try {
        final profileRows = await _client
            .from('profiles')
            .select('id,full_name,profile_photo_path,avatar_color')
            .inFilter('id', remainingIds);
        for (final raw in profileRows) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            namesById[id] = row['full_name']?.toString().trim() ?? '';
            photosById[id] =
                resolvePublicAvatar(row['profile_photo_path']?.toString());
            colorsById[id] = (row['avatar_color'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (e, s) {
        AppLogger.debug('SupabaseDatabaseService non-fatal note: $e',
            error: e, stackTrace: s);
      }

      for (final id in remainingIds) {
        result[id] = (
          name: namesById[id] ?? '',
          plate: platesById[id] ?? '',
          photoUrl: photosById[id],
          avatarColor: colorsById[id] ?? 0,
        );
      }
    }

    sw.stop();
    debugPrint('[SakayTa][Perf][History] batchDriverDisplayInfo '
        'requested=${uniqueIds.length} resolved=${result.length} '
        'durationMs=${sw.elapsedMilliseconds}');
    return result;
  }

  Stream<List<Trip>> streamIncomingRequestsForDriver({
    required String driverId,
    required VehicleType vehicleType,
    double? lat,
    double? lng,
    double radiusKm = 10.0,
  }) {
    if (_client.auth.currentUser?.id != driverId) {
      return Stream.error(
        StateError('A driver can only retrieve their own ride requests.'),
      );
    }
    var expiredOwnRequests = false;
    return realtimeQueryStream<List<Trip>>(
      client: _client,
      feature: 'driver_incoming_requests',
      table: 'rides',
      throttle: const Duration(seconds: 2),
      filterDescription:
          'status=searching;driver=$driverId;vehicle=${vehicleType.key}',
      filters: [
        PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'status',
          value: RideStatus.searching,
        ),
      ],
      fetch: () async {
        if (!expiredOwnRequests) {
          await _client.rpc('expire_driver_pending_requests');
          expiredOwnRequests = true;
        }
        final rows = await _client
            .from('rides')
            .select()
            .eq('status', RideStatus.searching)
            .order('created_at', ascending: false);
        return rows
            .map((row) => _trip(Map<String, dynamic>.from(row)))
            .where((trip) => isIncomingRideVisibleToDriver(
                  trip: trip,
                  driverId: driverId,
                  vehicleType: vehicleType,
                  latitude: lat,
                  longitude: lng,
                  radiusKm: radiusKm,
                ))
            .toList();
      },
      pollInterval: const Duration(seconds: 3),
    );
  }

  bool isIncomingRideVisibleToDriver({
    required Trip trip,
    required String driverId,
    required VehicleType vehicleType,
    double? latitude,
    double? longitude,
    required double radiusKm,
  }) {
    if (trip.status != RideStatus.searching) return false;
    if (trip.driverId != null && trip.driverId!.isNotEmpty) {
      return trip.driverId == driverId;
    }
    if (trip.vehicleType != vehicleType) return false;
    if (latitude != null && longitude != null) {
      if (Geo.distanceKm(Geo(latitude, longitude), trip.pickup) > radiusKm) {
        return false;
      }
    }
    return true;
  }

  Future<bool> atomicAcceptBooking({
    required String rideId,
    required AppUser driver,
  }) async =>
      await _client.rpc('accept_ride', params: {'ride_id': rideId}) == true;

  Future<bool> transitionDriverRide({
    required String rideId,
    required String driverId,
    required Set<String> fromStatuses,
    required String toStatus,
  }) async =>
      await _client.rpc('transition_ride', params: {
        'ride_id': rideId,
        'next_status': toStatus,
      }) ==
      true;

  Future<bool> cancelRide({required String rideId}) async =>
      await _client.rpc('cancel_ride', params: {
        'ride_id': rideId,
        'reason': 'Cancelled by user',
      }) ==
      true;

  Future<void> declineBooking({
    required String rideId,
    required String driverId,
  }) async {
    final ok = await _client.rpc('decline_ride', params: {'ride_id': rideId});
    if (ok != true) throw StateError('Ride could not be declined.');
  }

  Stream<Trip?> streamTrip(String rideId) => realtimeQueryStream<Trip?>(
        client: _client,
        feature: 'ride_detail',
        table: 'rides',
        filterDescription: 'id=$rideId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
        ],
        fetch: () async {
          final row = await _client
              .from('rides')
              .select(_rideWithRatingSelect)
              .eq('id', rideId)
              .maybeSingle();
          return row == null ? null : _trip(Map<String, dynamic>.from(row));
        },
        pollInterval: const Duration(seconds: 3),
      );

  Future<Trip?> getTrip(String tripId) async {
    final row = await _client
        .from('rides')
        .select(_rideWithRatingSelect)
        .eq('id', tripId)
        .maybeSingle();
    return row == null ? null : _trip(Map<String, dynamic>.from(row));
  }

  Future<List<AppUser>> getOnlineDrivers({String? vehicleType}) async {
    var rows = await _client
        .from('driver_presence')
        .select('driver_id,vehicle_type')
        .eq('is_online', true)
        .eq('is_available', true);
    if (vehicleType != null) {
      rows = rows.where((row) => row['vehicle_type'] == vehicleType).toList();
    }
    return _usersForIds(rows.map((row) => row['driver_id'].toString()));
  }

  Future<bool> isDriverBookable(String driverId) async {
    final result = await _client.rpc('is_driver_bookable', params: {
      'target_driver': driverId,
    });
    return result == true;
  }

  Future<bool> isDriverRequestable(String driverId) async {
    final result = await _client.rpc('is_driver_requestable', params: {
      'target_driver': driverId,
    });
    return result == true;
  }

  Future<void> saveBooking(Map<String, dynamic> bookingMap) async {
    await _client.from('bookings').upsert({
      'id': bookingMap['id'],
      'passenger_id': bookingMap['passenger_id'],
      'vehicle_type': bookingMap['vehicle_type'],
      'pickup_address': bookingMap['pickup_address'],
      'destination_address':
          bookingMap['dropoff_address'] ?? bookingMap['destination_address'],
      'pickup_latitude': bookingMap['pickup_lat'],
      'pickup_longitude': bookingMap['pickup_lng'],
      'destination_latitude': bookingMap['dropoff_lat'],
      'destination_longitude': bookingMap['dropoff_lng'],
      'payment_method': bookingMap['payment_method'] ?? 'cash',
      'status': bookingMap['status'] ?? 'requested',
      'queued': bookingMap['queued'] == true || bookingMap['queued'] == 1,
      'created_at': _iso(bookingMap['created_at']),
    });
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    await _client.from('chat_messages').insert({
      'id': message.id,
      'ride_id': message.tripId,
      'sender_id': message.senderId,
      'sender_role': message.isDriver ? 'driver' : 'passenger',
      'body': message.text,
      'created_at': message.createdAt.toUtc().toIso8601String(),
    });
  }

  ChatMessage _chat(Map<String, dynamic> row) => ChatMessage.fromMap({
        'id': row['id'],
        'trip_id': row['ride_id'],
        'sender_id': row['sender_id'],
        'sender_name': row['sender_name'] ?? '',
        'is_driver': row['sender_role'] == 'driver' ? 1 : 0,
        'text': row['body'],
        'created_at': _millis(row['created_at']),
      });

  Stream<List<ChatMessage>> streamChatMessages(String tripId) =>
      realtimeQueryStream<List<ChatMessage>>(
        client: _client,
        feature: 'ride_chat',
        table: 'chat_messages',
        filterDescription: 'ride_id=$tripId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: tripId,
          ),
        ],
        fetch: () async {
          final rows = await _client
              .from('chat_messages')
              .select()
              .eq('ride_id', tripId)
              .order('created_at');
          return rows
              .map((row) => _chat(Map<String, dynamic>.from(row)))
              .toList();
        },
        pollInterval: const Duration(seconds: 4),
      );

  Future<void> saveRating(FireRating rating) async {
    await _client.rpc('submit_ride_rating', params: {
      'target_ride': rating.rideId,
      'target_rating': rating.stars,
      'target_comment': rating.comment,
    });
  }

  FireRating _rating(Map<String, dynamic> row) => FireRating.fromMap({
        'id': row['id'],
        'rideId': row['ride_id'],
        'fromUserId': row['passenger_id'],
        'toUserId': row['driver_id'],
        'stars': row['rating'],
        'comment': row['comment'],
        'createdAt': row['created_at'],
      });

  Stream<List<FireRating>> streamRatingsFor(String userId) =>
      realtimeQueryStream<List<FireRating>>(
        client: _client,
        feature: 'user_ratings',
        table: 'ratings',
        filterDescription: 'driver_id=$userId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
        ],
        fetch: () async {
          final rows = await _client
              .from('ratings')
              .select()
              .eq('driver_id', userId)
              .order('created_at', ascending: false);
          return rows
              .map((row) => _rating(Map<String, dynamic>.from(row)))
              .toList();
        },
      );

  Map<String, dynamic> _paymentRow(FirePayment payment) => {
        'id': payment.id,
        'ride_id': payment.rideId,
        'passenger_id': payment.payerId,
        'driver_id': payment.payeeId.isEmpty ? null : payment.payeeId,
        'amount': payment.amount,
        'platform_fee': 0,
        'driver_net': payment.amount,
        'method': payment.method,
        'provider_reference': payment.reference,
        'status': payment.status,
        'metadata': {
          if (payment.sessionId != null) 'session_id': payment.sessionId,
          if (payment.checkoutUrl != null) 'checkout_url': payment.checkoutUrl,
        },
        'created_at': payment.createdAt.toUtc().toIso8601String(),
        'paid_at': payment.verifiedAt?.toUtc().toIso8601String(),
      };

  FirePayment _payment(Map<String, dynamic> row) {
    final metadata = _one(row['metadata']) ?? const <String, dynamic>{};
    return FirePayment.fromMap({
      'id': row['id'],
      'rideId': row['ride_id'],
      'payerId': row['passenger_id'],
      'payeeId': row['driver_id'] ?? '',
      'amount': row['amount'],
      'method': row['method'],
      'status': row['status'],
      'reference': row['provider_reference'],
      'sessionId': metadata['session_id'],
      'checkoutUrl': metadata['checkout_url'],
      'verifiedAt': row['paid_at'],
      'createdAt': row['created_at'],
    });
  }

  Future<void> savePayment(FirePayment payment) async {
    await _client.from('payments').upsert(_paymentRow(payment));
  }

  Future<FirePayment?> getPayment(String paymentId) async {
    final row = await _client
        .from('payments')
        .select()
        .eq('id', paymentId)
        .maybeSingle();
    return row == null ? null : _payment(Map<String, dynamic>.from(row));
  }

  Future<FirePayment?> getPaymentForRide(String rideId) async {
    final row = await _client
        .from('payments')
        .select()
        .eq('ride_id', rideId)
        .maybeSingle();
    return row == null ? null : _payment(Map<String, dynamic>.from(row));
  }

  Stream<FirePayment?> streamPayment(String paymentId) =>
      realtimeQueryStream<FirePayment?>(
        client: _client,
        feature: 'payment_detail',
        table: 'payments',
        filterDescription: 'id=$paymentId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: paymentId,
          ),
        ],
        fetch: () async {
          final row = await _client
              .from('payments')
              .select()
              .eq('id', paymentId)
              .maybeSingle();
          return row == null ? null : _payment(Map<String, dynamic>.from(row));
        },
      );

  Stream<FirePayment?> streamPaymentForRide(String rideId) =>
      realtimeQueryStream<FirePayment?>(
        client: _client,
        feature: 'ride_payment',
        table: 'payments',
        filterDescription: 'ride_id=$rideId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
        ],
        fetch: () async {
          final row = await _client
              .from('payments')
              .select()
              .eq('ride_id', rideId)
              .maybeSingle();
          return row == null ? null : _payment(Map<String, dynamic>.from(row));
        },
      );

  Stream<List<FirePayment>> streamPaymentsFor(String userId) =>
      realtimeQueryStream<List<FirePayment>>(
        client: _client,
        feature: 'user_payments',
        table: 'payments',
        filterDescription: 'passenger_id=$userId OR driver_id=$userId',
        fetch: () async {
          final rows = await _client
              .from('payments')
              .select()
              .or('passenger_id.eq.$userId,driver_id.eq.$userId')
              .order('created_at', ascending: false);
          return rows
              .map((row) => _payment(Map<String, dynamic>.from(row)))
              .toList();
        },
      );

  Future<bool> atomicSettleRidePayment({
    required String paymentId,
    required String rideId,
    required String driverId,
    required String passengerId,
    required double fare,
    required double commission,
    required double net,
    required String method,
    required String reference,
    String? gatewayPaymentId,
  }) async =>
      await _client.rpc('settle_ride_payment', params: {
        'payment_id': paymentId,
        'ride_id': rideId,
        'provider_reference': gatewayPaymentId ?? reference,
      }) ==
      true;

  DriverEarning _earning(Map<String, dynamic> row) => DriverEarning.fromMap({
        'id': row['id'],
        'driver_id': row['driver_id'],
        'ride_id': row['ride_id'],
        'fare': row['gross_amount'],
        'commission': row['commission'],
        'net': row['net_amount'],
        'payment_method': row['payment_method'],
        'settlement_status': row['settlement_status'],
        'created_at': row['created_at'],
      });

  Future<List<DriverEarning>> fetchDriverEarningsOnce(String driverId) async {
    final sw = Stopwatch()..start();
    const pageSize = 1000;
    final earnings = <DriverEarning>[];
    for (var offset = 0;; offset += pageSize) {
      final rows = await _client
          .from('driver_earnings')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      earnings
          .addAll(rows.map((row) => _earning(Map<String, dynamic>.from(row))));
      if (rows.length < pageSize) break;
    }
    sw.stop();
    debugPrint('[SakayTa][Perf][Wallet] table=driver_earnings '
        'driverId=$driverId rows=${earnings.length} '
        'queryMs=${sw.elapsedMilliseconds}');
    return earnings;
  }

  Stream<List<DriverEarning>> streamDriverEarnings(String driverId) =>
      realtimeQueryStream<List<DriverEarning>>(
        client: _client,
        feature: 'driver_earnings',
        table: 'driver_earnings',
        filterDescription: 'driver_id=$driverId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
        ],
        fetch: () => fetchDriverEarningsOnce(driverId),
        pollInterval: const Duration(seconds: 30),
      );

  Stream<DriverDailyEarningsSummary> streamDriverDailyEarningsToday(
      String driverId) {
    if (_client.auth.currentUser?.id != driverId) {
      return Stream.error(
        StateError('A driver can only read their own daily earnings.'),
      );
    }
    return realtimeQueryStream<DriverDailyEarningsSummary>(
      client: _client,
      feature: 'driver_daily_earnings',
      table: 'rides',
      filterDescription: 'driver_id=$driverId;status=completed;PHT-day',
      filters: [
        PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'driver_id',
          value: driverId,
        ),
      ],
      fetch: () async {
        final result = await _client.rpc(
          'get_driver_daily_activity_today',
          params: {'target_driver': driverId},
        );
        final row = result is List && result.isNotEmpty
            ? Map<String, dynamic>.from(result.first as Map)
            : result is Map
                ? Map<String, dynamic>.from(result)
                : const <String, dynamic>{};
        final gross = row['gross_earnings'];
        final trips = row['completed_trips'];
        return DriverDailyEarningsSummary(
          earnings: gross is num
              ? gross.toDouble()
              : double.tryParse(gross?.toString() ?? '') ?? 0,
          trips: trips is num
              ? trips.toInt()
              : int.tryParse(trips?.toString() ?? '') ?? 0,
        );
      },
      pollInterval: const Duration(seconds: 30),
    );
  }

  Stream<List<DriverEarning>> streamAllEarnings() =>
      realtimeQueryStream<List<DriverEarning>>(
        client: _client,
        feature: 'admin_driver_earnings',
        table: 'driver_earnings',
        filterDescription: 'all driver earnings',
        fetch: allEarningsOnce,
      );

  Future<List<DriverEarning>> allEarningsOnce() async {
    return _adminRead(
      'weekly_revenue',
      'driver_earnings ordered by created_at',
      () async {
        const pageSize = 1000;
        final earnings = <DriverEarning>[];
        for (var offset = 0;; offset += pageSize) {
          final rows = await _client
              .from('driver_earnings')
              .select()
              .order('created_at', ascending: false)
              .range(offset, offset + pageSize - 1);
          earnings.addAll(
              rows.map((row) => _earning(Map<String, dynamic>.from(row))));
          if (rows.length < pageSize) return earnings;
        }
      },
    );
  }

  Future<List<DriverProfile>> allDriverProfilesOnce() async {
    final rows = await _client.from('drivers').select('user_id');
    final result = <DriverProfile>[];
    for (final row in rows) {
      final profile = await getDriverProfile(row['user_id'].toString());
      if (profile != null) result.add(profile);
    }
    return result;
  }

  Future<List<AppUser>> allUsersOnce() async {
    final rows = await _client.from('profiles').select(
        '*,drivers:drivers!drivers_user_id_fkey(*),admin_roles:admin_roles!admin_roles_user_id_fkey(*)');
    return rows.map((row) => _appUser(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> saveWithdrawal(Withdrawal withdrawal) async {
    await _client.from('withdrawals').upsert({
      'id': withdrawal.id,
      'driver_id': withdrawal.driverId,
      'amount': withdrawal.amount,
      'method': withdrawal.method,
      'status': withdrawal.status,
      'account_details': {
        if (withdrawal.reference != null) 'reference': withdrawal.reference,
        if (withdrawal.note != null) 'note': withdrawal.note,
      },
      'requested_at': withdrawal.createdAt.toUtc().toIso8601String(),
      'processed_at': withdrawal.processedAt?.toUtc().toIso8601String(),
    });
  }

  Withdrawal _withdrawal(Map<String, dynamic> row) {
    final details = _one(row['account_details']) ?? const <String, dynamic>{};
    return Withdrawal.fromMap({
      'id': row['id'],
      'driverId': row['driver_id'],
      'amount': row['amount'],
      'method': row['method'],
      'status': row['status'],
      'reference': details['reference'],
      'note': details['note'],
      'createdAt': row['requested_at'],
      'processedAt': row['processed_at'],
    });
  }

  Future<void> incrementDriverStats(
    String userId, {
    int trips = 0,
    double earnings = 0,
  }) async {
    final row = await _client
        .from('drivers')
        .select('total_trips,lifetime_earnings')
        .eq('user_id', userId)
        .single();
    await _client.from('drivers').update({
      'total_trips': ((row['total_trips'] as num?)?.toInt() ?? 0) + trips,
      'lifetime_earnings':
          ((row['lifetime_earnings'] as num?)?.toDouble() ?? 0) + earnings,
    }).eq('user_id', userId);
  }

  Future<void> recalculateDriverRating(String userId) =>
      _client.rpc('refresh_driver_rating', params: {'target_driver': userId});

  Future<List<Withdrawal>> fetchWithdrawalsOnce(String driverId) async {
    final sw = Stopwatch()..start();
    final rows = await _client
        .from('withdrawals')
        .select()
        .eq('driver_id', driverId)
        .order('requested_at', ascending: false);
    final result =
        rows.map((row) => _withdrawal(Map<String, dynamic>.from(row))).toList();
    sw.stop();
    debugPrint('[SakayTa][Perf][Wallet] table=withdrawals '
        'driverId=$driverId rows=${result.length} '
        'queryMs=${sw.elapsedMilliseconds}');
    return result;
  }

  Stream<List<Withdrawal>> streamWithdrawals(String driverId) =>
      realtimeQueryStream<List<Withdrawal>>(
        client: _client,
        feature: 'driver_withdrawals',
        table: 'withdrawals',
        filterDescription: 'driver_id=$driverId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
        ],
        fetch: () => fetchWithdrawalsOnce(driverId),
        pollInterval: const Duration(seconds: 30),
      );

  Future<Map<String, dynamic>> saveToda(Map<String, dynamic> todaMap) async {
    final id = (todaMap['id']?.toString() ?? '').trim();
    final name = (todaMap['name']?.toString() ?? '').trim();
    final city =
        (todaMap['city'] ?? todaMap['municipality'])?.toString().trim() ?? '';
    final code = (todaMap['code']?.toString() ?? id).trim();
    if (id.isEmpty) throw ArgumentError('TODA id is required.');
    if (name.isEmpty) throw ArgumentError('TODA name is required.');
    if (city.isEmpty) throw ArgumentError('TODA city is required.');
    if (code.isEmpty) throw ArgumentError('TODA code is required.');

    final payload = <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'city': city,
      'president': todaMap['president'],
      'contact_number': todaMap['contactNumber'] ?? todaMap['contact_number'],
      'is_active': todaMap['isActive'] ?? todaMap['is_active'] ?? true,
    };
    final uid = _client.auth.currentUser?.id ?? 'none';
    debugPrint('[AdminTODA][SAVE_START] uid=$uid table=todas '
        'id=$id name=$name city=$city operation=upsert');

    try {
      final existingRows = await _client.from('todas').select('id,name,city');
      final normalizedName = name.toLowerCase();
      final normalizedCity = city.toLowerCase();
      final hasScopedDuplicate = existingRows.any((row) {
        final existing = Map<String, dynamic>.from(row);
        return existing['id']?.toString().trim() != id &&
            existing['name']?.toString().trim().toLowerCase() ==
                normalizedName &&
            existing['city']?.toString().trim().toLowerCase() == normalizedCity;
      });
      if (hasScopedDuplicate) {
        throw StateError('A TODA named "$name" already exists in $city.');
      }

      final row = await _client
          .from('todas')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      final saved = Map<String, dynamic>.from(row);
      final savedId = saved['id']?.toString();
      final rowExists = savedId == id;
      debugPrint('[AdminTODA][SAVE_SUCCESS] uid=$uid table=todas '
          'id=$savedId row_exists=$rowExists');
      if (!rowExists) {
        throw StateError('Supabase returned an unexpected TODA record.');
      }
      return saved;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[AdminTODA][SAVE_ERROR] uid=$uid table=todas id=$id '
          'name=$name code=${error.code} message=${error.message} '
          'details=${error.details} hint=${error.hint}');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[AdminTODA][SAVE_ERROR] uid=$uid table=todas id=$id '
          'type=${error.runtimeType} message=$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteToda(String todaId) async {
    await _client.from('todas').delete().eq('id', todaId);
  }

  Map<String, dynamic> _fareMap(Map<String, dynamic> row) => {
        ...row,
        'id': row['id'] ?? row['vehicle_type'],
        'vehicleType': row['vehicle_type'],
        'baseFare': row['base_fare'],
        'includedBaseDistance': row['included_base_distance'] ?? 1.0,
        'perKm': row['per_km_rate'],
        'perKmRate': row['per_km_rate'],
        'minimumFare': row['minimum_fare'] ?? row['base_fare'],
        // Legacy model field; commission is no longer part of the active fare flow.
        'commissionRate': 0.0,
        'updatedAt': row['updated_at'],
      };

  Stream<List<Map<String, dynamic>>> streamFareMatrix() =>
      streamFareMatrixMaps();
  Stream<List<Map<String, dynamic>>> streamFareMatrixMaps() =>
      Stream.fromFuture(getFareMatrixOnce());

  Future<List<Map<String, dynamic>>> getFareMatrixOnce() async {
    final rows =
        await _client.from('fare_matrix').select().order('vehicle_type');
    return rows.map((row) => _fareMap(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> updateFareMatrix({
    required String vehicleType,
    required double baseFare,
    required double perKmRate,
  }) async {
    await _client.from('fare_matrix').update({
      'base_fare': baseFare,
      'per_km_rate': perKmRate,
    }).eq('vehicle_type', vehicleType);
  }

  Future<void> adminCancelTrip(String tripId, String reason) async {
    final ok = await _client.rpc('cancel_ride', params: {
      'ride_id': tripId,
      'reason': reason,
    });
    if (ok != true) throw StateError('Ride could not be cancelled.');
  }

  Future<void> adminRefundPayment(
      String paymentId, double amount, String reason) async {
    final ok = await _client.rpc('refund_ride_payment', params: {
      'payment_id': paymentId,
      'reason': reason,
    });
    if (ok != true) throw StateError('Payment could not be refunded.');
  }

  Stream<List<Map<String, dynamic>>> streamTodas() =>
      Stream.fromFuture(todasOnce());
  Future<List<Map<String, dynamic>>> todasOnce() async =>
      (await _client.from('todas').select().order('name'))
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  /// Active Admin-managed TODAs eligible for a new driver application.
  /// This RPC intentionally exposes only public signup fields, including to
  /// unauthenticated applicants whose Auth account is created at final submit.
  /// Failures propagate to the form for retry UI.
  Future<List<Map<String, dynamic>>> eligibleDriverTodasOnce() async {
    final rows = await _client.rpc('get_driver_signup_todas');
    if (rows is! List) {
      throw StateError('Supabase returned an invalid TODA list response.');
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveTodaMembership(
      {required String driverId, required String todaId}) async {
    await _client.from('toda_associations').upsert({
      'id': '${todaId}_$driverId',
      'toda_id': todaId,
      'driver_id': driverId,
      'status': AccountStatus.pending,
    });
  }

  Future<void> saveTodaAssociation(TodaAssociation association) async {
    await _client.from('toda_associations').upsert({
      'id': association.id,
      'toda_id': association.todaId,
      'driver_id': association.driverId,
      'status': association.status,
      'member_role': association.role,
      'created_at': association.createdAt.toUtc().toIso8601String(),
    });
  }

  Stream<List<TodaAssociation>> streamTodaAssociations(String todaId) =>
      Stream.fromFuture(_client
          .from('toda_associations')
          .select()
          .eq('toda_id', todaId)
          .then((rows) => rows
              .map((row) => TodaAssociation.fromMap({
                    'id': row['id'],
                    'todaId': row['toda_id'],
                    'driverId': row['driver_id'],
                    'status': row['status'],
                    'role': row['member_role'],
                    'createdAt': row['created_at'],
                  }))
              .toList()));

  Future<void> saveFareMatrix(FareMatrix matrix) => updateFareMatrix(
      vehicleType: matrix.vehicleType,
      baseFare: matrix.baseFare,
      perKmRate: matrix.perKm);

  Stream<List<FareMatrix>> streamFareMatrices() => streamFareMatrixMaps()
      .map((rows) => rows.map(FareMatrix.fromMap).toList());

  Future<void> createPassengerCloudProfile(String uid) async {
    await _client.from('passenger_profiles').upsert({'user_id': uid});
  }

  Future<void> acceptRide(
      {required String rideId, required AppUser driver}) async {
    if (!await atomicAcceptBooking(rideId: rideId, driver: driver)) {
      throw StateError('Ride is no longer available.');
    }
  }

  Future<void> startTrip(
      {required String rideId, double? driverLat, double? driverLng}) async {
    if (driverLat != null && driverLng != null) {
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        await saveDriverLocation(
            userId: uid, latitude: driverLat, longitude: driverLng);
      }
    }
    final trip = await getTrip(rideId);
    final next = trip?.status == RideStatus.accepted
        ? RideStatus.arrived
        : RideStatus.started;
    if (!await transitionDriverRide(
      rideId: rideId,
      driverId: _client.auth.currentUser?.id ?? '',
      fromStatuses: {trip?.status ?? ''},
      toStatus: next,
    )) {
      throw StateError('Trip could not be started.');
    }
  }

  /// Completes a ride through the secured transition RPC and then reads back
  /// the canonical server row. The fare supplied by the client is retained
  /// for API compatibility only; the RPC always uses `rides.fare`.
  Future<Trip> completeTrip(
      {required String rideId, required double actualFare}) async {
    final driverId = _client.auth.currentUser?.id;
    if (driverId == null || driverId.isEmpty) {
      throw StateError('No authenticated driver session.');
    }

    final transitioned = await transitionDriverRide(
      rideId: rideId,
      driverId: driverId,
      fromStatuses: {RideStatus.started},
      toStatus: RideStatus.completed,
    );
    if (!transitioned) {
      throw StateError('Trip could not be completed.');
    }

    final completed = await getTrip(rideId);
    if (completed == null ||
        completed.driverId != driverId ||
        completed.status != RideStatus.completed) {
      throw StateError(
        'Trip completion was not confirmed by the server. Please refresh and try again.',
      );
    }
    return completed;
  }

  Future<void> rateDriver({
    required String rideId,
    required String passengerId,
    required String driverId,
    required double rating,
    String? comment,
  }) =>
      saveRating(FireRating(
        id: 'rating_$rideId',
        rideId: rideId,
        fromUserId: passengerId,
        toUserId: driverId,
        stars: rating.round().clamp(1, 5),
        comment: comment ?? '',
        createdAt: DateTime.now(),
      ));

  Future<void> requestWithdrawal({
    required String driverId,
    required String driverName,
    required double amount,
    required String method,
    Map<String, dynamic>? accountDetails,
  }) async {
    await _client.from('withdrawals').insert({
      'id': _uuid.v4(),
      'driver_id': driverId,
      'amount': amount,
      'method': method,
      'account_details': accountDetails ?? {},
    });
  }

  Future<void> approveDriver(String driverId) =>
      setDriverVerificationStatus(driverId, AccountStatus.approved);
  Future<int> repairApprovedDriverPhotos() async => 0;
  Future<void> rejectDriver(String driverId, String reason) =>
      setDriverVerificationStatus(driverId, AccountStatus.rejected,
          reason: reason);
  Future<void> updateDriverLocation(String driverId, double lat, double lng) =>
      saveDriverLocation(userId: driverId, latitude: lat, longitude: lng);

  Future<void> saveNotification(AppNotification notification) async {
    await _client.from('notifications').upsert({
      'id': notification.id,
      'user_id': notification.userId,
      'sender_id': _client.auth.currentUser?.id,
      'title': notification.title,
      'body': notification.body,
      'is_read': notification.isRead,
      'created_at': notification.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> pushNotification({
    required String userId,
    required String title,
    required String body,
    String? senderId,
    String? tripId,
  }) async {
    await _client.from('notifications').insert({
      'id': _uuid.v4(),
      'user_id': userId,
      'sender_id': senderId ?? _client.auth.currentUser?.id,
      'ride_id': tripId,
      'title': title,
      'body': body,
      'type': tripId == null ? 'general' : 'ride',
    });
  }

  Map<String, dynamic> _adminRole(AdminAccount admin) => {
        'user_id': admin.id,
        'role': admin.role == 'super_admin' ? 'super_admin' : 'admin',
        'status': admin.isDeactivated ? 'deactivated' : 'active',
        'department': admin.department,
        'permissions': admin.permissions
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'last_login_at': admin.lastLogin?.toUtc().toIso8601String(),
      };

  /// Provision through the existing server-side admin function. Calling
  /// Supabase Auth signUp from an administrator's browser can replace the
  /// current session with the newly created account before its role exists.
  Future<String> createAdminAccountSecure(
      AdminAccount admin, String password) async {
    final response = await _client.functions.invoke('admin-users', body: {
      'action': 'create',
      'email': admin.email.trim().toLowerCase(),
      'password': password,
      'fullName': admin.fullName.trim(),
      'role': admin.role,
      'department': admin.department,
      'permissions': admin.permissions
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    });
    if (response.status != 201) {
      throw StateError('Secure administrator creation failed '
          '(HTTP ${response.status}): ${response.data}');
    }
    final data = response.data;
    final userId = data is Map ? data['userId']?.toString() : null;
    if (userId == null || !Uuid.isValidUUID(fromString: userId)) {
      throw StateError('Secure administrator creation returned no valid UID.');
    }
    return userId;
  }

  Future<void> saveAdminAccount(AdminAccount admin) async {
    await _client.from('profiles').upsert({
      'id': admin.id,
      'full_name': admin.fullName,
      'email': admin.email.trim().toLowerCase(),
      'mobile': admin.mobile.trim().isEmpty ? null : admin.mobile.trim(),
      'account_status': admin.isDeactivated ? 'deactivated' : 'active',
    });
    await _client.from('admin_roles').upsert(_adminRole(admin));
  }

  Future<void> updateAdminAccount(AdminAccount admin) async {
    final response = await _client.functions.invoke('admin-users', body: {
      'action': 'update',
      'userId': admin.id,
      'email': admin.email,
      'fullName': admin.fullName,
      'role': admin.role,
      'status': admin.isDeactivated ? 'deactivated' : 'active',
      'department': admin.department,
      'permissions': admin.permissions.split(',').map((v) => v.trim()).toList(),
    });
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Administrator update failed.');
    }
  }

  Future<void> updateAdminProfile(String id, String fullName) async {
    await _client
        .from('profiles')
        .update({'full_name': fullName.trim()}).eq('id', id);
  }

  Future<void> deleteAdminAccount(String id) => deleteUser(id);

  Future<bool> isEmailInUse(String email) async =>
      await getUserByEmail(email) != null;

  AdminAccount _adminFromRow(Map<String, dynamic> row) {
    final profile = _one(row['profiles']) ?? const <String, dynamic>{};
    final permissions = row['permissions'] is List
        ? (row['permissions'] as List).join(',')
        : row['permissions']?.toString() ?? '';
    return AdminAccount.fromMap({
      'id': row['user_id'],
      'full_name': profile['full_name'],
      'email': profile['email'],
      'mobile': profile['mobile'],
      'role': row['role'],
      'status': row['status'],
      'department': row['department'],
      'permissions': permissions,
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'last_login': row['last_login_at'],
    });
  }

  Future<AdminAccount?> getAdminAccount(String id) async {
    // Do not embed profiles here. admin_roles has both user_id and created_by
    // foreign keys to profiles, which can make an embedded PostgREST request
    // ambiguous when its schema cache is stale.
    final row = await _client
        .from('admin_roles')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    if (row == null) return null;
    final profile = await _client
        .from('profiles')
        .select('id,full_name,email,mobile')
        .eq('id', id)
        .maybeSingle();
    return _adminFromRow({
      ...Map<String, dynamic>.from(row),
      'profiles': profile,
    });
  }

  Future<AdminAccount?> getAdminByEmail(String email) async {
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return profile == null ? null : getAdminAccount(profile['id'].toString());
  }

  Future<AdminAccount?> getAdminByMobile(String mobile) async {
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('mobile', mobile.trim())
        .maybeSingle();
    return profile == null ? null : getAdminAccount(profile['id'].toString());
  }

  Stream<List<AdminAccount>> streamAdminAccounts() =>
      Stream.fromFuture(getAdminAccountsOnce());

  Future<List<AdminAccount>> getAdminAccountsOnce() async {
    // Fetch separately instead of using profiles(*) embedding; see
    // getAdminAccount for the foreign-key ambiguity this avoids.
    final rows = await _client.from('admin_roles').select().order('created_at');
    if (rows.isEmpty) return [];
    final ids = rows.map((row) => row['user_id'].toString()).toList();
    final profileRows = await _client
        .from('profiles')
        .select('id,full_name,email,mobile')
        .inFilter('id', ids);
    final profilesById = <String, Map<String, dynamic>>{
      for (final profile in profileRows)
        profile['id'].toString(): Map<String, dynamic>.from(profile),
    };
    return rows.map((row) {
      final adminRole = Map<String, dynamic>.from(row);
      return _adminFromRow({
        ...adminRole,
        'profiles': profilesById[adminRole['user_id'].toString()],
      });
    }).toList();
  }

  Future<void> updateAdminStatus(String id, String status) async {
    final response = await _client.functions.invoke('admin-users', body: {
      'action': 'update',
      'userId': id,
      'status': status == 'disabled' ? 'deactivated' : status,
    });
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Administrator status update failed.');
    }
  }

  Future<void> updateAdminLastLogin(String id, DateTime timestamp) async {
    await _client.from('admin_roles').update({
      'last_login_at': timestamp.toUtc().toIso8601String(),
    }).eq('user_id', id);
  }

  Future<String?> getAdminUserId() async {
    final uid = _client.auth.currentUser?.id;
    return uid == null || await getAdminAccount(uid) == null ? null : uid;
  }

  AppNotification _notification(Map<String, dynamic> row) =>
      AppNotification.fromMap({
        'id': row['id'],
        'user_id': row['user_id'],
        'title': row['title'],
        'body': row['body'],
        'read': row['is_read'] == true ? 1 : 0,
        'created_at': _millis(row['created_at']),
      });

  Stream<List<AppNotification>> streamNotifications(String userId) =>
      realtimeQueryStream<List<AppNotification>>(
        client: _client,
        feature: 'notifications',
        table: 'notifications',
        filterDescription: 'user_id=$userId',
        filters: [
          PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
        ],
        fetch: () async {
          final rows = await _client
              .from('notifications')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          return rows
              .map((row) => _notification(Map<String, dynamic>.from(row)))
              .toList();
        },
      );

  Future<void> markNotificationsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('user_id', userId);
  }

  Future<void> saveMagicLink(Map<String, dynamic> link) =>
      Future.error(UnsupportedError(
          'Use Supabase Auth magic links; token tables are server-only.'));
  Future<({bool isValid, String? mobile, String? status})> verifyMagicLinkToken(
          String token) =>
      Future.error(UnsupportedError('Use Supabase Auth magic-link callbacks.'));

  Future<void> saveTransaction(WalletTransaction transaction) async {
    await _client.from('wallet_transactions').upsert({
      'id': transaction.id,
      'user_id': transaction.driverId,
      'ride_id': transaction.tripId,
      'type': transaction.type,
      'amount': transaction.amount,
      'description': transaction.description,
      'created_at': transaction.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> syncAllFromLocal(DatabaseService dbService) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Authentication required.');
    final db = await dbService.database;
    final users = await db.query('users', where: 'id = ?', whereArgs: [uid]);
    for (final row in users) {
      await updateUser(uid, {
        'full_name': row['full_name'],
        'mobile': row['mobile'],
        'email': row['email'],
        'address': row['address'],
      });
    }
  }

  static String? _uuidOrNull(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    return Uuid.isValidUUID(fromString: v) ? v : null;
  }

  Map<String, dynamic> _reportRow(FireReport report) => {
        'id': report.id,
        // reporter_id is a uuid FK; fall back to the authenticated session so
        // RLS (reporter_id = auth.uid()) is satisfied for non-admins.
        'reporter_id': _uuidOrNull(report.reporterId) ??
            _uuidOrNull(_client.auth.currentUser?.id),
        'reporter_name': report.reporterName,
        'reporter_role': report.reporterRole,
        'reporter_mobile': report.reporterMobile,
        'reported_user_id': _uuidOrNull(report.reportedUserId),
        'reported_user_name': report.reportedUserName,
        'reported_user_role': report.reportedUserRole,
        'ride_id': (report.rideId?.trim().isEmpty ?? true)
            ? null
            : report.rideId!.trim(),
        'type': report.type,
        'title': report.title,
        'description': report.description,
        'status': report.status,
        'priority': report.priority,
        'admin_notes': report.adminNotes,
        'resolution_summary': report.resolutionSummary,
        'resolved_by': _uuidOrNull(report.resolvedByAdminId),
        'created_at': report.createdAt.toUtc().toIso8601String(),
        // updated_at is NOT NULL DEFAULT now(); never send an explicit null.
        if (report.updatedAt != null)
          'updated_at': report.updatedAt!.toUtc().toIso8601String(),
        'resolved_at': report.resolvedAt?.toUtc().toIso8601String(),
      };

  FireReport _report(Map<String, dynamic> row) => FireReport.fromMap({
        ...row,
        'reporterId': row['reporter_id'],
        'reporterName': row['reporter_name'],
        'reporterRole': row['reporter_role'],
        'reportedUserId': row['reported_user_id'],
        'reportedUserName': row['reported_user_name'],
        'reportedUserRole': row['reported_user_role'],
        'rideId': row['ride_id'],
        'adminNotes': row['admin_notes'],
        'resolutionSummary': row['resolution_summary'],
        'resolvedByAdminId': row['resolved_by'],
      }, row['id']?.toString());

  Stream<List<FireReport>> streamAllReports({
    String? status,
    String? type,
    String? searchQuery,
  }) =>
      realtimeQueryStream<List<FireReport>>(
        client: _client,
        feature: 'admin_reports',
        table: 'reports',
        filterDescription: 'all report changes',
        fetch: () => _adminRead(
          'open_reports',
          'reports ordered by created_at',
          () async {
            dynamic dbQuery = _client.from('reports').select();
            if (status != null && status != 'all') {
              dbQuery = dbQuery.eq('status', status);
            }
            if (type != null && type != 'all') {
              dbQuery = dbQuery.eq('type', type);
            }
            final rows = await dbQuery.order('created_at', ascending: false);
            var reports = (rows as List)
                .map((row) => _report(Map<String, dynamic>.from(row)))
                .toList();
            final query = searchQuery?.trim().toLowerCase();
            if (query != null && query.isNotEmpty) {
              reports = reports
                  .where((report) =>
                      report.title.toLowerCase().contains(query) ||
                      report.description.toLowerCase().contains(query) ||
                      report.reporterName.toLowerCase().contains(query))
                  .toList();
            }
            return reports;
          },
        ),
      );

  /// Returns whether a ride exists in public.rides.
  Future<bool> rideExists(String rideId) async {
    final clean = rideId.trim();
    if (clean.isEmpty) return false;
    try {
      final res = await _client
          .from('rides')
          .select('id')
          .eq('id', clean)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[Reports] rideExists check error: $e');
      return false;
    }
  }

  /// Returns whether a profile exists in public.profiles.
  Future<bool> profileExists(String userId) async {
    final clean = userId.trim();
    if (clean.isEmpty) return false;
    if (!Uuid.isValidUUID(fromString: clean)) return false;
    try {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('id', clean)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[Reports] profileExists check error: $e');
      return false;
    }
  }

  Future<void> saveReport(FireReport report) async {
    String? validRideId;
    final rawRideId = report.rideId?.trim();
    if (rawRideId != null && rawRideId.isNotEmpty) {
      if (await rideExists(rawRideId)) {
        validRideId = rawRideId;
      }
    }
    final row = _reportRow(report.copyWith(rideId: validRideId));
    row['ride_id'] = validRideId;
    await _client.from('reports').upsert(row);
  }

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? notes,
    String? resolution,
    String? adminId,
    String? adminName,
  }) async {
    final current = await _client
        .from('reports')
        .select('admin_notes')
        .eq('id', reportId)
        .single();
    final existing =
        (current['admin_notes'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    if (notes != null && notes.trim().isNotEmpty) existing.add(notes.trim());

    final resolvedByUuid =
        _uuidOrNull(adminId) ?? _uuidOrNull(_client.auth.currentUser?.id);
    final isResolved = status == ReportStatus.resolved;

    final updateData = <String, dynamic>{
      'status': status,
      'admin_notes': existing,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (resolution != null) {
      updateData['resolution_summary'] =
          resolution.trim().isEmpty ? null : resolution.trim();
    }
    if (isResolved) {
      updateData['resolved_at'] = DateTime.now().toUtc().toIso8601String();
      if (resolvedByUuid != null) {
        updateData['resolved_by'] = resolvedByUuid;
      }
    } else {
      updateData['resolved_at'] = null;
      updateData['resolved_by'] = null;
    }

    final res = await _client
        .from('reports')
        .update(updateData)
        .eq('id', reportId)
        .select('id');
    if ((res as List).isEmpty) {
      throw StateError(
          'Report update failed: Report "$reportId" not found or update not permitted.');
    }
  }

  Future<void> addReportNote(String reportId, String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    final current = await _client
        .from('reports')
        .select('admin_notes')
        .eq('id', reportId)
        .single();
    final existing =
        (current['admin_notes'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    existing.add(trimmed);
    final res = await _client
        .from('reports')
        .update({
          'admin_notes': existing,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reportId)
        .select('id');
    if ((res as List).isEmpty) {
      throw StateError(
          'Failed to add note: Report "$reportId" not found or update not permitted.');
    }
  }

  /// New reports must use a plain INSERT: PostgREST UPSERT also requires the
  /// UPDATE RLS policy, which is admin-only on public.reports.
  ///
  /// Enforces referential integrity on `reports_ride_id_fkey` and
  /// `reports_reported_user_id_fkey` before INSERT to guarantee no PostgreSQL
  /// error 23503 foreign key exceptions occur.
  Future<void> createReport(FireReport report) async {
    String? validRideId;
    String description = report.description;

    final rawRideId = report.rideId?.trim();
    if (rawRideId != null && rawRideId.isNotEmpty) {
      final exists = await rideExists(rawRideId);
      if (exists) {
        validRideId = rawRideId;
      } else {
        // If an administrator manually entered an invalid Ride ID, reject with a clear error.
        if (report.reporterRole == 'admin') {
          throw ArgumentError(
            'The specified Ride ID ("$rawRideId") does not exist in the rides database. '
            'Please verify the Ride ID or leave it empty for a general report.',
          );
        }
        // If an end-user client app reported an issue on an offline/demo ride that only exists
        // in local SQLite cache, set ride_id = null so foreign key constraint reports_ride_id_fkey
        // passes, while preserving the referenced ID in the description for investigation.
        validRideId = null;
        description = '[Referenced Ride ID: $rawRideId]\n$description';
      }
    }

    String? validReportedUserId;
    final rawReportedUserId = _uuidOrNull(report.reportedUserId);
    if (rawReportedUserId != null) {
      final exists = await profileExists(rawReportedUserId);
      if (exists) {
        validReportedUserId = rawReportedUserId;
      } else {
        validReportedUserId = null;
      }
    }

    final sanitizedReport = report.copyWith(
      rideId: validRideId,
      reportedUserId: validReportedUserId,
      description: description,
    );

    final row = _reportRow(sanitizedReport);
    row['ride_id'] = validRideId;
    row['reported_user_id'] = validReportedUserId;
    row['description'] = description;

    await _client.from('reports').insert(row);
  }

  Future<void> suspendDriver(String driverId, String reason) =>
      _client.rpc('set_account_status', params: {
        'target_user': driverId,
        'new_status': AccountStatus.suspended,
        'reason': reason,
      });

  Future<void> reactivateDriver(String driverId) =>
      _client.rpc('set_account_status', params: {
        'target_user': driverId,
        'new_status': AccountStatus.active,
        'reason': null,
      });

  Future<int> repairApprovedDriverStatuses() async => 0;

  Future<void> setPassengerAccountStatus(
    String userId,
    String status, {
    String? reason,
  }) =>
      _client.rpc('set_account_status', params: {
        'target_user': userId,
        'new_status': status,
        'reason': reason,
      });

  Stream<List<Trip>> streamAllRides({
    String? status,
    String? searchQuery,
    int limit = 150,
  }) {
    final searchState =
        searchQuery?.trim().isNotEmpty == true ? 'text' : 'none';
    return realtimeQueryStream<List<Trip>>(
      client: _client,
      feature: 'admin_all_rides',
      table: 'rides',
      throttle: const Duration(seconds: 3),
      filterDescription: 'status=${status ?? 'all'};search=$searchState',
      fetch: () async {
        // PostgREST commonly caps a response at 1,000 rows. Fetch pages so
        // admin totals such as completed gross fares are not silently capped
        // by the API's default page size.
        final rows = <dynamic>[];
        var offset = 0;
        while (offset < limit) {
          final pageSize = (limit - offset) < 1000 ? limit - offset : 1000;
          var query = _client.from('rides').select('*');
          if (status != null && status != 'all') {
            query = query.eq('status', status);
          }

          final page = await query
              .order('created_at', ascending: false)
              .range(offset, offset + pageSize - 1);
          rows.addAll(page);
          if (page.length < pageSize) break;
          offset += page.length;
        }
        var trips =
            rows.map((row) => _trip(Map<String, dynamic>.from(row))).toList();

        final sq = searchQuery?.trim().toLowerCase();
        if (sq != null && sq.isNotEmpty) {
          trips = trips
              .where((trip) =>
                  trip.id.toLowerCase().contains(sq) ||
                  trip.passengerName.toLowerCase().contains(sq) ||
                  trip.pickupAddress.toLowerCase().contains(sq) ||
                  trip.dropoffAddress.toLowerCase().contains(sq))
              .toList();
        }
        return trips;
      },
    );
  }

  Stream<List<FirePayment>> streamAllPayments({
    String? status,
    String? method,
    String? searchQuery,
    int limit = 150,
  }) {
    final searchState =
        searchQuery?.trim().isNotEmpty == true ? 'text' : 'none';
    return realtimeQueryStream<List<FirePayment>>(
      client: _client,
      feature: 'admin_all_payments',
      table: 'payments',
      filterDescription:
          'status=${status ?? 'all'};method=${method ?? 'all'};search=$searchState',
      fetch: () async {
        var query = _client.from('payments').select('*');
        if (status != null && status != 'all') {
          query = query.eq('status', status);
        }
        if (method != null && method != 'all') {
          query = query.eq('method', method);
        }

        final rows =
            await query.order('created_at', ascending: false).limit(limit);
        var payments = rows
            .map((row) => _payment(Map<String, dynamic>.from(row)))
            .toList();

        final sq = searchQuery?.trim().toLowerCase();
        if (sq != null && sq.isNotEmpty) {
          payments = payments
              .where((payment) =>
                  payment.id.toLowerCase().contains(sq) ||
                  payment.rideId.toLowerCase().contains(sq) ||
                  (payment.reference?.toLowerCase().contains(sq) ?? false))
              .toList();
        }
        return payments;
      },
    );
  }

  Object? _databaseValue(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is num && value is int && value > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value)
          .toUtc()
          .toIso8601String();
    }
    return value;
  }

  String? _iso(Object? value) => _date(value)?.toUtc().toIso8601String();
}

const kActiveRideStatuses = [
  RideStatus.searching,
  RideStatus.accepted,
  RideStatus.arrived,
  RideStatus.started,
];
