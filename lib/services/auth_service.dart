import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../core/constants.dart';
import '../core/logger.dart';
import '../models/admin_account.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';
import '../models/philippine_address.dart';
import 'database_service.dart';
import 'account_remote_store.dart';
import 'supabase_auth_service.dart';
import 'supabase_service.dart';
import 'supabase/admin_service.dart';
import 'prefs_service.dart';

class AuthResult {
  final AppUser? user;
  final String? error;
  const AuthResult(this.user, this.error);
}

class AuthService {
  final DatabaseService db;
  final PrefsService prefs;
  final AccountRemoteStore? remoteStore;
  const AuthService(this.db, this.prefs, {this.remoteStore});
  AccountRemoteStore get _remote =>
      remoteStore ?? const SupabaseAccountRemoteStore();

  static Future<void> _authQueue = Future.value();

  /// Serializes sensitive authentication and SQLite user cache mutations to
  /// prevent race conditions when concurrent login/refresh/cache requests fire.
  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _authQueue = _authQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }).catchError((_) {});
    return completer.future;
  }

  static String hashPassword(String password) {
    return DatabaseService.hashPassword(password);
  }

  static bool verifyPassword(String password, String storedHash) {
    return DatabaseService.verifyPassword(password, storedHash);
  }

  static List<String> _mobileVariations(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return [];
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    final variations = <String>{clean, digits};
    if (digits.length >= 10) {
      final nat = digits.substring(digits.length - 10);
      variations.add(nat);
      variations.add('0$nat');
      variations.add('63$nat');
      variations.add('+63$nat');
      if (digits.length > 10) {
        variations.add('0$nat');
        variations.add('+$digits');
      }
    }
    return variations.toList();
  }

  Future<AuthResult> login({
    required String mobile,
    required String password,
    required String role,
  }) async {
    final cleanIdentifier = mobile.trim();
    if (_remote.isConfigured) {
      return _loginRemote(cleanIdentifier, password, role);
    }

    return _synchronized(() async {
      try {
        final admin = await db.getAdminByIdentifier(cleanIdentifier);
        if (admin != null) {
          if (!DatabaseService.verifyPassword(password, admin.passwordHash)) {
            return const AuthResult(null, 'wrong_password');
          }
          if (admin.isDeactivated) {
            return const AuthResult(null, 'account_deactivated');
          }
          var resolvedAdmin = admin;
          if (!admin.passwordHash.startsWith(r'$2')) {
            final upgradedHash = hashPassword(password);
            await db.updateAdminPassword(admin.id, upgradedHash);
            resolvedAdmin = admin.copyWith(passwordHash: upgradedHash);
          }
          return AuthResult(resolvedAdmin.toUser(), null);
        }
        final user = cleanIdentifier.contains('@')
            ? await _userByEmail(cleanIdentifier)
            : await _userByMobile(cleanIdentifier);
        if (user == null) return const AuthResult(null, 'no_user');
        if (!DatabaseService.verifyPassword(password, user.passwordHash)) {
          return const AuthResult(null, 'wrong_password');
        }
        var resolvedUser = user;
        if (!user.passwordHash.startsWith(r'$2')) {
          final upgradedHash = hashPassword(password);
          final database = await db.database;
          await database.update(
            'users',
            {'password_hash': upgradedHash},
            where: 'id = ?',
            whereArgs: [user.id],
          );
          resolvedUser = user.copyWith(passwordHash: upgradedHash);
        }
        final error = _accountLoginError(resolvedUser, role);
        return error == null
            ? AuthResult(resolvedUser, null)
            : AuthResult(null, error);
      } catch (e, s) {
        AppLogger.debug('AuthService: local login error ($e)',
            error: e, stackTrace: s);
        return const AuthResult(null, 'profile_unavailable');
      }
    });
  }

  Future<AuthResult> _loginRemote(
      String identifier, String password, String role) async {
    try {
      AppUser? cached;
      if (!identifier.contains('@')) {
        final database = await db.database;
        final variations = _mobileVariations(identifier);
        final rows = await database.query('users',
            where:
                'mobile IN (${List.filled(variations.length, '?').join(',')})',
            whereArgs: variations,
            limit: 1);
        if (rows.isNotEmpty) cached = AppUser.fromMap(rows.first);
      }
      final uid = await _remote.signIn(identifier, password,
          alternateIdentifiers: [if (cached?.email != null) cached!.email!]);

      // Supabase Auth verifies the password. The profile tables below decide
      // which role the authenticated UUID is permitted to use.
      final validation = _remote is SupabaseAccountRemoteStore
          ? await _validateSupabaseRole(uid, role)
          : await _validateRemoteRole(uid, role);
      if (validation.error != null || validation.user == null) {
        return validation;
      }

      // ── Role-aware fast path ────────────────────────────────────────────────
      // Admin accounts live in `admin_accounts`, NOT `users`.  Querying the
      // users collection for an admin wastes up to 9 s (5 s + 4 s timeouts)
      // before finally checking the right collection.  We therefore split the
      // primary UID resolution based on the requested role so each role only
      // searches the collection it belongs to.
      AppUser? user = validation.user;
      // A validated Supabase session is already represented by
      // `validation.user`. Retain this legacy lookup only for non-Supabase
      // remote-store implementations used by older integrations.
      if (_remote is! SupabaseAccountRemoteStore && role == UserRole.admin) {
        // Admin fast path: check admin_accounts first, skip users collection.
        final admin = await _remote.getAdmin(uid);
        user = admin?.toUser();
        if (user == null && SupabaseService.isConfigured) {
          // Also search admin by identifier if UID doc is missing.
          try {
            if (identifier.contains('@')) {
              final a =
                  await SupabaseService.instance.getAdminByEmail(identifier);
              user = a?.toUser();
            } else {
              final a =
                  await SupabaseService.instance.getAdminByMobile(identifier);
              user = a?.toUser();
            }
          } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
        }
        // Local DB fallback for admin.
        if (user == null) {
          try {
            final localAdmin = await db.getAdminByIdentifier(identifier) ??
                await db.getAdminById(uid);
            user = localAdmin?.toUser();
          } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
        }
      } else if (_remote is! SupabaseAccountRemoteStore) {
        // Passenger / driver fast path: check users collection first.
        user = await _remote.getUser(uid);

        // 1. If not found by UID, search by email or mobile identifier in Firestore
        if (user == null && SupabaseService.isConfigured) {
          try {
            if (identifier.contains('@')) {
              user = await SupabaseService.instance.getUserByEmail(identifier);
            } else {
              user = await SupabaseService.instance.getUserByMobile(identifier);
              if (user == null) {
                final syntheticEmail = SupabaseAuthService.emailFor(identifier);
                user = await SupabaseService.instance
                    .getUserByEmail(syntheticEmail);
              }
            }
          } catch (e) {
            debugPrint('AuthService: Firestore search by identifier note ($e)');
          }
        }

        // 2. Search local SQLite database for existing account or uid
        if (user == null) {
          try {
            user = cached ??
                (identifier.contains('@')
                    ? await _userByEmail(identifier)
                    : await _userByMobile(identifier)) ??
                await _userById(uid);
          } catch (e) {
            debugPrint('AuthService: local db lookup note ($e)');
          }
        }
      }

      user = validation.user;

      // A profile that does not exist after authentication is never silently
      // created here. The signup/trigger flow owns profile creation.
      if (user == null && _remote is SupabaseAccountRemoteStore) {
        try {
          final fbUser = Supabase.instance.client.auth.currentUser;
          if (fbUser != null) {
            final userEmail = identifier.contains('@')
                ? identifier.trim().toLowerCase()
                : (fbUser.email ?? SupabaseAuthService.emailFor(identifier));
            final userMobile = !identifier.contains('@')
                ? identifier.trim()
                : ((fbUser.userMetadata?['phone'] as String?) ?? '');
            final displayName =
                ((fbUser.userMetadata?['full_name'] as String?) != null &&
                        (fbUser.userMetadata?['full_name'] as String?)!
                            .trim()
                            .isNotEmpty)
                    ? (fbUser.userMetadata?['full_name'] as String?)!.trim()
                    : (userEmail.isNotEmpty && userEmail.contains('@')
                        ? userEmail.split('@').first
                        : 'User');
            final resolvedRole = (role == 'admin' || role == 'driver')
                ? role
                : UserRole.passenger;

            user = AppUser(
              id: uid,
              fullName: displayName,
              email: userEmail.isNotEmpty ? userEmail : null,
              mobile: userMobile,
              role: resolvedRole,
              status: AccountStatus.active,
              createdAt: DateTime.now(),
              passwordHash: hashPassword(password),
            );

            // Persist self-healed user to Firestore so it's permanently stored
            try {
              await _remote.saveUser(user);
            } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
            if (SupabaseService.isConfigured) {
              try {
                await SupabaseService.instance.saveUser(user);
              } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
            }

            // If driver, initialize default driver profile
            if (resolvedRole == UserRole.driver) {
              final defaultDriver = DriverProfile(
                userId: uid,
                vehicleType: VehicleType.tricycle,
                submittedAt: DateTime.now(),
              );
              try {
                await _remote.saveDriverProfile(defaultDriver);
              } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
              try {
                final database = await db.database;
                await database.insert('drivers', defaultDriver.toMap(),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
            } else if (resolvedRole == UserRole.admin) {
              final adminAccount = AdminAccount(
                id: uid,
                fullName: displayName,
                email: userEmail,
                mobile: userMobile,
                passwordHash: hashPassword(password),
                role: UserRole.admin,
                status: AccountStatus.active,
                createdAt: DateTime.now(),
              );
              try {
                await db.createAdminAccount(adminAccount);
              } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
              if (SupabaseService.isConfigured) {
                try {
                  await SupabaseService.instance.saveAdminAccount(adminAccount);
                } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
              }
            }
          }
        } catch (e) {
          debugPrint('AuthService: self-heal profile note ($e)');
        }
      }

      if (user == null) return const AuthResult(null, 'profile_not_found');
      var resolvedUser = user;

      // If driver shows pending, check if drivers collection or cloud was approved
      if (resolvedUser.isDriver &&
          resolvedUser.status == AccountStatus.pending &&
          SupabaseService.isConfigured) {
        try {
          final vRaw =
              await SupabaseService.instance.getDriverVerificationStatus(uid) ??
                  await SupabaseService.instance
                      .getDriverVerificationStatus(resolvedUser.id);
          final cloudUser = await SupabaseService.instance.getUser(uid) ??
              await SupabaseService.instance.getUser(resolvedUser.id);
          final vStatus = (vRaw ?? cloudUser?.status)?.toLowerCase().trim();
          if (vStatus == AccountStatus.approved ||
              vStatus == AccountStatus.active) {
            resolvedUser =
                resolvedUser.copyWith(status: AccountStatus.approved);
            unawaited(SupabaseService.instance.updateUser(uid, {
              'status': AccountStatus.approved,
              'verificationStatus': AccountStatus.approved,
              'verification_status': AccountStatus.approved,
            }).catchError((Object e, StackTrace s) {
              AppLogger.debug('AuthService: updateUser status note ($e)',
                  error: e, stackTrace: s);
            }));
            if (resolvedUser.id != uid) {
              unawaited(SupabaseService.instance.updateUser(resolvedUser.id, {
                'status': AccountStatus.approved,
                'verificationStatus': AccountStatus.approved,
                'verification_status': AccountStatus.approved,
              }).catchError((Object e, StackTrace s) {
                AppLogger.debug('AuthService: updateUser legacy id note ($e)',
                    error: e, stackTrace: s);
              }));
            }
            await _cacheUser(resolvedUser);
          }
        } catch (e, s) {
          AppLogger.debug('AuthService: driver status sync note ($e)',
              error: e, stackTrace: s);
        }
      }

      final error = _accountLoginError(resolvedUser, role);
      if (error != null) return AuthResult(null, error);
      resolvedUser =
          resolvedUser.copyWith(id: uid, passwordHash: hashPassword(password));
      // Verify the canonical database/RLS role before a local admin session is
      // persisted. This makes a backend authorization regression fail at login
      // instead of surfacing as unrelated dashboard-card errors.
      if (resolvedUser.isAdmin) {
        await SupabaseService.instance.ensureCurrentAdminAuthorized(uid);
      }
      // Persist session and local cache concurrently for faster login completion.
      await Future.wait([
        _cacheUser(resolvedUser),
        prefs.saveSession(uid, resolvedUser.role),
      ]);
      if (resolvedUser.isAdmin) {
        unawaited(_recordAdminLogin(uid).catchError((Object e, StackTrace s) {
          AppLogger.debug('AuthService: _recordAdminLogin note ($e)',
              error: e, stackTrace: s);
        }));
      }
      return AuthResult(resolvedUser, null);
    } on AuthException catch (e) {
      return AuthResult(
          null,
          switch (e.code) {
            'network-request-failed' => 'network_unavailable',
            'too-many-requests' => 'too_many_requests',
            'user-disabled' => 'account_deactivated',
            'invalid_credentials' ||
            'invalid-credentials' ||
            'invalid-credential' =>
              'wrong_password',
            'email_not_confirmed' => 'Exception: Email address not verified.',
            _ => 'Exception: ${e.message}',
          });
    } on StateError {
      // The Supabase remote store reaches this branch only after every
      // supplied identifier fails password authentication. A cached profile
      // must never be used to create a session in that case.
      return AuthResult(
        null,
        identifier.contains('@') ? 'wrong_password' : 'use_registered_email',
      );
    } on TimeoutException catch (e) {
      debugPrint('AuthService: cloud profile lookup timed out ($e)');
      return const AuthResult(null, 'network_unavailable');
    } catch (e) {
      debugPrint('AuthService: login error (${e.runtimeType})');
      return const AuthResult(null, 'Unable to sign in. Please try again.');
    }
  }

  Future<AuthResult> _validateSupabaseRole(String uid, String role) async {
    final client = Supabase.instance.client;

    // Run profile and role checks concurrently to eliminate sequential waterfall
    final profileFuture =
        client.from('profiles').select().eq('id', uid).maybeSingle();
    final adminFuture = role == UserRole.admin
        ? client
            .from('admin_roles')
            .select('role,status')
            .eq('user_id', uid)
            .maybeSingle()
        : Future<Map<String, dynamic>?>.value(null);

    final results = await Future.wait([profileFuture, adminFuture]);
    final profileRow = results[0];
    final adminRoleRow = results[1];

    if (profileRow == null) {
      debugPrint('[LOGIN] profileFound=false');
      return const AuthResult(null, 'profile_not_found');
    }
    debugPrint('[LOGIN] profileFound=true');

    final profile = AppUser.fromMap(Map<String, Object?>.from(profileRow));
    final profileStatus =
        (profileRow['account_status'] ?? 'active').toString().toLowerCase();
    if (profileStatus == 'deactivated' || profileStatus == 'suspended') {
      return const AuthResult(null, 'account_deactivated');
    }

    if (role == UserRole.admin) {
      if (adminRoleRow == null || adminRoleRow['status'] != 'active') {
        return const AuthResult(null, 'wrong_role');
      }
      // Register verified session token in cache for instant router validation
      final token = client.auth.currentSession?.accessToken;
      if (token != null) {
        SupabaseAdminService.instance.cacheAuthorizedAdmin(uid, token);
      }
      return AuthResult(
          profile.copyWith(
            role: adminRoleRow['role'].toString(),
            status: profileStatus,
          ),
          null);
    }

    if (role == UserRole.driver) {
      var driver = await client
          .from('drivers')
          .select('application_status')
          .eq('user_id', uid)
          .maybeSingle();

      if (driver == null) {
        // Fallback to check if they are in driver_applications
        final applicant = await client
            .from('driver_applications')
            .select('status')
            .eq('auth_user_id', uid)
            .maybeSingle();
        if (applicant == null) return const AuthResult(null, 'wrong_role');
        driver = {'application_status': applicant['status']};
      }

      final driverStatus =
          driver['application_status'].toString().toLowerCase();
      if (driverStatus == 'pending') return const AuthResult(null, 'pending');
      if (driverStatus == 'rejected') return const AuthResult(null, 'rejected');
      if (driverStatus == 'suspended' || driverStatus == 'deactivated') {
        return const AuthResult(null, 'account_deactivated');
      }
      if (driverStatus != 'approved' && driverStatus != 'active') {
        return const AuthResult(null, 'wrong_role');
      }
      return AuthResult(
          profile.copyWith(
            role: UserRole.driver,
            status: driverStatus,
          ),
          null);
    }

    final admin = await client
        .from('admin_roles')
        .select('user_id')
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (admin != null) return const AuthResult(null, 'wrong_role');

    var passenger = await client
        .from('passenger_profiles')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle();
    debugPrint('[LOGIN] passengerProfileFound=${passenger != null}');
    if (passenger == null) {
      final isDriver = await client
          .from('drivers')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      if (isDriver == null) {
        try {
          await client.from('passenger_profiles').upsert({'user_id': uid});
          passenger = {'user_id': uid};
          debugPrint(
              '[LOGIN] self-healed missing passenger_profiles for uid=$uid');
        } catch (e) {
          debugPrint('[LOGIN] failed to self-heal passenger_profiles ($e)');
        }
      }
    }
    if (passenger == null) return const AuthResult(null, 'wrong_role');
    return AuthResult(
        profile.copyWith(
          role: UserRole.passenger,
          status: profileStatus,
        ),
        null);
  }

  /// The test/local remote-store contract exposes a role-resolved AppUser
  /// rather than database tables. Production uses [_validateSupabaseRole].
  Future<AuthResult> _validateRemoteRole(String uid, String role) async {
    final user = role == UserRole.admin
        ? (await _remote.getAdmin(uid))?.toUser()
        : await _remote.getUser(uid);
    if (user == null) return const AuthResult(null, 'profile_not_found');
    final error = _accountLoginError(user, role);
    return error == null ? AuthResult(user, null) : AuthResult(null, error);
  }

  static String? _accountLoginError(AppUser user, String role) {
    if (user.isDeactivated || user.status == 'suspended') {
      return 'account_deactivated';
    }
    // `super_admin` is accepted as an administrator, but an administrator is
    // never implicitly a passenger or driver.
    if (role == UserRole.admin) {
      if (!user.isAdmin) return 'wrong_role';
    } else if (user.role != role) {
      return 'wrong_role';
    }
    if (user.isDriver && user.status == AccountStatus.pending) return 'pending';
    if (user.isDriver && user.status == AccountStatus.rejected) {
      return 'rejected';
    }
    return null;
  }

  Future<void> _recordAdminLogin(String adminId) async {
    final timestamp = DateTime.now();
    await Future.wait([
      (() async {
        try {
          await db.updateAdminLastLogin(
              adminId, timestamp.millisecondsSinceEpoch);
        } catch (e) {
          debugPrint('AuthService: updateAdminLastLogin local db note ($e)');
        }
      })(),
      (() async {
        if (!SupabaseService.isConfigured) return;
        try {
          await SupabaseService.instance
              .updateAdminLastLogin(adminId, timestamp);
        } catch (e) {
          debugPrint('AuthService: updateAdminLastLogin cloud note ($e)');
        }
      })(),
    ]);
  }

  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    if (SupabaseService.isConfigured) {
      try {
        final cloudInUse =
            await SupabaseService.instance.isEmailInUse(cleanEmail);
        return cloudInUse;
      } catch (e) {
        debugPrint('AuthService: isEmailInUse cloud check failed ($e)');
        // If RLS blocks enumeration, we fail closed for the pre-check
        // and let Supabase Auth signUp handle the real authoritative check.
      }
    }
    return (await _userByEmail(cleanEmail)) != null;
  }

  Future<bool> isMobileRegistered(String mobile) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty) return false;
    if (SupabaseService.isConfigured) {
      try {
        final cloud =
            await SupabaseService.instance.getUserByMobile(cleanMobile);
        return cloud != null;
      } catch (e) {
        debugPrint('AuthService: isMobileRegistered cloud check failed ($e)');
      }
    }
    return (await _userByMobile(cleanMobile)) != null;
  }

  Future<AppUser?> getUserById(String id) => _userById(id);
  Future<AppUser?> getUserByEmail(String email) => _userByEmail(email);
  Future<AppUser?> getUserByMobile(String mobile) => _userByMobile(mobile);

  Future<AppUser?> _userById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    if (SupabaseService.isConfigured) {
      try {
        final cloud = await SupabaseService.instance.getUser(cleanId);
        if (cloud != null) return cloud;
      } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'users',
        where: 'id = ?',
        whereArgs: [cleanId],
        limit: 1,
      );
      if (rows.isNotEmpty) return AppUser.fromMap(rows.first);
    } catch (e) {
      debugPrint('AuthService: _userById local db note ($e)');
    }
    return null;
  }

  Future<AppUser?> _userByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    if (SupabaseService.isConfigured) {
      try {
        final cloud = await SupabaseService.instance.getUserByEmail(cleanEmail);
        if (cloud != null) return cloud;
      } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'users',
        where: 'email = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );
      if (rows.isNotEmpty) return AppUser.fromMap(rows.first);
    } catch (e) {
      debugPrint('AuthService: _userByEmail local db note ($e)');
    }
    return null;
  }

  Future<AppUser?> _userByMobile(String mobile) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty) return null;
    if (SupabaseService.isConfigured) {
      try {
        final cloud =
            await SupabaseService.instance.getUserByMobile(cleanMobile);
        if (cloud != null) return cloud;
      } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    final variations = _mobileVariations(cleanMobile);
    try {
      final database = await db.database;
      final placeholders = List.filled(variations.length, '?').join(', ');
      final rows = await database.query(
        'users',
        where: 'mobile IN ($placeholders)',
        whereArgs: variations,
        limit: 1,
      );
      if (rows.isNotEmpty) return AppUser.fromMap(rows.first);
    } catch (e) {
      debugPrint('AuthService: _userByMobile local db note ($e)');
    }
    return null;
  }

  Future<AppUser?> registerPassenger({
    required String fullName,
    required String mobile,
    required String password,
    String? email,
    PhilippineAddress? address,
  }) async {
    final database = await db.database;
    final cleanMobile = mobile.trim();
    final cleanEmail = email?.trim().toLowerCase();

    if (_remote.isConfigured && _remote is SupabaseAccountRemoteStore) {
      final client = Supabase.instance.client;
      var authUser = client.auth.currentUser;
      if (authUser == null) {
        if (cleanEmail == null || cleanEmail.isEmpty) {
          throw StateError(
              'An email address is required to create a passenger account.');
        }
        authUser = await SupabaseAuthService.createAuthenticatedAccount(
          email: cleanEmail,
          password: password,
          fullName: fullName,
          mobile: cleanMobile,
        );
      }
      if (client.auth.currentSession == null ||
          client.auth.currentUser?.id != authUser.id) {
        throw StateError(
            'Your new account has no active authenticated session. Please retry.');
      }
      if (cleanEmail != null &&
          cleanEmail.isNotEmpty &&
          authUser.email?.trim().toLowerCase() != cleanEmail) {
        throw StateError(
            'The active account does not match the registration email.');
      }
      return _registerRemote(
          fullName: fullName,
          mobile: cleanMobile,
          password: password,
          email: cleanEmail,
          address: address);
    }
    if (_remote.isConfigured) {
      return _registerRemote(
          fullName: fullName,
          mobile: cleanMobile,
          password: password,
          email: cleanEmail,
          address: address);
    }
    _requireAccountServiceOnPhone();

    // Check if user already exists by email or mobile
    AppUser? existingUser;
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      existingUser = await _userByEmail(cleanEmail);
    }
    if (existingUser == null && cleanMobile.isNotEmpty) {
      existingUser = await _userByMobile(cleanMobile);
    }

    if (existingUser != null) {
      final updatedUser = existingUser.copyWith(
        fullName: fullName.isNotEmpty ? fullName : existingUser.fullName,
        mobile: cleanMobile.isNotEmpty ? cleanMobile : existingUser.mobile,
        email: cleanEmail ?? existingUser.email,
        emailVerified: true,
        passwordHash: password.isNotEmpty
            ? hashPassword(password)
            : existingUser.passwordHash,
        address: address?.formattedAddress ?? existingUser.address,
      );
      await database.update(
        'users',
        updatedUser.toMap(),
        where: 'id = ?',
        whereArgs: [existingUser.id],
      );
      if (address != null && address.isComplete) {
        try {
          await database.rawUpdate(
            'UPDATE users SET address = ? WHERE id = ?',
            [address.formattedAddress, existingUser.id],
          );
        } catch (e) {
          AppLog.w('AuthService', 'Address column update note ($e)');
        }
      }
      if (SupabaseService.isConfigured) {
        await SupabaseService.instance.saveUser(updatedUser);
        await SupabaseService.instance.savePassengerProfile(
          existingUser.id,
          initialize: false,
          defaultAddress: address?.formattedAddress,
          savedAddresses: address != null && address.isComplete
              ? [address.formattedAddress]
              : null,
          address: address,
        );
      }
      await prefs.saveSession(existingUser.id, updatedUser.role);
      return updatedUser;
    }

    final id = _newLocalAccountId();
    final user = AppUser(
      id: id,
      fullName: fullName,
      mobile: cleanMobile,
      email: cleanEmail,
      emailVerified: cleanEmail != null,
      passwordHash: hashPassword(password),
      role: UserRole.passenger,
      createdAt: DateTime.now(),
      address: address?.formattedAddress,
    );
    await database.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (address != null && address.isComplete) {
      try {
        await database.rawUpdate(
          'UPDATE users SET address = ? WHERE id = ?',
          [address.formattedAddress, id],
        );
      } catch (e) {
        AppLog.w('AuthService', 'Address column insert note ($e)');
      }
    }

    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.saveUser(user);
      await SupabaseService.instance.savePassengerProfile(
        id,
        initialize: true,
        defaultAddress: address?.formattedAddress,
        savedAddresses: address != null && address.isComplete
            ? [address.formattedAddress]
            : null,
        address: address,
      );
    }
    await prefs.saveSession(id, user.role);
    return user;
  }

  Future<AppUser?> registerDriver({
    required String fullName,
    required String mobile,
    required String password,
    required DriverProfile profile,
    String? email,
  }) async {
    final database = await db.database;
    final cleanMobile = mobile.trim();
    final cleanEmail = email?.trim().toLowerCase();

    if (_remote.isConfigured && _remote is SupabaseAccountRemoteStore) {
      final authUser = await SupabaseAuthService.createAuthenticatedAccount(
        email: cleanEmail ?? '',
        password: password,
        fullName: fullName,
        mobile: cleanMobile,
      );
      final user = AppUser(
        id: authUser.id,
        fullName: fullName,
        mobile: cleanMobile,
        email: cleanEmail,
        role: UserRole.driver,
        status: AccountStatus.pending,
        createdAt: DateTime.now(),
        passwordHash: hashPassword(password),
      );
      await _cacheUser(user);
      return user;
    }
    if (_remote.isConfigured) {
      return _registerRemote(
          fullName: fullName,
          mobile: cleanMobile,
          password: password,
          email: cleanEmail,
          profile: profile);
    }
    _requireAccountServiceOnPhone();

    AppUser? existingUser;
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      existingUser = await _userByEmail(cleanEmail);
    }
    if (existingUser == null && cleanMobile.isNotEmpty) {
      existingUser = await _userByMobile(cleanMobile);
    }

    final now = DateTime.now();
    final id = existingUser?.id ?? _newLocalAccountId();
    final user = AppUser(
      id: id,
      fullName: fullName,
      mobile: cleanMobile,
      email: cleanEmail,
      emailVerified: cleanEmail != null,
      passwordHash: password.isNotEmpty
          ? hashPassword(password)
          : (existingUser?.passwordHash ?? ''),
      role: UserRole.driver,
      status: AccountStatus.pending,
      createdAt: existingUser?.createdAt ?? now,
    );
    final updatedProfile = profile.copyWith(userId: id, submittedAt: now);
    if (existingUser != null) {
      await database.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await database.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await database.insert(
      'drivers',
      updatedProfile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.saveUser(user);
      await SupabaseService.instance.saveDriverProfile(updatedProfile);
      // Record the driver's TODA membership for the association registry.
      final todaId = updatedProfile.todaId;
      if (todaId != null && todaId.isNotEmpty) {
        await SupabaseService.instance
            .saveTodaMembership(driverId: id, todaId: todaId);
      }
    }
    return user;
  }

  /// Resolves the authenticated identity used by a driver application.
  ///
  /// New applicants create a normal Supabase email/password account here.
  /// The application can then be submitted without an email OTP; approval is
  /// still controlled by the `drivers.application_status` lifecycle.
  Future<AppUser> prepareDriverApplicant({
    required String fullName,
    required String mobile,
    required String email,
    required String password,
  }) async {
    throw StateError(
      'Driver application submission no longer creates an Auth account. Use the secure application submission endpoint.',
    );
  }

  /// Establishes the single authenticated session used by the remainder of a
  /// driver application. No driver row is created here; that happens only on
  /// the final application submit.
  Future<AppUser> signInFinalizedDriver({
    required String expectedUserId,
    required String email,
    required String password,
    required String fullName,
    required String mobile,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Registration is temporarily unavailable.');
    }
    final client = Supabase.instance.client;
    final response = await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final authUser = response.user;
    if (authUser == null ||
        authUser.id != expectedUserId ||
        client.auth.currentSession == null) {
      throw StateError(
          'Unable to establish the authenticated account session.');
    }
    final profile = await client
        .from('profiles')
        .select('id,account_status')
        .eq('id', expectedUserId)
        .maybeSingle();
    if (profile == null) {
      throw StateError('Your account setup is incomplete.');
    }
    final user = AppUser(
      id: expectedUserId,
      fullName: fullName.trim(),
      mobile: mobile.trim(),
      email: email.trim().toLowerCase(),
      emailVerified: true,
      passwordHash: '',
      role: UserRole.driver,
      status: profile['account_status']?.toString() ?? AccountStatus.pending,
      createdAt: DateTime.now(),
    );
    await Future.wait([
      _cacheUser(user),
      prefs.saveSession(user.id, user.role),
    ]);
    AppLog.i('AuthService', '[DRIVER AUTH] stage=session_ready success');
    return user;
  }

  /// Updates the offline cache only after the authoritative Supabase
  /// application transaction has committed.
  Future<void> cacheSubmittedDriver(AppUser user, DriverProfile profile) async {
    final database = await db.database;
    await database.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await database.insert('drivers', profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _cacheUser(user);
  }

  /// Establishes the first normal password session after the trusted signup
  /// function has atomically created Auth, profile, and passenger rows.
  Future<AppUser> signInFinalizedPassenger({
    required String expectedUserId,
    required String email,
    required String password,
    required String fullName,
    required String mobile,
    PhilippineAddress? address,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Registration is temporarily unavailable.');
    }
    final client = Supabase.instance.client;
    final response = await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final authUser = response.user;
    if (authUser == null || authUser.id != expectedUserId) {
      throw StateError('Unable to establish the new account session.');
    }

    final profile = await client
        .from('profiles')
        .select('id,account_status')
        .eq('id', expectedUserId)
        .maybeSingle();
    final passenger = await client
        .from('passenger_profiles')
        .select('user_id')
        .eq('user_id', expectedUserId)
        .maybeSingle();
    if (profile == null || passenger == null) {
      throw StateError('Your account setup is incomplete. Please try again.');
    }

    final user = AppUser(
      id: expectedUserId,
      fullName: fullName.trim(),
      mobile: mobile.trim(),
      email: email.trim().toLowerCase(),
      emailVerified: authUser.emailConfirmedAt != null,
      passwordHash: '',
      role: UserRole.passenger,
      status: profile['account_status']?.toString() ?? AccountStatus.active,
      createdAt: DateTime.now(),
      address: address?.formattedAddress,
    );
    await Future.wait([
      _cacheUser(user),
      prefs.saveSession(user.id, user.role),
    ]);
    AppLog.i('AuthService', '[SIGNUP] stage=normal_password_login success');
    return user;
  }

  /// Compatibility handler for legacy callers that already have a session.
  ///
  /// Validates that the authenticated signup already produced both canonical
  /// records before updating passenger-editable fields. It never creates an
  /// Auth identity, profile, or passenger row without that session.
  Future<AppUser?> completePassengerProfile({
    required String email,
    required String fullName,
    required String mobile,
    PhilippineAddress? address,
  }) async {
    AppLog.i('AuthService', '[SIGNUP] stage=profile_creation email=$email');

    try {
      // Get the current authenticated user. Registration never falls back to
      // an email lookup because the canonical Auth UUID owns the profile.
      var authUser = Supabase.instance.client.auth.currentUser;

      // If there is no session, profile completion cannot be authorized safely.
      if (authUser == null) {
        AppLog.w('AuthService',
            '[SIGNUP] no active session, profile completion skipped');
        return null;
      }

      final uid = authUser.id;

      final client = Supabase.instance.client;
      final profile = await client
          .from('profiles')
          .select('id,account_status')
          .eq('id', uid)
          .maybeSingle();
      final passenger = await client
          .from('passenger_profiles')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      if (profile == null || passenger == null) {
        AppLog.w('AuthService',
            '[SIGNUP] finalized contract missing uid=$uid profile=${profile != null} passenger=${passenger != null}');
        return null;
      }

      // Update only the fields a passenger may control. The mirrored email,
      // account status, and verification state remain owned by Auth/admin.
      final profilePayload = <String, dynamic>{
        'full_name': fullName.isNotEmpty ? fullName : null,
        'mobile': mobile.isNotEmpty ? mobile : null,
        'address': address?.formattedAddress,
      };
      profilePayload.removeWhere((k, v) => v == null);

      try {
        await client.from('profiles').update(profilePayload).eq('id', uid);
        AppLog.i(
            'AuthService', '[SIGNUP] stage=profile_completion profile updated');
      } catch (e) {
        AppLog.w('AuthService',
            '[SIGNUP ERROR] stage=profile_creation type=${e.runtimeType}');
      }

      // Update the already-finalized passenger row with the default address.
      if (address != null && address.isComplete) {
        try {
          await client.from('passenger_profiles').update({
            'default_address': address.formattedAddress,
          }).eq('user_id', uid);
        } catch (e) {
          AppLog.w('AuthService',
              '[SIGNUP ERROR] stage=passenger_profile type=${e.runtimeType}');
        }
      }

      final now = DateTime.now();
      final user = AppUser(
        id: uid,
        fullName: fullName,
        mobile: mobile,
        email: email,
        emailVerified: true,
        passwordHash: '',
        role: UserRole.passenger,
        status: AccountStatus.active,
        createdAt: now,
        address: address?.formattedAddress,
      );

      await _cacheUser(user);
      await prefs.saveSession(uid, user.role);
      AppLog.i('AuthService', '[SIGNUP] stage=complete user=$uid');
      return user;
    } catch (e, st) {
      AppLog.e('AuthService', '[SIGNUP ERROR] stage=profile_creation', e, st);
      return null;
    }
  }

  void _requireAccountServiceOnPhone() {
    if (!_remote.isConfigured &&
        !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS)) {
      throw StateError(
          'Account service is unavailable. Connect to the internet '
          'and try again. Your account has not been created.');
    }
  }

  String _newLocalAccountId() =>
      'local_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  static final Random _random = Random();

  Future<AppUser> _registerRemote(
      {required String fullName,
      required String mobile,
      required String password,
      String? email,
      PhilippineAddress? address,
      DriverProfile? profile}) async {
    if (profile != null && _remote is SupabaseAccountRemoteStore) {
      throw StateError(
        'A Driver profile cannot be created before Admin approval.',
      );
    }
    // Auth signup must be followed by an authenticated session before any
    // RLS-protected profile, passenger, or driver write is attempted.
    final isSupabaseRemote = _remote is SupabaseAccountRemoteStore;
    final client = isSupabaseRemote ? Supabase.instance.client : null;
    var authUser = client?.auth.currentUser;
    final uid = authUser != null
        ? authUser.id
        : await _remote.createAccount(mobile, password, email);
    if (isSupabaseRemote) {
      authUser = client!.auth.currentUser;
      if (client.auth.currentSession == null || authUser?.id != uid) {
        throw StateError(
            'Account creation returned no active authenticated session.');
      }
    }

    final role = profile == null ? UserRole.passenger : UserRole.driver;

    // For a first passenger registration, do not reload the profile through an
    // embedded admin_roles relationship before saving it. admin_roles has both
    // user_id and created_by foreign keys to profiles and that extra read can
    // fail with PGRST201 even though Auth signup succeeded.
    final isAuthenticatedPassengerSignup =
        profile == null && isSupabaseRemote && authUser?.id == uid;
    if (isAuthenticatedPassengerSignup) {
      final session = client!.auth.currentSession;
      final confirmedUser = client.auth.currentUser;
      if (session == null || confirmedUser?.id != uid) {
        throw StateError(
            'The new account has no active authenticated session.');
      }

      final user = AppUser(
        id: uid,
        fullName: fullName.trim(),
        mobile: mobile.trim(),
        email: email?.trim().toLowerCase(),
        emailVerified: confirmedUser!.emailConfirmedAt != null,
        // Supabase Auth is the only password authority. The local profile
        // cache intentionally contains no password-derived credential.
        passwordHash: '',
        role: UserRole.passenger,
        status: AccountStatus.approved,
        createdAt: DateTime.now(),
        address: address?.formattedAddress,
      );

      // The auth.users trigger is the sole creator of `profiles`. After
      // signup, update that trigger-owned row by canonical UUID.
      // In particular, do not upsert or send `email_verified`: it is an Auth
      // controlled column and an upsert can require INSERT privileges even
      // though the row is already present.
      final profileUpdate = <String, Object?>{
        'full_name': user.fullName,
        'mobile': user.mobile.isEmpty ? null : user.mobile,
        'address': user.address,
      }..removeWhere((_, value) => value == null);
      await client
          .from('profiles')
          .update(profileUpdate)
          .eq('id', uid)
          .select('id')
          .single();
      AppLog.i('AuthService', '[SIGNUP] stage=profile_setup success uid=$uid');

      // Passenger capability is created exactly once. The primary key and
      // own-row RLS policy make retries idempotent without creating a driver.
      final passengerPayload = <String, Object?>{
        'user_id': uid,
        if (user.address?.isNotEmpty == true) 'default_address': user.address,
      };
      await client
          .from('passenger_profiles')
          .upsert(passengerPayload)
          .select('user_id')
          .single();
      AppLog.i('AuthService',
          '[SIGNUP] stage=passenger_profile_setup success uid=$uid');
      await Future.wait([
        _cacheUser(user),
        prefs.saveSession(uid, user.role),
      ]);
      return user;
    }

    final existing = await _remote.getUser(uid);
    if (existing != null) {
      // A retry after a reinstall must keep the original profile and approval.
      if (existing.role != role ||
          existing.isDeactivated ||
          existing.status == 'suspended') {
        throw StateError(
            'This account already exists. Please log in or contact support.');
      }
      final needsProfileCompletion = existing.fullName.trim().isEmpty ||
          existing.mobile.trim().isEmpty ||
          existing.address?.trim().isEmpty != false;
      final user = existing.copyWith(
        id: uid,
        fullName: existing.fullName.trim().isEmpty
            ? fullName.trim()
            : existing.fullName,
        mobile:
            existing.mobile.trim().isEmpty ? mobile.trim() : existing.mobile,
        email: email?.trim().isEmpty == false
            ? email!.trim().toLowerCase()
            : existing.email,
        emailVerified: isSupabaseRemote
            ? client!.auth.currentUser?.emailConfirmedAt != null
            : existing.emailVerified,
        address: existing.address?.trim().isEmpty == false
            ? existing.address
            : address?.formattedAddress,
        passwordHash: hashPassword(password),
      );
      if (profile != null) {
        final database = await db.database;
        await database.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        var driver = await _remote.getDriverProfile(uid);
        if (driver == null) {
          if (existing.status != AccountStatus.pending) {
            throw StateError(
                'The saved driver profile is missing. Contact support.');
          }
          // Finish a signup whose user write succeeded but profile write failed.
          driver =
              profile.copyWith(userId: uid, submittedAt: existing.createdAt);
          await _remote.saveDriverProfile(driver);
        }
        await _cacheUser(user);
        await database.insert('drivers', driver.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        final database = await db.database;
        await database.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        if (_remote is SupabaseAccountRemoteStore && needsProfileCompletion) {
          await _remote.saveUser(user);
        }
        await _remote.savePassengerProfile(
          uid,
          address,
          initialize: false,
        );
      }
      await _cacheUser(user);
      if (profile == null) await prefs.saveSession(uid, user.role);
      return user;
    }
    final now = DateTime.now();
    final user = AppUser(
        id: uid,
        fullName: fullName,
        mobile: mobile,
        email: email,
        emailVerified: email != null,
        passwordHash: hashPassword(password),
        role: role,
        status:
            profile == null ? AccountStatus.approved : AccountStatus.pending,
        createdAt: now,
        address: address?.formattedAddress);
    // Server acknowledgement is required before reporting successful signup.
    await _remote.saveUser(user);
    final database = await db.database;
    await database.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (profile != null) {
      final driver = profile.copyWith(userId: uid, submittedAt: now);
      // Parallelize profile cloud save, local cache, and local DB insert.
      await Future.wait([
        _remote.saveDriverProfile(driver),
        _cacheUser(user),
        database.insert('drivers', driver.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace),
      ]);
    } else {
      // Parallelize passenger profile cloud save, local cache, and session.
      await Future.wait([
        _remote.savePassengerProfile(uid, address),
        _cacheUser(user),
        prefs.saveSession(uid, user.role),
      ]);
    }
    return user;
  }

  Future<AppUser?> restoreSession() async {
    var userId = await prefs.sessionUserId;
    if (userId == null && SupabaseService.isConfigured) {
      try {
        userId = Supabase.instance.client.auth.currentUser?.id;
      } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    if (userId == null) return null;
    final database = await db.database;
    final rows = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final localUser = AppUser.fromMap(rows.first);
      await prefs.saveSession(localUser.id, localUser.role);
      return localUser;
    }
    // If local database was cleared or user is admin, attempt to restore user from Firestore / Supabase
    if (SupabaseService.isConfigured) {
      final cloudUser = await SupabaseService.instance.getUser(userId);
      if (cloudUser != null) {
        await _cacheUser(cloudUser);
        await prefs.saveSession(cloudUser.id, cloudUser.role);
        await syncUserFromCloud(userId);
        return cloudUser;
      }
      final cloudAdmin = await SupabaseService.instance.getAdminAccount(userId);
      if (cloudAdmin != null) {
        final adminUser = cloudAdmin.toUser();
        await _cacheUser(adminUser);
        await prefs.saveSession(adminUser.id, adminUser.role);
        return adminUser;
      }
    }
    final localAdmin = await db.getAdminById(userId);
    if (localAdmin != null) {
      final adminUser = localAdmin.toUser();
      await _cacheUser(adminUser);
      await prefs.saveSession(adminUser.id, adminUser.role);
      return adminUser;
    }

    await prefs.clearSession();
    return null;
  }

  Future<void> logout() async {
    SupabaseAdminService.instance.clearAuthCache();
    await prefs.clearSession();
    // Sign out of Supabase Auth when configured (non-blocking).
    unawaited(
        SupabaseAuthService.signOut().catchError((Object e, StackTrace s) {
      AppLogger.debug('AuthService: signOut note ($e)',
          error: e, stackTrace: s);
    }));
  }

  /// Permanently deletes the passenger or driver account from backend and local database.
  Future<void> deleteAccount(String userId) async {
    // 1. Delete from Cloud Firestore
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.deleteUser(userId);
    }
    // 2. Delete from local SQLite database
    try {
      final database = await db.database;
      await database.delete('users', where: 'id = ?', whereArgs: [userId]);
      await database
          .delete('drivers', where: 'user_id = ?', whereArgs: [userId]);
      await database.delete('trip',
          where: 'passenger_id = ? OR driver_id = ?',
          whereArgs: [userId, userId]);
      await database
          .delete('saved_places', where: 'user_id = ?', whereArgs: [userId]);
      await database.delete('emergency_contacts',
          where: 'user_id = ?', whereArgs: [userId]);
      await database
          .delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
      await database
          .delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
    } catch (e) {
      debugPrint('AuthService: deleteAccount local db note ($e)');
    }
    // 3. Clear session and sign out
    await prefs.clearSession();
    unawaited(
        SupabaseAuthService.signOut().catchError((Object e, StackTrace s) {
      AppLogger.debug('AuthService: deleteAccount signOut note ($e)',
          error: e, stackTrace: s);
    }));
  }

  /// Downloads user details, past trips, and profile data from the cloud into local SQLite.
  Future<void> syncUserFromCloud(String userId) async {
    if (!SupabaseService.isConfigured) return;
    try {
      final database = await db.database;
      // 1. Sync User profile
      final cloudUser = await SupabaseService.instance.getUser(userId);
      if (cloudUser != null) {
        await _cacheUser(cloudUser);
      }

      // 2. Sync Past Trips/Rides
      final cloudTrips =
          await SupabaseService.instance.getPassengerTrips(userId);
      for (final trip in cloudTrips) {
        await database.insert(
          'trip',
          trip.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. Sync Driver Profile if applicable
      if (cloudUser != null && cloudUser.isDriver) {
        final driverProfile =
            await SupabaseService.instance.getDriverProfile(userId);
        if (driverProfile != null) {
          await database.insert(
            'drivers',
            driverProfile.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (e) {
      debugPrint('AuthService: syncUserFromCloud note ($e)');
    }
  }

  Future<AppUser?> getUser(String id) async {
    if (SupabaseService.isConfigured) {
      try {
        final cloud = await SupabaseService.instance.getUser(id);
        if (cloud != null) {
          unawaited(_cacheUser(cloud).catchError((Object e, StackTrace s) {
            AppLogger.debug('AuthService: getUser cache cloud note ($e)',
                error: e, stackTrace: s);
          }));
          return cloud;
        }
        final cloudAdmin = await SupabaseService.instance.getAdminAccount(id);
        if (cloudAdmin != null) {
          final adminUser = cloudAdmin.toUser();
          unawaited(_cacheUser(adminUser).catchError((Object e, StackTrace s) {
            AppLogger.debug('AuthService: getUser cache admin note ($e)',
                error: e, stackTrace: s);
          }));
          return adminUser;
        }
      } catch (e, s) {
        AppLogger.debug('AuthService: getUser cloud lookup note ($e)',
            error: e, stackTrace: s);
      }
    }

    try {
      final database = await db.database;
      final rows = await database.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return AppUser.fromMap(rows.first);
      }
    } catch (e) {
      debugPrint('AuthService: getUser local db note ($e)');
    }

    final localAdmin = await db.getAdminById(id);
    if (localAdmin != null) {
      return localAdmin.toUser();
    }

    return null;
  }

  Future<void> updateUser(AppUser user) async {
    try {
      final database = await db.database;
      await database
          .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
    } catch (e, s) {
      AppLogger.debug('AuthService: updateUser local note ($e)',
          error: e, stackTrace: s);
    }
    try {
      await SupabaseService.instance.saveUser(user);
    } catch (e, s) {
      AppLogger.debug('AuthService: updateUser remote note ($e)',
          error: e, stackTrace: s);
    }
  }

  Future<void> updateDriverProfile(DriverProfile profile) async {
    try {
      final database = await db.database;
      await database.insert(
        'drivers',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, s) {
      AppLogger.debug('AuthService: updateDriverProfile local note ($e)',
          error: e, stackTrace: s);
    }
    if (SupabaseService.isConfigured) {
      try {
        await SupabaseService.instance.updateDriverProfile(profile);
      } catch (e, s) {
        AppLogger.debug('AuthService: updateDriverProfile remote note ($e)',
            error: e, stackTrace: s);
      }
    }
  }

  Future<void> _cacheUser(AppUser user) => _synchronized(() async {
        try {
          final database = await db.database;
          await database.insert('users', user.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e, s) {
          AppLogger.debug('AuthService: _cacheUser note ($e)',
              error: e, stackTrace: s);
        }
      });

  Future<void> setOnline(String userId, bool online) async {
    try {
      final database = await db.database;
      await database.update(
        'users',
        {'is_online': online ? 1 : 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint('AuthService: setOnline local db note ($e)');
    }
    try {
      final user = await getUser(userId);
      if (user != null) {
        await SupabaseService.instance.saveUser(user);
      }
    } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
  }

  /// Persists a driver's last known GPS coordinates to the local database
  /// (offline source of truth for the nearby-drivers search).
  Future<void> saveDriverLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final database = await db.database;
      await database.update(
        'users',
        {'latitude': latitude, 'longitude': longitude},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      debugPrint('AuthService: saveDriverLocation local db note ($e)');
    }
  }

  Future<DriverProfile?> getDriverProfile(String userId) async {
    if (SupabaseService.isConfigured) {
      try {
        final profile = await SupabaseService.instance.getDriverProfile(userId);
        if (profile != null) return profile;
      } catch (e, s) {
      AppLogger.debug('AuthService non-fatal note: $e', error: e, stackTrace: s);
    }
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'drivers',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isNotEmpty) return DriverProfile.fromMap(rows.first);
    } catch (e) {
      debugPrint('AuthService: getDriverProfile local db note ($e)');
    }
    return null;
  }

  Future<List<AppUser>> listDrivers({String? status}) async {
    if (SupabaseService.isConfigured) {
      try {
        final drivers =
            await SupabaseService.instance.streamDrivers(status: status).first;
        if (drivers.isNotEmpty) return drivers;
      } catch (e) {
        debugPrint('AuthService: listDrivers cloud note ($e)');
      }
    }
    try {
      final database = await db.database;
      final rows = status == null
          ? await database.query(
              'users',
              where: 'role = ?',
              whereArgs: [UserRole.driver],
              orderBy: 'created_at DESC',
            )
          : await database.query(
              'users',
              where: 'role = ? AND status = ?',
              whereArgs: [UserRole.driver, status],
              orderBy: 'created_at DESC',
            );
      return rows.map(AppUser.fromMap).toList();
    } catch (e) {
      debugPrint('AuthService: listDrivers note ($e)');
      return [];
    }
  }

  Future<List<AppUser>> listPassengers() async {
    if (SupabaseService.isConfigured) {
      try {
        final passengers =
            await SupabaseService.instance.streamPassengers().first;
        if (passengers.isNotEmpty) return passengers;
      } catch (e) {
        debugPrint('AuthService: listPassengers cloud note ($e)');
      }
    }
    try {
      final database = await db.database;
      final rows = await database.query(
        'users',
        where: 'role = ?',
        whereArgs: [UserRole.passenger],
        orderBy: 'created_at DESC',
      );
      return rows.map(AppUser.fromMap).toList();
    } catch (e) {
      debugPrint('AuthService: listPassengers note ($e)');
      return [];
    }
  }

  Future<List<AppUser>> listDriversByVehicle(VehicleType type) async {
    if (SupabaseService.isConfigured) {
      try {
        final drivers = await SupabaseService.instance
            .getOnlineDrivers(vehicleType: type.key);
        if (drivers.isNotEmpty) return drivers;
      } catch (e) {
        debugPrint('AuthService: listDriversByVehicle cloud note ($e)');
      }
    }
    try {
      final database = await db.database;
      final keys = await database.rawQuery(
        'SELECT user_id FROM drivers WHERE vehicle_type = ?',
        [type.key],
      );
      if (keys.isEmpty) return [];
      final ids = keys.map((e) => e['user_id'] as String).toList();
      final rows = await database.query(
        'users',
        where:
            'role = ? AND status = ? AND is_online = 1 AND id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: [UserRole.driver, AccountStatus.approved, ...ids],
      );
      return rows.map(AppUser.fromMap).toList();
    } catch (e) {
      debugPrint('AuthService: listDriversByVehicle note ($e)');
      return [];
    }
  }

  Future<void> setDriverStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    if (SupabaseService.isConfigured) {
      try {
        if (status == AccountStatus.approved) {
          await SupabaseService.instance.approveDriver(userId);
        } else if (status == AccountStatus.rejected) {
          await SupabaseService.instance.rejectDriver(userId, reason ?? '');
        } else {
          await SupabaseService.instance
              .setDriverVerificationStatus(userId, status, reason: reason);
        }
      } catch (e) {
        debugPrint('AuthService: cloud setDriverStatus note ($e)');
        rethrow;
      }
    }
    try {
      final database = await db.database;
      if (status == AccountStatus.rejected) {
        // Preserve passenger account status when rejecting a driver application
        await database.update(
          'users',
          {
            'status': status,
            'rejection_reason': reason,
            'verified_at': null,
          },
          where: 'id = ? AND role = ?',
          whereArgs: [userId, UserRole.driver],
        );
        await database.update(
          'users',
          {
            'rejection_reason': reason,
          },
          where: 'id = ? AND role != ?',
          whereArgs: [userId, UserRole.driver],
        );
      } else {
        await database.update(
          'users',
          {
            'status': status,
            'rejection_reason': reason,
            'verified_at': status == AccountStatus.approved
                ? DateTime.now().millisecondsSinceEpoch
                : null,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    } catch (e) {
      debugPrint('AuthService: setDriverStatus local db note ($e)');
    }
    try {
      final user = await getUser(userId);
      if (user != null) {
        final effectiveStatus =
            (status == AccountStatus.rejected && !user.isDriver)
                ? user.status
                : status;
        final updated = user.copyWith(
          status: effectiveStatus,
          rejectionReason: reason,
          verifiedAt: status == AccountStatus.approved ? DateTime.now() : null,
        );
        await _cacheUser(updated);
        if (SupabaseService.isConfigured) {
          await SupabaseService.instance.saveUser(updated);
        }
      }
    } catch (e, s) {
      AppLogger.debug('AuthService: setDriverStatus cache note ($e)',
          error: e, stackTrace: s);
    }
  }

  Future<List<AppUser>> findDrivers({required String vehicleType}) async {
    if (SupabaseService.isConfigured) {
      try {
        final drivers = await SupabaseService.instance
            .getOnlineDrivers(vehicleType: vehicleType);
        if (drivers.isNotEmpty) return drivers;
      } catch (e) {
        debugPrint('AuthService: findDrivers cloud note ($e)');
      }
    }
    try {
      final database = await db.database;
      return await database.rawQuery(
        'SELECT u.* FROM users u JOIN drivers d ON d.user_id = u.id '
        'WHERE u.role = ? AND u.status = ? AND u.is_online = 1 AND d.vehicle_type = ?',
        [UserRole.driver, AccountStatus.approved, vehicleType],
      ).then((rows) => rows.map(AppUser.fromMap).toList());
    } catch (e) {
      debugPrint('AuthService: findDrivers note ($e)');
      return [];
    }
  }

  Future<AppUser?> randomOnlineDriver(VehicleType type) async {
    final drivers = await findDrivers(vehicleType: type.key);
    if (drivers.isEmpty) return null;
    return drivers[Random().nextInt(drivers.length)];
  }
}
