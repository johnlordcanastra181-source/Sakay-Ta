import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

/// Supabase password-recovery helpers shared by the passenger, driver, and
/// admin login experiences. No password is ever read or persisted here.
abstract final class PasswordRecoveryService {
  static bool get hasRecoverySession =>
      SupabaseConfig.isInitialized &&
      Supabase.instance.client.auth.currentSession != null;

  static Future<void> sendRecoveryEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (!SupabaseConfig.isInitialized) {
      throw StateError('Password recovery is not available right now.');
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(normalized);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('rate_limit')) {
        throw StateError(
            'Too many attempts. Please wait before requesting another code.');
      }
      throw StateError(e.message);
    } catch (e) {
      throw StateError(
          'Unable to connect. Please check your internet connection.');
    }
  }

  static Future<void> verifyRecoveryOtp(String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    if (normalizedEmail.isEmpty) throw ArgumentError('Email is required.');
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Verification code is required.');
    }
    if (!SupabaseConfig.isInitialized) {
      throw StateError('Password recovery is not available right now.');
    }

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedCode,
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired')) {
        throw StateError(
            'This verification code has expired. Request a new code.');
      }
      if (msg.contains('invalid') || msg.contains('token')) {
        throw StateError('Invalid verification code.');
      }
      if (msg.contains('rate_limit')) {
        throw StateError(
            'Too many attempts. Please wait before requesting another code.');
      }
      throw StateError(e.message);
    } catch (e) {
      throw StateError(
          'Unable to connect. Please check your internet connection.');
    }
  }

  static Future<void> updatePassword(String password) async {
    if (!SupabaseConfig.isInitialized || !hasRecoverySession) {
      throw StateError(
        'This recovery link is invalid or has expired. Request a new one.',
      );
    }
    if (password.length < 6) {
      throw ArgumentError('Use at least 6 characters for your new password.');
    }
    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(UserAttributes(password: password));

      // Admin-invited Drivers carry this marker in Auth metadata. Activate the
      // profile only after the invitee has set a password using the trusted
      // session from the activation link.
      final isDriverInvite =
          client.auth.currentUser?.userMetadata?['driver_application_id'] !=
              null;
      if (isDriverInvite) {
        final activation = await client.functions.invoke(
          'driver-applications',
          body: {'action': 'activate'},
        );
        if (activation.status < 200 || activation.status >= 300) {
          final details = activation.data;
          final message = details is Map ? details['error']?.toString() : null;
          throw StateError(
              message ?? 'Driver account activation could not be confirmed.');
        }
        final result = activation.data;
        if (result is! Map || result['activated'] != true) {
          throw StateError('Driver account activation could not be confirmed.');
        }
      }
      // A recovery session is temporary. Sign it out so the
      // user explicitly signs in again with the new password and chosen role.
      await client.auth.signOut();
    } on StateError {
      rethrow;
    } on AuthException catch (e) {
      throw StateError(e.message);
    } on FunctionException catch (e) {
      final details = e.details;
      final message =
          details is Map ? details['error']?.toString() : details?.toString();
      throw StateError(
          message ?? e.reasonPhrase ?? 'Account activation failed.');
    } catch (e) {
      throw StateError(
          'Unable to connect. Please check your internet connection.');
    }
  }
}
