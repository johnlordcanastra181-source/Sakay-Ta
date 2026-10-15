import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

abstract final class SupabaseAuthService {
  static Future<String?> createAdminAuthAccount(
      {required String email,
      required String password,
      String? fullName}) async {
    return createDurableAccount(
        mobile: email, password: password, email: email);
  }

  static bool get isConfigured => SupabaseConfig.isInitialized;

  static String emailFor(String identifier) {
    if (identifier.contains('@')) return identifier.trim().toLowerCase();
    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final local = digits.substring(digits.length - 10);
      return '63$local@sakayta.phone.local';
    }
    return identifier.trim().toLowerCase();
  }

  static Future<String?> signIn({
    required String mobile,
    required String password,
    List<String>? alternateIdentifiers,
  }) async {
    final candidates = <String>{
      emailFor(mobile),
      if (mobile.contains('@')) mobile.trim().toLowerCase(),
      if (alternateIdentifiers != null)
        ...alternateIdentifiers.map((id) => emailFor(id)),
    };

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final email in candidates) {
      if (email.isEmpty || !email.contains('@')) continue;
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        return res.user?.id;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
        debugPrint('SupabaseAuth: signIn skipped for $email ($e)');
      }
    }
    if (lastError != null) {
      Error.throwWithStackTrace(
          lastError, lastStackTrace ?? StackTrace.current);
    }
    return null;
  }

  static Future<String> createDurableAccount({
    required String mobile,
    required String password,
    String? email,
  }) async {
    final targetEmail = email?.trim().isNotEmpty == true
        ? email!.trim().toLowerCase()
        : emailFor(mobile);
    final auth = Supabase.instance.client.auth;

    // Legacy durable-account helper. Registration flows that need to write
    // RLS-protected rows use createAuthenticatedAccount below instead.
    final res = await auth.signUp(
      email: targetEmail,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Account creation returned no authenticated user.');
    }
    return user.id;
  }

  /// Creates an email/password account and requires Supabase to return an
  /// authenticated session immediately.
  ///
  /// Passenger and driver registration write RLS-protected rows immediately
  /// after Auth signup. A signup response with a user but no session means
  /// Supabase Confirm Email is still enabled; that is a server configuration
  /// issue, not a reason to send a second client-side OTP or to fake success.
  static Future<User> createAuthenticatedAccount({
    required String email,
    required String password,
    String? fullName,
    String? mobile,
  }) async {
    final targetEmail = email.trim().toLowerCase();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }

    final auth = Supabase.instance.client.auth;
    AuthResponse response;
    try {
      response = await auth.signUp(
        email: targetEmail,
        password: password,
        data: {
          if (fullName?.trim().isNotEmpty == true) 'full_name': fullName!.trim(),
          if (mobile?.trim().isNotEmpty == true) 'mobile': mobile!.trim(),
        },
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.statusCode == '422' ||
          e.code == 'user_already_exists' ||
          msg.contains('already registered') ||
          msg.contains('already exists')) {
        try {
          final loginRes = await auth.signInWithPassword(
            email: targetEmail,
            password: password,
          );
          if (loginRes.user != null && loginRes.session != null) {
            return loginRes.user!;
          }
        } on AuthException catch (loginErr) {
          final loginMsg = loginErr.message.toLowerCase();
          if (loginErr.code == 'email_not_confirmed' ||
              loginMsg.contains('email not confirmed')) {
            throw const AuthException(
              'This account was created during an earlier setup and requires confirmation. Please use Forgot Password to reset your password and access your account.',
              statusCode: '400',
              code: 'email_not_confirmed',
            );
          }
          throw const AuthException(
            'This email address is already registered. Please log in with your existing password or use Forgot Password to recover your account.',
            statusCode: '422',
            code: 'user_already_exists',
          );
        }
      }
      rethrow;
    }

    final createdUser = response.user;
    if (createdUser == null) {
      throw StateError('Account creation returned no user.');
    }

    final session = response.session ?? auth.currentSession;
    final activeUser = auth.currentUser;
    if (session == null || activeUser?.id != createdUser.id) {
      if (createdUser.identities?.isEmpty == true) {
        try {
          final loginRes = await auth.signInWithPassword(
            email: targetEmail,
            password: password,
          );
          if (loginRes.user != null && loginRes.session != null) {
            return loginRes.user!;
          }
        } on AuthException catch (loginErr) {
          final loginMsg = loginErr.message.toLowerCase();
          if (loginErr.code == 'email_not_confirmed' ||
              loginMsg.contains('email not confirmed')) {
            throw const AuthException(
              'This account was created during an earlier setup and requires confirmation. Please use Forgot Password to reset your password and access your account.',
              statusCode: '400',
              code: 'email_not_confirmed',
            );
          }
          throw const AuthException(
            'This email address is already registered. Please log in with your existing password or use Forgot Password to recover your account.',
            statusCode: '422',
            code: 'user_already_exists',
          );
        }
      }

      throw StateError(
        'Supabase created the account but did not establish a session. '
        'Disable Authentication > Providers > Email > Confirm Email, then '
        'retry registration. No OTP fallback was requested.',
      );
    }
    return activeUser!;
  }

  static Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuth: signOut note ($e)');
    }
  }

  static String? get currentUid {
    return Supabase.instance.client.auth.currentUser?.id;
  }
}
