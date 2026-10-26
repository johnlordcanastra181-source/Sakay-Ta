import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logger.dart';
import '../core/supabase_config.dart';
import '../state/app_state.dart';
import 'database_service.dart';
import 'supabase/admin_service.dart';

/// Clean authentication exception for password change and recovery flows.
///
/// Prevents converting expected OTP/Auth failures into [StateError]
/// (which Dart formats with a misleading `"Bad state: "` prefix).
class PasswordAuthException implements Exception {
  const PasswordAuthException(
    this.message, {
    this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String? code;
  final String? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

/// Secure password-change helpers for signed-in Passenger, Driver, and Admin users.
///
/// Sends a 6-digit verification code to the currently authenticated user's
/// email, verifies the code with [OtpType.recovery] (preserving compatibility
/// with Supabase Auth reauthenticate / [OtpType.email] boundaries), confirms
/// that the verified session belongs to the same user account, and only then
/// updates the password via [GoTrueClient.updateUser].
abstract final class PasswordChangeService {
  @visibleForTesting
  static SupabaseClient? debugClient;

  static bool _requestingInFlight = false;
  static bool _updatingInFlight = false;
  static bool _isFlowActive = false;

  static String? _expectedUserId;
  static String? _expectedEmail;
  static int _requestGeneration = 0;
  static DateTime? _lastOtpSentAt;
  static String? _lastSubmittedCodeHash;
  static String? _verifiedPendingCodeHash;
  static int? _verifiedPendingGeneration;
  static final Set<String> _usedCodeHashes = <String>{};
  static final Set<String> _supersededCodeHashes = <String>{};

  /// True while a password-change OTP verification + update transaction is active.
  /// Used by auth-state routers to avoid premature redirects mid-update.
  static bool get isFlowActive => _isFlowActive;

  /// Returns the normalized email of the currently authenticated user.
  static String get currentUserEmail {
    try {
      final authEmail = _client.auth.currentUser?.email?.trim().toLowerCase();
      if (authEmail != null && authEmail.isNotEmpty) {
        return authEmail;
      }
    } catch (e, s) {
      AppLogger.debug('PasswordChangeService non-fatal note: $e',
          error: e, stackTrace: s);
    }
    return AppState.instance.currentUser?.email?.trim().toLowerCase() ?? '';
  }

  @visibleForTesting
  static void resetStateForTesting() {
    _requestingInFlight = false;
    _updatingInFlight = false;
    _isFlowActive = false;
    _expectedUserId = null;
    _expectedEmail = null;
    _requestGeneration = 0;
    _lastOtpSentAt = null;
    _lastSubmittedCodeHash = null;
    _verifiedPendingCodeHash = null;
    _verifiedPendingGeneration = null;
    _usedCodeHashes.clear();
    _supersededCodeHashes.clear();
  }

  /// Records a one-way hash of any code present in the input before a resend
  /// so submitting an older replaced code yields a clear message.
  static void markCodeSuperseded(String? code) {
    final trimmed = code?.trim() ?? '';
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      _supersededCodeHashes.add(DatabaseService.legacyFnv1aHash(trimmed));
    }
  }

  static Future<void> requestOtp({String? previousCode}) async {
    if (_requestingInFlight || _updatingInFlight) {
      throw const PasswordAuthException(
        'A password-change request is already in progress.',
        code: 'request_in_flight',
      );
    }

    final client = _client;
    final currentUser = client.auth.currentUser;
    final currentSession = client.auth.currentSession;
    if (currentUser == null || currentSession == null) {
      throw const PasswordAuthException(
        'Sign in before changing your password.',
        code: 'session_missing',
      );
    }

    final appUser = AppState.instance.currentUser;
    if (appUser != null && appUser.id != currentUser.id) {
      throw const PasswordAuthException(
        'Your session changed. Sign in again and retry.',
        code: 'session_mismatch',
      );
    }

    final normalizedEmail =
        (currentUser.email ?? appUser?.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const PasswordAuthException(
        'No valid email address is associated with this account.',
        code: 'invalid_email',
      );
    }

    if (_expectedUserId != null && _expectedUserId != currentUser.id ||
        _expectedEmail != null && _expectedEmail != normalizedEmail) {
      _usedCodeHashes.clear();
      _supersededCodeHashes.clear();
      _lastSubmittedCodeHash = null;
      _verifiedPendingCodeHash = null;
      _verifiedPendingGeneration = null;
    }

    _requestingInFlight = true;
    try {
      await client.auth.resetPasswordForEmail(normalizedEmail);
      // Only mark previous codes as superseded after the server confirms
      // that a new code has been issued.
      markCodeSuperseded(previousCode);
      if (_lastSubmittedCodeHash != null) {
        _supersededCodeHashes.add(_lastSubmittedCodeHash!);
        _lastSubmittedCodeHash = null;
      }
      if (_verifiedPendingCodeHash != null) {
        _supersededCodeHashes.add(_verifiedPendingCodeHash!);
        _verifiedPendingCodeHash = null;
        _verifiedPendingGeneration = null;
      }
      _expectedUserId = currentUser.id;
      _expectedEmail = normalizedEmail;
      _lastOtpSentAt = DateTime.now();
      _requestGeneration++;
    } on AuthException catch (error) {
      _logDiagnostic(
        'requestOtp',
        code: error.code,
        statusCode: error.statusCode,
        reason: 'auth_exception',
      );
      throw PasswordAuthException(
        _authMessage(error),
        code: error.code,
        statusCode: error.statusCode,
        cause: error,
      );
    } on PasswordAuthException {
      rethrow;
    } catch (error) {
      _logDiagnostic('requestOtp', reason: 'unexpected_error');
      throw PasswordAuthException(
        'Unable to send the verification code. Try again.',
        cause: error,
      );
    } finally {
      _requestingInFlight = false;
    }
  }

  static Future<void> verifyAndUpdate({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_updatingInFlight || _requestingInFlight) {
      throw const PasswordAuthException(
        'A password update is already in progress.',
        code: 'update_in_flight',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw ArgumentError('Enter the 6-digit verification code.');
    }
    if (newPassword.length < 6) {
      throw ArgumentError('Use at least 6 characters for your new password.');
    }

    final client = _client;
    final before = client.auth.currentUser;
    if (before == null || client.auth.currentSession == null) {
      throw const PasswordAuthException(
        'Your session expired. Sign in again and retry.',
        code: 'session_expired',
      );
    }

    final beforeEmail = before.email?.trim().toLowerCase() ?? '';
    if (beforeEmail != normalizedEmail) {
      throw const PasswordAuthException(
        'The verification email does not match this account.',
        code: 'email_mismatch',
      );
    }
    if (_expectedUserId != null && before.id != _expectedUserId) {
      throw const PasswordAuthException(
        'The active account changed. Request a new verification code.',
        code: 'account_mismatch',
      );
    }
    if (_expectedEmail != null && normalizedEmail != _expectedEmail) {
      throw const PasswordAuthException(
        'The verification email does not match this account.',
        code: 'email_mismatch',
      );
    }

    final appUser = AppState.instance.currentUser;
    if (appUser != null && appUser.id != before.id) {
      throw const PasswordAuthException(
        'The verification email does not match this account.',
        code: 'account_mismatch',
      );
    }
    if (appUser != null && appUser.passwordHash.isNotEmpty) {
      if (DatabaseService.verifyPassword(newPassword, appUser.passwordHash)) {
        throw ArgumentError(
          'New password must be different from your current password.',
        );
      }
    }

    final codeHash = DatabaseService.legacyFnv1aHash(normalizedCode);
    if (_usedCodeHashes.contains(codeHash)) {
      throw const PasswordAuthException(
        'This verification code has already been used. Request a new code.',
        code: 'otp_used',
      );
    }
    if (_supersededCodeHashes.contains(codeHash)) {
      throw const PasswordAuthException(
        'This verification code has expired because a new code was requested. '
        'Enter the latest code.',
        code: 'otp_superseded',
      );
    }

    final generationAtStart = _requestGeneration;
    _lastSubmittedCodeHash = codeHash;
    _updatingInFlight = true;
    _isFlowActive = true;

    try {
      final alreadyVerifiedThisCode = _verifiedPendingCodeHash == codeHash &&
          _verifiedPendingGeneration == generationAtStart &&
          client.auth.currentSession != null &&
          client.auth.currentUser?.id == before.id;

      if (!alreadyVerifiedThisCode) {
        final verification = await client.auth.verifyOTP(
          email: normalizedEmail,
          token: normalizedCode,
          type: OtpType.recovery,
        );

        if (_requestGeneration != generationAtStart) {
          throw const PasswordAuthException(
            'A newer verification code was requested. Please enter the latest code.',
            code: 'otp_superseded',
          );
        }

        final verifiedUser = verification.user ?? client.auth.currentUser;
        final verifiedEmail = verifiedUser?.email?.trim().toLowerCase();
        if (verifiedUser == null ||
            verifiedUser.id != before.id ||
            verifiedEmail != normalizedEmail ||
            client.auth.currentSession == null) {
          throw const PasswordAuthException(
            'Verification did not establish a valid session.',
            code: 'session_invalid',
          );
        }

        _verifiedPendingCodeHash = codeHash;
        _verifiedPendingGeneration = generationAtStart;
      }

      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _usedCodeHashes.add(codeHash);
      _verifiedPendingCodeHash = null;
      _verifiedPendingGeneration = null;
      _lastSubmittedCodeHash = null;

      await _syncLocalAccountPassword(
        userId: before.id,
        newPassword: newPassword,
        accessToken: client.auth.currentSession?.accessToken,
      );
    } on AuthException catch (error) {
      _logDiagnostic(
        'verifyAndUpdate',
        code: error.code,
        statusCode: error.statusCode,
        reason: 'auth_exception',
      );
      throw PasswordAuthException(
        _authMessage(error, codeHash: codeHash),
        code: error.code,
        statusCode: error.statusCode,
        cause: error,
      );
    } on PasswordAuthException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (error) {
      _logDiagnostic('verifyAndUpdate', reason: 'unexpected_error');
      throw PasswordAuthException(
        'Unable to update the password. Try again.',
        cause: error,
      );
    } finally {
      _updatingInFlight = false;
      _isFlowActive = false;
    }
  }

  static Future<void> _syncLocalAccountPassword({
    required String userId,
    required String newPassword,
    required String? accessToken,
  }) async {
    final hash = DatabaseService.hashPassword(newPassword);
    try {
      await DatabaseService.instance.updateAdminPassword(userId, hash);
    } catch (e, s) {
      AppLogger.debug('PasswordChangeService non-fatal note: $e',
          error: e, stackTrace: s);
    }

    final appState = AppState.instance;
    final current = appState.currentUser;
    if (current != null && current.id == userId) {
      appState.currentUser = current.copyWith(passwordHash: hash);
      if (current.isAdmin && accessToken != null) {
        SupabaseAdminService.instance.cacheAuthorizedAdmin(userId, accessToken);
      }
    }
  }

  static SupabaseClient? get activeClientOrNull {
    if (debugClient != null) return debugClient;
    if (!SupabaseConfig.isInitialized) return null;
    return Supabase.instance.client;
  }

  static SupabaseClient get _client {
    final client = activeClientOrNull;
    if (client == null) {
      throw const PasswordAuthException(
        'Password change is not available right now.',
        code: 'client_unavailable',
      );
    }
    return client;
  }

  static String formatErrorMessage(Object error) {
    if (error is PasswordAuthException) {
      return error.message.trim();
    }
    var msg = error.toString().trim();
    const prefixes = [
      'Bad state: ',
      'StateError: ',
      'Invalid argument(s): ',
      'FormatException: ',
      'PasswordAuthException: ',
      'Exception: ',
    ];
    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (msg.startsWith(prefix)) {
          msg = msg.substring(prefix.length).trim();
          changed = true;
        }
      }
    }
    return msg;
  }

  static String _authMessage(AuthException error, {String? codeHash}) {
    if (codeHash != null && _usedCodeHashes.contains(codeHash)) {
      return 'This verification code has already been used. Request a new code.';
    }
    if (codeHash != null && _supersededCodeHashes.contains(codeHash)) {
      return 'This verification code has expired because a new code was requested. Enter the latest code.';
    }

    final message = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    final status = (error.statusCode ?? '').toLowerCase();

    if (status == '429' ||
        code.contains('rate') ||
        message.contains('rate') ||
        message.contains('too many') ||
        message.contains('security purposes')) {
      return 'Too many attempts. Please wait before requesting another code.';
    }
    if (code == 'otp_used' ||
        message.contains('already been used') ||
        message.contains('already used')) {
      return 'This verification code has already been used. Request a new code.';
    }
    if (message.contains('same_password') ||
        code == 'same_password' ||
        message.contains('different from the old password')) {
      return 'New password must be different from your current password.';
    }
    if (code == 'otp_invalid' ||
        (message.contains('invalid') && !message.contains('expired'))) {
      return 'Invalid verification code. Please check the 6-digit code and try again.';
    }
    if (message.contains('expired') && message.contains('invalid')) {
      final sentAt = _lastOtpSentAt;
      if (sentAt != null &&
          DateTime.now().difference(sentAt) < const Duration(minutes: 55)) {
        return 'Invalid verification code. Please check the 6-digit code and try again.';
      }
      return 'Invalid or expired verification code. Check the latest code sent to your email or request a new code.';
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return 'This verification code has expired. Request a new code.';
    }
    if (message.contains('invalid') || message.contains('token')) {
      return 'Invalid verification code. Please check the 6-digit code and try again.';
    }
    if (message.contains('reauth') || message.contains('nonce')) {
      return 'Password verification failed. Request a new code and try again.';
    }
    return error.message;
  }

  static void _logDiagnostic(
    String operation, {
    String? code,
    String? statusCode,
    String? reason,
  }) {
    debugPrint(
      '[SakayTa][PasswordChangeService] op=$operation '
      'code=${code ?? 'none'} status=${statusCode ?? 'none'} '
      'reason=${reason ?? 'unspecified'}',
    );
  }
}
