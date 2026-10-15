import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/admin_account.dart';
import '../../models/app_user.dart';
import '../../models/firestore_models.dart';
import '../../models/report_model.dart';
import '../../models/admin_dashboard.dart';
import '../supabase_database_service.dart';

/// Compatibility facade for admin operations.
///
/// Canonical PostgreSQL mappings live in [SupabaseDatabaseService]. Keeping
/// this facade thin prevents obsolete table and camelCase field names from
/// leaking back into the web admin.
class SupabaseAdminService {
  SupabaseAdminService._();
  static final SupabaseAdminService instance = SupabaseAdminService._();

  final SupabaseDatabaseService _database = SupabaseDatabaseService.instance;
  SupabaseClient get _client => Supabase.instance.client;

  AdminOverviewResponse? _cachedOverview;
  DateTime? _lastOverviewFetchTime;

  String? _cachedAuthorizedToken;
  String? _cachedAuthorizedUid;
  DateTime? _lastAuthorizedTime;

  void cacheAuthorizedAdmin(String uid, String? token) {
    _cachedAuthorizedUid = uid;
    _cachedAuthorizedToken = token;
    _lastAuthorizedTime = DateTime.now();
  }

  void clearAuthCache() {
    _cachedAuthorizedUid = null;
    _cachedAuthorizedToken = null;
    _lastAuthorizedTime = null;
    _cachedOverview = null;
    _lastOverviewFetchTime = null;
  }

  Future<AdminOverviewResponse> getAdminOverview(
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedOverview != null &&
        _lastOverviewFetchTime != null) {
      if (now.difference(_lastOverviewFetchTime!) <
          const Duration(seconds: 45)) {
        return _cachedOverview!;
      }
    }

    try {
      // 1. Direct high-speed PostgreSQL RPC call (15-35ms)
      final rpcResult = await _client.rpc('get_admin_overview');
      if (rpcResult != null) {
        final response = AdminOverviewResponse.fromJson(
            Map<String, dynamic>.from(rpcResult as Map));
        _cachedOverview = response;
        _lastOverviewFetchTime = now;
        return response;
      }
    } catch (rpcError) {
      debugPrint(
          '[ADMIN OVERVIEW RPC NOTE] $rpcError, trying Edge Function fallback');
    }

    // 2. Fallback to Edge Function if RPC not reachable
    try {
      final response = await _client.functions.invoke('admin-overview');
      if (response.status == 200 && response.data != null) {
        final res = AdminOverviewResponse.fromJson(response.data);
        _cachedOverview = res;
        _lastOverviewFetchTime = now;
        return res;
      } else {
        throw Exception('Failed to load admin overview: ${response.status}');
      }
    } catch (e) {
      debugPrint('[ADMIN OVERVIEW ERROR] $e');
      if (_cachedOverview != null) return _cachedOverview!;
      rethrow;
    }
  }

  Future<List<AppUser>> getAdminPassengersPaginated({
    String query = '',
    String status = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'get_admin_passengers_paginated',
        params: {
          'search_term': query,
          'status_filter': status,
          'limit_val': limit,
          'offset_val': offset,
        },
      );
      final list = response as List;
      return list
          .map((e) => AppUser.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ADMIN PASSENGERS ERROR] $e');
      rethrow;
    }
  }

  Future<List<AppUser>> getAdminDriversPaginated({
    String query = '',
    String status = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'get_admin_drivers_paginated',
        params: {
          'search_term': query,
          'status_filter': status,
          'limit_val': limit,
          'offset_val': offset,
        },
      );
      final list = response as List;
      return list
          .map((e) => AppUser.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ADMIN DRIVERS ERROR] $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deletePassengerAccount(String userId) =>
      _deleteManagedAccount(userId: userId, accountType: 'passenger');

  Future<Map<String, dynamic>> deleteDriverAccount(String userId) =>
      _deleteManagedAccount(userId: userId, accountType: 'driver');

  Future<Map<String, dynamic>> _deleteManagedAccount({
    required String userId,
    required String accountType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-delete-account',
        body: {
          'targetUserId': userId,
          'accountType': accountType,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError(_functionErrorMessage(response.data));
      }
      final data = response.data;
      if (data is! Map) {
        throw StateError('Account deletion returned an invalid server result.');
      }
      _cachedOverview = null;
      _lastOverviewFetchTime = null;
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      throw StateError(_functionErrorMessage(error.details));
    }
  }

  String _functionErrorMessage(dynamic details) {
    dynamic value = details;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        // Keep the original response text below.
      }
    }
    if (value is Map && value['error'] != null) {
      return value['error'].toString();
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Secure account deletion failed.' : text;
  }

  Future<Map<String, dynamic>> saveToda(Map<String, dynamic> todaMap) =>
      _database.saveToda(todaMap);

  Future<void> deleteToda(String todaId) => _database.deleteToda(todaId);

  Future<void> saveTodaMembership({
    required String driverId,
    required String todaId,
  }) =>
      _database.saveTodaMembership(driverId: driverId, todaId: todaId);

  Future<void> saveTodaAssociation(TodaAssociation association) =>
      _database.saveTodaAssociation(association);

  Future<void> saveFareMatrix(FareMatrix matrix) =>
      _database.saveFareMatrix(matrix);

  Future<void> updateFareMatrix({
    required String vehicleType,
    required double baseFare,
    required double perKmRate,
  }) =>
      _database.updateFareMatrix(
        vehicleType: vehicleType,
        baseFare: baseFare,
        perKmRate: perKmRate,
      );

  Future<void> saveReport(FireReport report) => _database.saveReport(report);

  Future<void> createReport(FireReport report) =>
      _database.createReport(report);

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? notes,
    String? resolution,
    String? adminId,
    String? adminName,
  }) =>
      _database.updateReportStatus(
        reportId,
        status,
        notes: notes,
        resolution: resolution,
        adminId: adminId,
        adminName: adminName,
      );

  Future<void> addReportNote(String reportId, String note) =>
      _database.addReportNote(reportId, note);

  Future<bool> isCurrentAdminAuthorized([String? explicitUid]) async {
    final currentUser = _client.auth.currentUser;
    final currentSession = _client.auth.currentSession;
    final userId = explicitUid ?? currentUser?.id;
    if (currentUser == null || userId == null || currentUser.id != userId) {
      return false;
    }

    // Reuse verified session token if already authenticated recently within session
    if (_cachedAuthorizedUid == userId &&
        currentSession != null &&
        _cachedAuthorizedToken == currentSession.accessToken &&
        _lastAuthorizedTime != null &&
        DateTime.now().difference(_lastAuthorizedTime!) <
            const Duration(minutes: 15)) {
      return true;
    }

    try {
      final rows = await _client.rpc('admin_dashboard_authorization');
      if (rows is! List || rows.length != 1 || rows.first is! Map) {
        return false;
      }
      final role = Map<String, dynamic>.from(rows.first as Map);
      final isAuth = role['status'] == 'active' &&
          (role['role'] == 'admin' || role['role'] == 'super_admin');
      if (isAuth && currentSession != null) {
        cacheAuthorizedAdmin(userId, currentSession.accessToken);
      }
      return isAuth;
    } on PostgrestException catch (error) {
      // The UI remains generic, but browser development logs retain the real
      // server-side reason without exposing tokens or database errors to an
      // administrator in production.
      debugPrint('[ADMIN AUTH ERROR] code=${error.code} '
          'message=${error.message} details=${error.details} hint=${error.hint}');
      return false;
    } catch (error) {
      debugPrint('[ADMIN AUTH ERROR] type=${error.runtimeType} message=$error');
      return false;
    }
  }

  Future<void> ensureCurrentAdminAuthorized([String? explicitUid]) async {
    if (!await isCurrentAdminAuthorized(explicitUid)) {
      throw StateError(
          'The active Supabase session is not an authorized admin.');
    }
  }

  Future<void> saveAdminAccount(AdminAccount admin) =>
      _database.saveAdminAccount(admin);

  Future<String> createAdminAccountSecure(
          AdminAccount admin, String password) =>
      _database.createAdminAccountSecure(admin, password);

  Future<void> updateAdminAccount(AdminAccount admin) =>
      _database.updateAdminAccount(admin);

  Future<void> updateAdminProfile(String id, String fullName) =>
      _database.updateAdminProfile(id, fullName);

  Future<void> deleteAdminAccount(String id) =>
      _database.deleteAdminAccount(id);

  Future<AdminAccount?> getAdminAccount(String id) =>
      _database.getAdminAccount(id);

  Future<AdminAccount?> getAdminByEmail(String email) =>
      _database.getAdminByEmail(email);

  Future<AdminAccount?> getAdminByMobile(String mobile) =>
      _database.getAdminByMobile(mobile);

  Future<void> updateAdminStatus(String id, String status) =>
      _database.updateAdminStatus(id, status);

  Future<void> updateAdminLastLogin(String id, DateTime timestamp) =>
      _database.updateAdminLastLogin(id, timestamp);

  Future<String?> getAdminUserId() => _database.getAdminUserId();
}
