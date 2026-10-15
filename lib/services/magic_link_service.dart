import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../core/logger.dart';
import '../core/phone_utils.dart';
import 'database_service.dart';
import 'supabase_service.dart';

/// Friendly, user-facing failure thrown when a Magic Link cannot be created.
class MagicLinkException implements Exception {
  final String message;
  MagicLinkException(this.message);

  @override
  String toString() => message;
}

enum MagicLinkVerificationStatus {
  verified,
  notFound,
  expired,
  alreadyUsed,
}

class MagicLinkRecord {
  final int id;
  final String mobile;
  final String token;
  final String purpose;
  final bool isUsed;
  final DateTime expiresAt;
  final DateTime createdAt;

  MagicLinkRecord({
    required this.id,
    required this.mobile,
    required this.token,
    required this.purpose,
    required this.isUsed,
    required this.expiresAt,
    required this.createdAt,
  });

  factory MagicLinkRecord.fromMap(Map<String, Object?> map) => MagicLinkRecord(
        id: map['id'] as int,
        mobile: map['mobile'] as String,
        token: map['token'] as String,
        purpose: (map['purpose'] as String?) ?? 'signup',
        isUsed: ((map['is_used'] as int?) ?? 0) == 1,
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

/// Generates, stores, delivers, and verifies signed Magic Links.
///
/// The full flow is traced through [AppLog]:
///  1. Request received for an E.164 number
///  2. Token generated and stored with a 15-minute expiry
///  3. `sakayta://auth/verify?token=...` deep link handed to the caller
///  4. Verification attempt against the stored token
///
/// Delivery is intentionally decoupled: this service returns the deep link
/// and the UI delivers it (wa.me deep link for WhatsApp, or an on-screen
/// copy/simulate fallback in demo mode). This keeps the flow 100% free.
class MagicLinkService {
  /// Production constructor backed by the app's SQLite database.
  MagicLinkService.database(DatabaseService db) : _db = (() => db.database);

  /// Test-friendly constructor backed by any [ffi.Database] provider.
  MagicLinkService(this._db);

  static const String tag = 'MagicLinkService';

  /// Custom URL scheme/host used by the deep link.
  static const String scheme = 'sakayta';
  static const String host = 'auth';

  /// How long a Magic Link remains valid once issued.
  static const Duration tokenTtl = Duration(minutes: 15);

  /// Cooldown before a new link can be requested for the same number.
  static const Duration resendCooldown = Duration(seconds: 30);

  final Future<ffi.Database> Function() _db;
  final Random _random = Random.secure();

  Future<ffi.Database> get _database => _db();

  /// Generates a cryptographically random, URL-safe token (e.g. "kZ9...xQ").
  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64Url
        .encode(bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
    AppLog.d(tag, 'Generated Magic Link token (length=${token.length})');
    return token;
  }

  /// Builds the deep link URI the user taps to verify.
  String buildDeepLink({required String mobile, required String token}) =>
      '$scheme://$host/verify?token=$token&mobile=$mobile';

  /// Builds the free `wa.me` URL that opens WhatsApp with the Magic Link
  /// pre-filled (no API, no Meta account, no cost).
  String buildWaMeUrl({required String mobile, required String token}) {
    final national = mobile.replaceAll('+', '').replaceAll(' ', '');
    final link = buildDeepLink(mobile: mobile, token: token);
    return 'https://wa.me/$national?text=${Uri.encodeComponent(link)}';
  }

  /// Requests a new Magic Link for [mobile] (E.164, e.g. "+639123456789").
  ///
  /// Generates a signed token, stores it with a 15-minute expiry, and returns
  /// the deep link + token. Returns null-mobile validation handled by caller
  /// via [MagicLinkException].
  /// [purpose] is 'signup' or 'login' and is stored with the record.
  Future<({String deepLink, String waMeUrl, String token, String mobile})>
      requestMagicLink({
    required String mobile,
    String purpose = 'signup',
  }) async {
    final normalized = PhoneUtils.normalizeToInternational(mobile);
    if (normalized == null) {
      AppLog.w(
          tag, 'Rejected Magic Link request for malformed number: "$mobile"');
      throw MagicLinkException('Invalid phone number format.');
    }

    AppLog.i(tag, 'Magic Link request received for $normalized ($purpose)');
    final database = await _database;

    await _purgeExpired(database);

    final previous = await _latestRecord(database, normalized);
    if (previous != null) {
      final now = DateTime.now();
      final cooldownUntil = previous.createdAt.add(resendCooldown);
      if (now.isBefore(cooldownUntil)) {
        final wait = cooldownUntil.difference(now).inSeconds + 1;
        AppLog.w(tag, 'Resend cooldown active for $normalized');
        throw MagicLinkException(
            'Please wait ${wait}s before requesting a new link.');
      }
    }

    final token = _generateToken();
    final now = DateTime.now();
    await database
        .delete('magic_links', where: 'mobile = ?', whereArgs: [normalized]);
    await database.insert('magic_links', {
      'mobile': normalized,
      'token': token,
      'purpose': purpose,
      'is_used': 0,
      'expires_at': now.add(tokenTtl).millisecondsSinceEpoch,
      'created_at': now.millisecondsSinceEpoch,
    });
    if (SupabaseService.isConfigured) {
      await SupabaseService.instance.saveMagicLink({
        'id': token,
        'phoneNumber': normalized,
        'mobile': normalized,
        'token': token,
        'purpose': purpose,
        'isUsed': false,
        'is_used': 0,
        'expiry': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
    AppLog.i(
        tag,
        'Magic Link stored for $normalized '
        '(expires ${now.add(tokenTtl).toLocal()})');

    final deepLink = buildDeepLink(mobile: normalized, token: token);
    final waMeUrl = buildWaMeUrl(mobile: normalized, token: token);
    AppLog.i(tag, 'Deep link ready: $deepLink');

    return (
      deepLink: deepLink,
      waMeUrl: waMeUrl,
      token: token,
      mobile: normalized,
    );
  }

  /// Validates [token] against the stored record. Returns the verified
  /// mobile number on success.
  Future<({MagicLinkVerificationStatus status, String? mobile})> verifyToken(
      String token) async {
    final clean = token.trim();
    AppLog.i(tag, 'Verification attempt for token (length=${clean.length})');

    if (SupabaseService.isConfigured) {
      final res = await SupabaseService.instance.verifyMagicLinkToken(clean);
      if (res.isValid && res.mobile != null) {
        return (
          status: MagicLinkVerificationStatus.verified,
          mobile: res.mobile,
        );
      } else if (res.status == 'alreadyUsed') {
        return (
          status: MagicLinkVerificationStatus.alreadyUsed,
          mobile: res.mobile,
        );
      } else if (res.status == 'expired') {
        return (
          status: MagicLinkVerificationStatus.expired,
          mobile: res.mobile,
        );
      }
    }

    final database = await _database;

    final record = await _recordForToken(database, clean);
    if (record == null) {
      AppLog.w(tag, 'No Magic Link found for token');
      return (status: MagicLinkVerificationStatus.notFound, mobile: null);
    }

    if (record.isUsed) {
      AppLog.w(tag, 'Magic Link already used for ${record.mobile}');
      return (
        status: MagicLinkVerificationStatus.alreadyUsed,
        mobile: record.mobile,
      );
    }

    if (DateTime.now().isAfter(record.expiresAt)) {
      AppLog.w(tag, 'Magic Link expired for ${record.mobile}');
      return (
        status: MagicLinkVerificationStatus.expired,
        mobile: record.mobile,
      );
    }

    await database.update(
      'magic_links',
      {'is_used': 1},
      where: 'id = ?',
      whereArgs: [record.id],
    );
    AppLog.i(tag, 'Magic Link verified successfully for ${record.mobile}');
    return (
      status: MagicLinkVerificationStatus.verified,
      mobile: record.mobile,
    );
  }

  /// Parses a `sakayta://auth/verify?token=...&mobile=...` URI.
  /// Returns the token, or null when the URI is not an auth link.
  static String? tokenFromLink(Uri uri) {
    if (uri.scheme != scheme || uri.host != host) return null;
    if (uri.pathSegments.contains('verify')) {
      return uri.queryParameters['token'];
    }
    return null;
  }

  Future<void> _purgeExpired(ffi.Database database) async {
    await database.delete(
      'magic_links',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<MagicLinkRecord?> _latestRecord(
      ffi.Database database, String mobile) async {
    final rows = await database.query(
      'magic_links',
      where: 'mobile = ?',
      whereArgs: [mobile],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MagicLinkRecord.fromMap(rows.first);
  }

  Future<MagicLinkRecord?> _recordForToken(
      ffi.Database database, String token) async {
    final rows = await database.query(
      'magic_links',
      where: 'token = ?',
      whereArgs: [token],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MagicLinkRecord.fromMap(rows.first);
  }
}
