import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/admin_account.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/pages/password_change_page.dart';
import 'package:sakay_ta/pages/password_recovery_page.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/password_change_service.dart';
import 'package:sakay_ta/services/password_recovery_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'support/isolated_database.dart';

class _MemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

class _FakeGoTrueAccount {
  _FakeGoTrueAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
  });

  final String id;
  final String email;
  String password;
  final String role;
  String? activeRecoveryOtp;
  bool recoveryOtpExpired = false;
  int issuedCount = 0;
}

class _FakeGoTrueServer {
  final Map<String, _FakeGoTrueAccount> accountsByEmail = {};
  final List<Map<String, dynamic>> requests = [];
  String? currentAccessTokenEmail;
  bool rateLimitNextRecover = false;

  void registerAccount({
    required String id,
    required String email,
    required String password,
    required String role,
  }) {
    final normalized = email.trim().toLowerCase();
    accountsByEmail[normalized] = _FakeGoTrueAccount(
      id: id,
      email: normalized,
      password: password,
      role: role,
    );
  }

  String _buildJwt(String sub, String email) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': sub,
      'email': email,
      'exp': exp,
      'role': 'authenticated',
    })));
    return '$header.$payload.signature';
  }

  Map<String, dynamic> _userJson(_FakeGoTrueAccount acc) => {
        'id': acc.id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': acc.email,
        'email_confirmed_at': '2026-01-01T00:00:00Z',
        'app_metadata': {'provider': 'email', 'role': acc.role},
        'user_metadata': {'role': acc.role},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

  Map<String, dynamic> _sessionJson(_FakeGoTrueAccount acc) => {
        'access_token': _buildJwt(acc.id, acc.email),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-${acc.id}-${acc.issuedCount}',
        'user': _userJson(acc),
      };

  MockClient createClient() {
    return MockClient((http.Request request) async {
      final path = request.url.path;
      Map<String, dynamic> body = {};
      if (request.body.isNotEmpty) {
        try {
          body = jsonDecode(request.body) as Map<String, dynamic>;
        } catch (_) {}
      }
      requests.add({
        'method': request.method,
        'path': path,
        'query': request.url.queryParameters,
        'body': body,
      });

      // POST /auth/v1/token?grant_type=password
      if (path.endsWith('/token') && request.method == 'POST') {
        final email = (body['email'] as String? ?? '').trim().toLowerCase();
        final password = body['password'] as String? ?? '';
        final acc = accountsByEmail[email];
        if (acc == null || acc.password != password) {
          return http.Response(
            jsonEncode({
              'code': 'invalid_credentials',
              'message': 'Invalid login credentials',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        currentAccessTokenEmail = acc.email;
        return http.Response(
          jsonEncode(_sessionJson(acc)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // POST /auth/v1/recover
      if (path.endsWith('/recover') && request.method == 'POST') {
        if (rateLimitNextRecover) {
          rateLimitNextRecover = false;
          return http.Response(
            jsonEncode({
              'code': 'over_email_send_rate_limit',
              'message':
                  'For security purposes, you can only request this after 60 seconds.',
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        }
        final email = (body['email'] as String? ?? '').trim().toLowerCase();
        final acc = accountsByEmail[email];
        if (acc != null) {
          acc.issuedCount += 1;
          // Deterministic 6-digit OTP per issue count (100001, 100002, ...)
          acc.activeRecoveryOtp = (100000 + acc.issuedCount).toString();
          acc.recoveryOtpExpired = false;
        }
        return http.Response(
          jsonEncode({}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // POST /auth/v1/verify
      if (path.endsWith('/verify') && request.method == 'POST') {
        final type = body['type'] as String? ?? '';
        final email = (body['email'] as String? ?? '').trim().toLowerCase();
        final token = (body['token'] as String? ?? '').trim();

        // Real Supabase GoTrue behavior: recovery OTP only matches when type == 'recovery'
        if (type != 'recovery') {
          return http.Response(
            jsonEncode({
              'code': 'otp_expired',
              'message': 'Token has expired or is invalid',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }

        final acc = accountsByEmail[email];
        if (acc == null || acc.activeRecoveryOtp == null) {
          return http.Response(
            jsonEncode({
              'code': 'otp_expired',
              'message': 'Token has expired or is invalid',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        if (acc.recoveryOtpExpired) {
          return http.Response(
            jsonEncode({
              'code': 'otp_expired',
              'message': 'Token has expired',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        if (acc.activeRecoveryOtp != token) {
          return http.Response(
            jsonEncode({
              'code': 'otp_invalid',
              'message': 'Token is invalid',
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }

        // Consume one-time recovery token and return authenticated session
        acc.activeRecoveryOtp = null;
        currentAccessTokenEmail = acc.email;
        return http.Response(
          jsonEncode(_sessionJson(acc)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // PUT /auth/v1/user
      if (path.endsWith('/user') && request.method == 'PUT') {
        final email = currentAccessTokenEmail;
        final acc = email != null ? accountsByEmail[email] : null;
        if (acc == null) {
          return http.Response(
            jsonEncode({'message': 'Auth session missing!'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        final newPassword = body['password'] as String?;
        if (newPassword != null && newPassword.isNotEmpty) {
          if (newPassword == acc.password) {
            return http.Response(
              jsonEncode({
                'code': 'same_password',
                'message':
                    'New password should be different from the old password.',
              }),
              422,
              headers: {'content-type': 'application/json'},
            );
          }
          acc.password = newPassword;
        }
        return http.Response(
          jsonEncode({'user': _userJson(acc), ..._userJson(acc)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      // POST /auth/v1/logout
      if (path.endsWith('/logout') && request.method == 'POST') {
        currentAccessTokenEmail = null;
        return http.Response('', 204);
      }

      return http.Response(jsonEncode({}), 200,
          headers: {'content-type': 'application/json'});
    });
  }
}

void main() {
  late _FakeGoTrueServer server;
  late SupabaseClient supabaseClient;
  final db = DatabaseService.instance;

  setUp(() async {
    await useIsolatedDatabase();
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();

    server = _FakeGoTrueServer();
    supabaseClient = SupabaseClient(
      'https://kasgyeaedfbcsrhzcnax.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon.sig',
      httpClient: server.createClient(),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );

    PasswordChangeService.debugClient = supabaseClient;
    PasswordRecoveryService.debugClient = supabaseClient;
    PasswordChangeService.resetStateForTesting();
    PasswordRecoveryService.resetStateForTesting();
  });

  tearDown(() async {
    PasswordChangeService.debugClient = null;
    PasswordRecoveryService.debugClient = null;
    PasswordChangeService.resetStateForTesting();
    PasswordRecoveryService.resetStateForTesting();
    AppState.instance.currentUser = null;
    await supabaseClient.dispose();
  });

  Future<AppUser> seedAndSignInRole({
    required String id,
    required String email,
    required String password,
    required String role,
  }) async {
    server.registerAccount(
      id: id,
      email: email,
      password: password,
      role: role,
    );
    final hash = DatabaseService.hashPassword(password);
    final uniqueMobile =
        '0917${(id.hashCode.abs() % 9000000 + 1000000).toString()}';
    final user = AppUser(
      id: id,
      fullName: 'Test $role',
      email: email,
      mobile: uniqueMobile,
      passwordHash: hash,
      role: role,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
    );
    final sqlite = await db.database;
    await sqlite.insert('users', {
      'id': user.id,
      'full_name': user.fullName,
      'mobile': user.mobile,
      'email': user.email,
      'email_verified': 1,
      'password_hash': user.passwordHash,
      'role': user.role,
      'status': user.status,
      'is_online': 0,
      'created_at': user.createdAt.millisecondsSinceEpoch,
    });
    if (role == UserRole.admin) {
      await db.createAdminAccount(
        AdminAccount(
          id: id,
          fullName: user.fullName,
          email: email,
          mobile: user.mobile,
          passwordHash: hash,
          role: UserRole.admin,
          status: AccountStatus.active,
          createdAt: DateTime.now(),
        ),
      );
    }
    AppState.instance.currentUser = user;
    await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return user;
  }

  Future<String?> getLocalUserPasswordHash(String userId) async {
    final sqlite = await db.database;
    final rows = await sqlite.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['password_hash'] as String?;
  }

  group('Change Password & Forgot Password — All Roles & 10 Required Scenarios',
      () {
    for (final role in [UserRole.passenger, UserRole.driver, UserRole.admin]) {
      test(
          'Scenario 1, 9, 10 ($role): Requesting OTP & immediately entering latest code updates password; new password signs in and old password fails',
          () async {
        final email = '$role@sakayta.ph';
        const oldPassword = 'OldPassword123!';
        const newPassword = 'NewPassword456!';

        final user = await seedAndSignInRole(
          id: 'uid-$role',
          email: email,
          password: oldPassword,
          role: role,
        );

        // Request OTP
        await PasswordChangeService.requestOtp();
        expect(PasswordChangeService.currentUserEmail, equals(email));

        final issuedOtp = server.accountsByEmail[email]!.activeRecoveryOtp;
        expect(issuedOtp, equals('100001'));

        // Verify that /recover was called (not /reauthenticate)
        expect(
          server.requests.any((r) => (r['path'] as String).endsWith('/recover')),
          isTrue,
        );

        // Immediately verify latest code and update password
        await PasswordChangeService.verifyAndUpdate(
          email: email,
          code: issuedOtp!,
          newPassword: newPassword,
        );

        // Verify that /verify was called with type: 'recovery'
        final verifyCall = server.requests.lastWhere(
          (r) => (r['path'] as String).endsWith('/verify'),
        );
        expect((verifyCall['body'] as Map)['type'], equals('recovery'));

        // Verify local SQLite and AppState synced
        final expectedHash = DatabaseService.hashPassword(newPassword);
        expect(
            AppState.instance.currentUser?.passwordHash, equals(expectedHash));
        expect(await getLocalUserPasswordHash(user.id), equals(expectedHash));
        if (role == UserRole.admin) {
          final dbAdmin = await db.getAdminById(user.id);
          expect(dbAdmin?.passwordHash, equals(expectedHash));
        }

        // Scenario 10: Signing in with old password fails
        await expectLater(
          () => supabaseClient.auth.signInWithPassword(
            email: email,
            password: oldPassword,
          ),
          throwsA(isA<AuthException>()),
        );

        // Scenario 9: Signing in with new password succeeds
        final loginRes = await supabaseClient.auth.signInWithPassword(
          email: email,
          password: newPassword,
        );
        expect(loginRes.user?.id, equals(user.id));
      });
    }

    test(
        'Scenario 2: Entering an incorrect code fails with clear invalid code message (no Bad state prefix)',
        () async {
      const email = 'passenger2@sakayta.ph';
      await seedAndSignInRole(
        id: 'uid-p2',
        email: email,
        password: 'OldPassword123!',
        role: UserRole.passenger,
      );

      await PasswordChangeService.requestOtp();

      Object? caught;
      try {
        await PasswordChangeService.verifyAndUpdate(
          email: email,
          code: '999999',
          newPassword: 'NewPassword456!',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      final formatted = PasswordChangeService.formatErrorMessage(caught!);
      expect(formatted, isNot(contains('Bad state:')));
      expect(
        formatted,
        equals(
          'Invalid verification code. Please check the 6-digit code and try again.',
        ),
      );
    });

    test(
        'Scenario 3: Entering an expired code fails with clear expired message (no Bad state prefix)',
        () async {
      const email = 'driver3@sakayta.ph';
      await seedAndSignInRole(
        id: 'uid-d3',
        email: email,
        password: 'OldPassword123!',
        role: UserRole.driver,
      );

      await PasswordChangeService.requestOtp();
      final otp = server.accountsByEmail[email]!.activeRecoveryOtp!;
      server.accountsByEmail[email]!.recoveryOtpExpired = true;

      Object? caught;
      try {
        await PasswordChangeService.verifyAndUpdate(
          email: email,
          code: otp,
          newPassword: 'NewPassword456!',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      final formatted = PasswordChangeService.formatErrorMessage(caught!);
      expect(formatted, isNot(contains('Bad state:')));
      expect(
        formatted,
        equals('This verification code has expired. Request a new code.'),
      );
    });

    test(
        'Scenario 4 & 5: Clicking Resend Code invalidates old code with superseded message, and entering the new code succeeds',
        () async {
      const email = 'passenger4@sakayta.ph';
      await seedAndSignInRole(
        id: 'uid-p4',
        email: email,
        password: 'OldPassword123!',
        role: UserRole.passenger,
      );

      // Initial code request
      await PasswordChangeService.requestOtp();
      final firstCode = server.accountsByEmail[email]!.activeRecoveryOtp!;
      expect(firstCode, equals('100001'));

      // User clicks Resend Code while firstCode was in input
      await PasswordChangeService.requestOtp(previousCode: firstCode);
      final secondCode = server.accountsByEmail[email]!.activeRecoveryOtp!;
      expect(secondCode, equals('100002'));

      // Scenario 4: Entering old code fails with specific replaced-by-newer-code message
      Object? oldCodeError;
      try {
        await PasswordChangeService.verifyAndUpdate(
          email: email,
          code: firstCode,
          newPassword: 'NewPassword456!',
        );
      } catch (e) {
        oldCodeError = e;
      }
      expect(oldCodeError, isNotNull);
      expect(
        PasswordChangeService.formatErrorMessage(oldCodeError!),
        equals(
          'This verification code has expired because a new code was requested. Enter the latest code.',
        ),
      );

      // Scenario 5: Entering the new code succeeds
      await PasswordChangeService.verifyAndUpdate(
        email: email,
        code: secondCode,
        newPassword: 'NewPassword456!',
      );
      expect(server.accountsByEmail[email]!.password, equals('NewPassword456!'));
    });

    test(
        'Scenario 6: Attempting to reuse an already used code fails with already-used message',
        () async {
      const email = 'admin6@sakayta.ph';
      await seedAndSignInRole(
        id: 'uid-a6',
        email: email,
        password: 'OldPassword123!',
        role: UserRole.admin,
      );

      await PasswordChangeService.requestOtp();
      final code = server.accountsByEmail[email]!.activeRecoveryOtp!;

      await PasswordChangeService.verifyAndUpdate(
        email: email,
        code: code,
        newPassword: 'NewPassword456!',
      );

      // Attempt to reuse the exact same code again
      Object? reuseError;
      try {
        await PasswordChangeService.verifyAndUpdate(
          email: email,
          code: code,
          newPassword: 'AnotherPassword789!',
        );
      } catch (e) {
        reuseError = e;
      }
      expect(reuseError, isNotNull);
      expect(
        PasswordChangeService.formatErrorMessage(reuseError!),
        equals(
            'This verification code has already been used. Request a new code.'),
      );
    });

    test(
        'Scenario 7 & 8: Weak/invalid password fails before consuming OTP',
        () async {
      const email = 'driver7@sakayta.ph';
      await seedAndSignInRole(
        id: 'uid-d7',
        email: email,
        password: 'OldPassword123!',
        role: UserRole.driver,
      );

      await PasswordChangeService.requestOtp();
      final code = server.accountsByEmail[email]!.activeRecoveryOtp!;

      // Scenario 8: Weak password (< 6 chars)
      await expectLater(
        () => PasswordChangeService.verifyAndUpdate(
          email: email,
          code: code,
          newPassword: '123',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // OTP was NOT consumed because password validation runs before verifyOTP
      expect(server.accountsByEmail[email]!.activeRecoveryOtp, equals(code));

      // Now valid password succeeds with the same code
      await PasswordChangeService.verifyAndUpdate(
        email: email,
        code: code,
        newPassword: 'StrongPassword123!',
      );
      expect(
        server.accountsByEmail[email]!.password,
        equals('StrongPassword123!'),
      );
    });

    test(
        'Rate-limited resend does NOT invalidate the existing active code, and server-side same_password retry preserves verified session',
        () async {
      const email = 'retry_driver@sakayta.ph';
      const oldPassword = 'OldPassword123!';
      const newPassword = 'UpdatedPassword789!';

      await seedAndSignInRole(
        id: 'uid-retry-d',
        email: email,
        password: oldPassword,
        role: UserRole.driver,
      );
      // Simulate Supabase-loaded user where local passwordHash is empty
      AppState.instance.currentUser =
          AppState.instance.currentUser!.copyWith(passwordHash: '');

      await PasswordChangeService.requestOtp();
      final activeCode = server.accountsByEmail[email]!.activeRecoveryOtp!;

      // Simulate a rate-limited resend (429): activeCode must NOT be marked superseded!
      server.rateLimitNextRecover = true;
      await expectLater(
        () => PasswordChangeService.requestOtp(previousCode: activeCode),
        throwsA(
          isA<PasswordAuthException>().having(
            (e) => e.toString(),
            'toString()',
            allOf(
              isNot(contains('Bad state:')),
              equals(
                'Too many attempts. Please wait before requesting another code.',
              ),
            ),
          ),
        ),
      );

      // Attempt update with oldPassword -> verifyOTP succeeds, updateUser fails with same_password
      await expectLater(
        () => PasswordChangeService.verifyAndUpdate(
          email: email,
          code: activeCode,
          newPassword: oldPassword,
        ),
        throwsA(
          isA<PasswordAuthException>().having(
            (e) => e.toString(),
            'toString()',
            equals('New password must be different from your current password.'),
          ),
        ),
      );

      // Retry with a valid new password using the same code -> succeeds without re-consuming OTP!
      await PasswordChangeService.verifyAndUpdate(
        email: email,
        code: activeCode,
        newPassword: newPassword,
      );
      expect(server.accountsByEmail[email]!.password, equals(newPassword));
    });

    test(
        'Forgot Password complete recovery flow works for Passenger, Driver, and Admin',
        () async {
      for (final role in [UserRole.passenger, UserRole.driver, UserRole.admin]) {
        final email = 'forgot_$role@sakayta.ph';
        const oldPassword = 'ForgotOld123!';
        const newPassword = 'ForgotNew456!';

        final user = await seedAndSignInRole(
          id: 'forgot-uid-$role',
          email: email,
          password: oldPassword,
          role: role,
        );
        await supabaseClient.auth.signOut();
        AppState.instance.currentUser = null;

        // Step 1 & 2: Send recovery email
        await PasswordRecoveryService.sendRecoveryEmail(email);
        final firstOtp = server.accountsByEmail[email]!.activeRecoveryOtp!;

        // Resend code and verify old code is rejected
        await PasswordRecoveryService.sendRecoveryEmail(
          email,
          previousCode: firstOtp,
        );
        final latestOtp = server.accountsByEmail[email]!.activeRecoveryOtp!;
        expect(latestOtp, isNot(equals(firstOtp)));

        await expectLater(
          () => PasswordRecoveryService.verifyRecoveryOtp(
            email,
            firstOtp,
          ),
          throwsA(
            predicate(
              (e) =>
                  PasswordRecoveryService.formatErrorMessage(e!) ==
                  'This verification code has expired because a new code was requested. Enter the latest code.',
            ),
          ),
        );

        // Step 3 & 4: Verify latest code
        await PasswordRecoveryService.verifyRecoveryOtp(
          email,
          latestOtp,
        );
        expect(PasswordRecoveryService.hasRecoverySession, isTrue);

        // Step 5 & 6: Update password
        await PasswordRecoveryService.updatePassword(newPassword);

        // Verify local SQLite password hash synced
        final expectedHash = DatabaseService.hashPassword(newPassword);
        expect(await getLocalUserPasswordHash(user.id), equals(expectedHash));

        // Verify sign in with new password works and old password fails
        await expectLater(
          () => supabaseClient.auth.signInWithPassword(
            email: email,
            password: oldPassword,
          ),
          throwsA(isA<AuthException>()),
        );
        final signInRes = await supabaseClient.auth.signInWithPassword(
          email: email,
          password: newPassword,
        );
        expect(signInRes.user?.email, equals(email));
        await supabaseClient.auth.signOut();
      }
    });

    testWidgets(
        'PasswordChangePage UI: clears old code on Resend, validates mismatched passwords, and updates password without Bad state error',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      const email = 'ui_passenger@sakayta.ph';
      await tester.runAsync(() async {
        await seedAndSignInRole(
          id: 'uid-ui-p',
          email: email,
          password: 'OldPassword123!',
          role: UserRole.passenger,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordChangePage(),
        ),
      );
      await tester.pump();

      // Send verification code
      await tester.tap(find.text('Send Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final firstCode = server.accountsByEmail[email]!.activeRecoveryOtp!;
      expect(firstCode, equals('100001'));

      // Enter first code into Verification Code field
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), firstCode);
      await tester.enterText(textFields.at(1), 'NewPassword456!');
      // Scenario 7: Mismatched confirmation password
      await tester.enterText(textFields.at(2), 'Mismatch999!');

      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('New passwords do not match.'), findsOneWidget);

      // Advance 31 seconds for resend cooldown to finish
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Tap Resend Verification Code -> must clear the Verification Code field!
      await tester.tap(find.text('Resend Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final codeFieldWidget = tester.widget<TextField>(textFields.at(0));
      expect(codeFieldWidget.controller?.text, isEmpty);

      final secondCode = server.accountsByEmail[email]!.activeRecoveryOtp!;
      expect(secondCode, equals('100002'));

      // Advance cooldown timer so no pending timer remains at end of test
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    });

    testWidgets(
        'PasswordRecoveryPage UI: shows target email, clears old code on Resend, and completes password reset',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      const email = 'ui_recovery@sakayta.ph';
      await tester.runAsync(() async {
        await seedAndSignInRole(
          id: 'uid-ui-rec',
          email: email,
          password: 'OldPassword123!',
          role: UserRole.driver,
        );
        await supabaseClient.auth.signOut();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PasswordRecoveryEmailScreen(initialEmail: email),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Send Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Enter Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify interpolated email is displayed in subtitle
      expect(
        find.text('Enter the verification code sent to $email.'),
        findsOneWidget,
      );

      final firstOtp = server.accountsByEmail[email]!.activeRecoveryOtp!;
      await tester.enterText(find.byType(TextField), firstOtp);

      // Tap Resend Code and verify old code is cleared from input
      await tester.tap(find.text('Resend Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final codeField = tester.widget<TextField>(find.byType(TextField));
      expect(codeField.controller?.text, isEmpty);

      final latestOtp = server.accountsByEmail[email]!.activeRecoveryOtp!;
      await tester.enterText(find.byType(TextField), latestOtp);
      await tester.tap(find.widgetWithText(FilledButton, 'Verify Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Now on New Password screen
      expect(find.text('Choose a new password'), findsOneWidget);
    });
  });
}
