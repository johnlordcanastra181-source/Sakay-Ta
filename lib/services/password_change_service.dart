import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

/// Secure password-change helpers for signed-in Passenger and Driver users.
///
/// Supabase sends the reauthentication OTP and enforces the resulting
/// reauthentication state. The client never stores an OTP, password, or
/// service-role credential, and the update is only attempted after the OTP
/// has been verified by Auth.
abstract final class PasswordChangeService {
  static Future<void> requestOtp() async {
    final client = _client;
    if (client.auth.currentUser == null || client.auth.currentSession == null) {
      throw StateError('Sign in before changing your password.');
    }
    try {
      await client.auth.reauthenticate();
    } on AuthException catch (error) {
      throw StateError(_authMessage(error));
    } catch (_) {
      throw StateError('Unable to send the verification code. Try again.');
    }
  }

  static Future<void> verifyAndUpdate({
    required String email,
    required String code,
    required String newPassword,
  }) async {
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
      throw StateError('Your session expired. Sign in again and retry.');
    }
    if (before.email?.trim().toLowerCase() != normalizedEmail) {
      throw StateError('The verification email does not match this account.');
    }

    try {
      final verification = await client.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedCode,
        type: OtpType.email,
      );
      final verifiedUser = verification.user ?? client.auth.currentUser;
      if (verifiedUser == null ||
          verifiedUser.id != before.id ||
          client.auth.currentSession == null) {
        throw StateError('Verification did not establish a valid session.');
      }

      // Supabase Secure Password Change must be enabled for the server to
      // require the reauthentication nonce before accepting this update.
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (error) {
      throw StateError(_authMessage(error));
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError('Unable to update the password. Try again.');
    }
  }

  static SupabaseClient get _client {
    if (!SupabaseConfig.isInitialized) {
      throw StateError('Password change is not available right now.');
    }
    return Supabase.instance.client;
  }

  static String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('expired')) {
      return 'This verification code has expired. Request a new code.';
    }
    if (message.contains('invalid') || message.contains('token')) {
      return 'Invalid verification code.';
    }
    if (message.contains('reauth') || message.contains('nonce')) {
      return 'Password reauthentication failed. Request a new code and try again.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait before requesting another code.';
    }
    return error.message;
  }
}
