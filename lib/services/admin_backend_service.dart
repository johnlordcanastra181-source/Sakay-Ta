import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/supabase_auth_service.dart';
import 'package:sakay_ta/services/supabase_service.dart';

/// Service for developer-controlled admin account provisioning.
///
/// Communicates with Firebase Cloud Functions (Firebase Admin SDK) or
/// directly provisions via Firebase Authentication and Cloud Firestore
/// using secondary FirebaseApp instance to protect active developer sessions.
class AdminBackendService {
  AdminBackendService._();
  static final AdminBackendService instance = AdminBackendService._();

  /// Optional base URL for deployed Firebase Cloud Functions.
  /// Example: https://us-central1-sakay-ta.cloudfunctions.net
  String? cloudFunctionsBaseUrl;

  /// Optional developer secret for REST authentication
  String? developerSecret;

  /// Creates a new administrator account in Firebase Authentication
  /// and Cloud Firestore `admins/{uid}` collection.
  ///
  /// CRITICAL SECURITY: Passwords are used strictly for Firebase Auth credential
  /// creation and are NEVER stored in Cloud Firestore.
  Future<AdminAccount> createAdminAccount({
    required String name,
    required String email,
    required String password,
    String role = 'admin',
    String status = 'active',
    String department = 'Operations',
    String mobile = '',
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanRole = role == 'super_admin' ? 'super_admin' : 'admin';
    final cleanStatus = status == 'disabled' ? 'disabled' : 'active';

    if (cleanName.length < 2) {
      throw Exception('Admin name must be at least 2 characters long.');
    }
    if (!cleanEmail.contains('@')) {
      throw Exception('A valid email address is required.');
    }
    if (password.length < 6) {
      throw Exception(
          'Password must be at least 6 characters long for Firebase Authentication.');
    }

    // Attempt 1: Call Firebase Cloud Functions REST API if configured
    if (cloudFunctionsBaseUrl != null && cloudFunctionsBaseUrl!.isNotEmpty) {
      try {
        final url = Uri.parse('$cloudFunctionsBaseUrl/createAdminAccountRest');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (developerSecret != null) 'X-Developer-Secret': developerSecret!,
          },
          body: jsonEncode({
            'name': cleanName,
            'email': cleanEmail,
            'password': password,
            'role': cleanRole,
            'status': cleanStatus,
            'developerSecret': developerSecret,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final adminData = data['admin'] as Map<String, dynamic>;
          final uid = adminData['uid'] as String;

          final admin = AdminAccount(
            id: uid,
      fullName: cleanName,
email: cleanEmail,
            mobile: mobile,
            passwordHash: DatabaseService.hashPassword(password),
            role: cleanRole,
            status: cleanStatus == 'disabled'
                ? AccountStatus.deactivated
                : AccountStatus.active,
            permissions: cleanRole == 'super_admin'
                ? AdminPermissions.all
                : AdminPermissions.standardAdmin,
            department: department,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await DatabaseService.instance.createAdminAccount(admin);
          return admin;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['error'] ??
              'Cloud Function returned HTTP ${response.statusCode}');
        }
      } catch (cloudErr) {
        debugPrint(
            'AdminBackendService: Cloud Function invocation failed ($cloudErr). Falling back to direct Firebase provisioning.');
      }
    }

    // Direct / Local Fallback:
    // Uses SupabaseAuthService.createAdminAuthAccount (secondary FirebaseApp ensures developer session is preserved)
    // and SupabaseService to save admin document under `admins/{uid}`.
    final uid = await SupabaseAuthService.createAdminAuthAccount(
      email: cleanEmail,
      password: password,
            fullName: cleanName,
    );

    final now = DateTime.now();
    final admin = AdminAccount(
      id: uid ?? '',
      fullName: cleanName,
email: cleanEmail,
      mobile: mobile,
      passwordHash: DatabaseService.hashPassword(
          password), // For local offline SQLite only, NEVER Firestore
      role: cleanRole,
      status: cleanStatus == 'disabled'
          ? AccountStatus.deactivated
          : AccountStatus.active,
      permissions: cleanRole == 'super_admin'
          ? AdminPermissions.all
          : AdminPermissions.standardAdmin,
      department: department,
      createdAt: now,
      updatedAt: now,
    );

    // Save to Firestore admins/{uid} (toFirestoreMap() does NOT include password)
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.saveAdminAccount(admin);
    }

    // Save to local SQLite cache
    await DatabaseService.instance.createAdminAccount(admin);

    return admin;
  }
}
