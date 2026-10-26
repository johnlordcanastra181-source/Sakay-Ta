import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logger.dart';
import '../core/supabase_config.dart';
import 'database_service.dart';
import 'password_change_service.dart';

/// Supabase password-recovery helpers shared by the passenger, driver, and
/// admin login experiences. No password or OTP is ever stored in plaintext.
abstract final class PasswordRecoveryService {
  @visibleForTesting
  static SupabaseClient? debugClient;

  static bool _sendingInFlight = false;
  static bool _verifyingInFlight = false;
  static bool _updatingInFlight = false;
  static bool _isFlowActive = false;

  static String? _activeRecoveryEmail;
  static int _requestGeneration = 0;
  static DateTime? _lastOtpSentAt;
  static String? _verifiedUserId;
  static String? _verifiedEmail;
  static int? _verifiedGeneration;
  static String? _lastSubmittedCodeHash;
  static final Set<String> _usedCodeHashes = <String>{};
  static final Set<String> _supersededCodeHashes = <String>{};

  /// True while a password-recovery verification or password update is active.
  static bool get isFlowActive => _isFlowActive;

  static bool get hasRecoverySession {
    try {
      final client = _clientOrNull;
      if (client == null) return false;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) return false;
      if (_verifiedUserId != null && user.id != _verifiedUserId) {
        return false;
      }
      if (_verifiedEmail != null &&
          user.email?.trim().toLowerCase() != _verifiedEmail) {
        return false;
      }
      if (_verifiedGeneration != null &&
          _verifiedGeneration != _requestGeneration) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void resetStateForTesting() {
    _sendingInFlight = false;
    _verifyingInFlight = false;
    _updatingInFlight = false;
    _isFlowActive = false;
    _activeRecoveryEmail = null;
    _requestGeneration = 0;
    _lastOtpSentAt = null;
    _verifiedUserId = null;
    _verifiedEmail = null;
    _verifiedGeneration = null;
    _lastSubmittedCodeHash = null;
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

  static Future<void> sendRecoveryEmail(
    String email, {
    String? previousCode,
  }) async {
    if (_sendingInFlight) {
      throw const PasswordAuthException(
        'A verification code request is already in progress.',
        code: 'request_in_flight',
      );
    }

    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw ArgumentError('Enter a valid email address.');
    }

    final client = _client;

    _sendingInFlight = true;
    try {
      await client.auth.resetPasswordForEmail(normalized);
      if (_activeRecoveryEmail != normalized) {
        _usedCodeHashes.clear();
        _supersededCodeHashes.clear();
        _lastSubmittedCodeHash = null;
      } else {
        // Only mark previous codes as superseded after the server confirms
        // that a new code has been issued.
        markCodeSuperseded(previousCode);
        if (_lastSubmittedCodeHash != null) {
          _supersededCodeHashes.add(_lastSubmittedCodeHash!);
          _lastSubmittedCodeHash = null;
        }
      }
      _activeRecoveryEmail = normalized;
      _lastOtpSentAt = DateTime.now();
      _requestGeneration++;
      _verifiedUserId = null;
      _verifiedEmail = null;
      _verifiedGeneration = null;
    } on AuthException catch (e) {
      _logDiagnostic(
        'sendRecoveryEmail',
        code: e.code,
        statusCode: e.statusCode,
        reason: 'auth_exception',
      );
      throw PasswordAuthException(
        _authMessage(e),
        code: e.code,
        statusCode: e.statusCode,
        cause: e,
      );
    } on PasswordAuthException {
      rethrow;
    } catch (e) {
      _logDiagnostic('sendRecoveryEmail', reason: 'unexpected_error');
      throw PasswordAuthException(
        'Unable to connect. Please check your internet connection.',
        cause: e,
      );
    } finally {
      _sendingInFlight = false;
    }
  }

  static Future<void> verifyRecoveryOtp(String email, String code) async {
    if (_verifyingInFlight || _sendingInFlight) {
      throw const PasswordAuthException(
        'Verification is already in progress.',
        code: 'verify_in_flight',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Verification code is required.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw ArgumentError('Enter the 6-digit verification code.');
    }
    if (_activeRecoveryEmail != null &&
        _activeRecoveryEmail != normalizedEmail) {
      throw const PasswordAuthException(
        'The email address does not match the active recovery request.',
        code: 'email_mismatch',
      );
    }

    final client = _client;
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
    _verifyingInFlight = true;
    _isFlowActive = true;

    try {
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
      final session = verification.session ?? client.auth.currentSession;
      final verifiedEmail = verifiedUser?.email?.trim().toLowerCase();
      if (verifiedUser == null ||
          session == null ||
          verifiedEmail != normalizedEmail) {
        throw const PasswordAuthException(
          'Verification did not establish a valid session.',
          code: 'session_invalid',
        );
      }

      _usedCodeHashes.add(codeHash);
      _verifiedUserId = verifiedUser.id;
      _verifiedEmail = normalizedEmail;
      _verifiedGeneration = generationAtStart;
    } on AuthException catch (e) {
      _logDiagnostic(
        'verifyRecoveryOtp',
        code: e.code,
        statusCode: e.statusCode,
        reason: 'auth_exception',
      );
      throw PasswordAuthException(
        _authMessage(e, codeHash: codeHash),
        code: e.code,
        statusCode: e.statusCode,
        cause: e,
      );
    } on PasswordAuthException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      _logDiagnostic('verifyRecoveryOtp', reason: 'unexpected_error');
      throw PasswordAuthException(
        'Unable to connect. Please check your internet connection.',
        cause: e,
      );
    } finally {
      _verifyingInFlight = false;
    }
  }

  static Future<void> updatePassword(String password) async {
    if (_updatingInFlight) {
      throw const PasswordAuthException(
        'Password update is already in progress.',
        code: 'update_in_flight',
      );
    }
    if (password.length < 6) {
      throw ArgumentError('Use at least 6 characters for your new password.');
    }
    if (!hasRecoverySession) {
      throw const PasswordAuthException(
        'This recovery session is invalid or has expired. Request a new code.',
        code: 'session_expired',
      );
    }

    final client = _client;
    final targetUser = client.auth.currentUser;
    if (targetUser == null) {
      throw const PasswordAuthException(
        'This recovery session is invalid or has expired. Request a new code.',
        code: 'session_expired',
      );
    }
    if (_verifiedUserId != null && targetUser.id != _verifiedUserId) {
      throw const PasswordAuthException(
        'The recovery session no longer matches the verified account. Request a new code.',
        code: 'account_mismatch',
      );
    }
    if (_verifiedEmail != null &&
        targetUser.email?.trim().toLowerCase() != _verifiedEmail) {
      throw const PasswordAuthException(
        'The recovery session no longer matches the verified email. Request a new code.',
        code: 'email_mismatch',
      );
    }

    _updatingInFlight = true;
    _isFlowActive = true;
    try {
      await client.auth.updateUser(UserAttributes(password: password));

      // Admin-invited Drivers carry this marker in Auth metadata. Activate the
      // profile only after the invitee has set a password using the trusted
      // session from the activation link.
      final metadata = client.auth.currentUser?.userMetadata;
      final isDriverInvite = metadata?['driver_application_id'] != null &&
          metadata?['driver_account_activated'] != true;
      if (isDriverInvite) {
        final activation = await client.functions.invoke(
          'driver-applications',
          body: {'action': 'activate'},
        );
        if (activation.status < 200 || activation.status >= 300) {
          final details = activation.data;
          final message = details is Map ? details['error']?.toString() : null;
          throw PasswordAuthException(
            message ?? 'Driver account activation could not be confirmed.',
            code: 'activation_failed',
          );
        }
        final result = activation.data;
        if (result is! Map || result['activated'] != true) {
          throw const PasswordAuthException(
            'Driver account activation could not be confirmed.',
            code: 'activation_failed',
          );
        }
      }

      // Sync local SQLite password hash if this account is cached locally.
      try {
        final hash = DatabaseService.hashPassword(password);
        await DatabaseService.instance.updateAdminPassword(targetUser.id, hash);
      } catch (e, s) {
      AppLogger.debug('PasswordRecoveryService non-fatal note: $e',
          error: e, stackTrace: s);
    }

      // A recovery session is temporary. Sign it out so the
      // user explicitly signs in again with the new password and chosen role.
      await client.auth.signOut();
      _verifiedUserId = null;
      _verifiedEmail = null;
      _verifiedGeneration = null;
    } on PasswordAuthException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } on AuthException catch (e) {
      _logDiagnostic(
        'updatePassword',
        code: e.code,
        statusCode: e.statusCode,
        reason: 'auth_exception',
      );
      throw PasswordAuthException(
        _authMessage(e),
        code: e.code,
        statusCode: e.statusCode,
        cause: e,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message =
          details is Map ? details['error']?.toString() : details?.toString();
      throw PasswordAuthException(
        message ?? e.reasonPhrase ?? 'Account activation failed.',
        cause: e,
      );
    } catch (e) {
      _logDiagnostic('updatePassword', reason: 'unexpected_error');
      throw PasswordAuthException(
        'Unable to connect. Please check your internet connection.',
        cause: e,
      );
    } finally {
      _updatingInFlight = false;
      _isFlowActive = false;
    }
  }

  static SupabaseClient? get _clientOrNull {
    if (debugClient != null) return debugClient;
    if (!SupabaseConfig.isInitialized) return null;
    return Supabase.instance.client;
  }

  static SupabaseClient get _client {
    final client = _clientOrNull;
    if (client == null) {
      throw const PasswordAuthException(
        'Password recovery is not available right now.',
        code: 'client_unavailable',
      );
    }
    return client;
  }

  static String formatErrorMessage(Object error) =>
      PasswordChangeService.formatErrorMessage(error);

  static String _authMessage(AuthException error, {String? codeHash}) {
    if (codeHash != null && _usedCodeHashes.contains(codeHash)) {
      return 'This verification code has already been used. Request a new code.';
    }
    if (codeHash != null && _supersededCodeHashes.contains(codeHash)) {
      return 'This verification code has expired because a new code was requested. Enter the latest code.';
    }

    final msg = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    final status = (error.statusCode ?? '').toLowerCase();

    if (status == '429' ||
        code.contains('rate') ||
        msg.contains('rate') ||
        msg.contains('too many') ||
        msg.contains('security purposes')) {
      return 'Too many attempts. Please wait before requesting another code.';
    }
    if (code == 'otp_used' ||
        msg.contains('already been used') ||
        msg.contains('already used')) {
      return 'This verification code has already been used. Request a new code.';
    }
    if (msg.contains('same_password') ||
        code == 'same_password' ||
        msg.contains('different from the old password')) {
      return 'New password must be different from your current password.';
    }
    if (code == 'otp_invalid' ||
        (msg.contains('invalid') && !msg.contains('expired'))) {
      return 'Invalid verification code. Please check the 6-digit code and try again.';
    }
    if (msg.contains('expired') && msg.contains('invalid')) {
      final sentAt = _lastOtpSentAt;
      if (sentAt != null &&
          DateTime.now().difference(sentAt) < const Duration(minutes: 55)) {
        return 'Invalid verification code. Please check the 6-digit code and try again.';
      }
      return 'Invalid or expired verification code. Check the latest code sent to your email or request a new code.';
    }
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'This verification code has expired. Request a new code.';
    }
    if (msg.contains('invalid') || msg.contains('token')) {
      return 'Invalid verification code. Please check the 6-digit code and try again.';
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
      '[SakayTa][PasswordRecoveryService] op=$operation '
      'code=${code ?? 'none'} status=${statusCode ?? 'none'} '
      'reason=${reason ?? 'unspecified'}',
    );
  }
}
