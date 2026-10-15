import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/services/magic_link_service.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late MagicLinkService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE magic_links (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              mobile TEXT NOT NULL,
              token TEXT NOT NULL UNIQUE,
              purpose TEXT NOT NULL DEFAULT 'signup',
              is_used INTEGER NOT NULL DEFAULT 0,
              expires_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    service = MagicLinkService(() async => db);
  });

  tearDown(() async {
    await db.close();
  });

  test('requestMagicLink creates a free wa.me link and stores the token',
      () async {
    final result =
        await service.requestMagicLink(mobile: '+639123456789');

    expect(result.mobile, '+639123456789');
    expect(result.token, isNotEmpty);
    expect(result.deepLink, startsWith('sakayta://auth/verify?token='));
    expect(result.deepLink, contains(result.token));
    expect(result.waMeUrl,
        startsWith('https://wa.me/639123456789?text=sakayta%3A%2F%2Fauth%2Fverify'));
  });

  test('requestMagicLink rejects malformed numbers', () async {
    expect(
      () => service.requestMagicLink(mobile: '+6391'),
      throwsA(isA<MagicLinkException>()),
    );
  });

  test('verifyToken verifies the fresh token and marks it used', () async {
    final result =
        await service.requestMagicLink(mobile: '+639123456789');

    final first = await service.verifyToken(result.token);
    expect(first.status, MagicLinkVerificationStatus.verified);
    expect(first.mobile, '+639123456789');

    final second = await service.verifyToken(result.token);
    expect(second.status, MagicLinkVerificationStatus.alreadyUsed);
  });

  test('verifyToken rejects unknown tokens', () async {
    final result = await service.verifyToken('not-a-real-token');
    expect(result.status, MagicLinkVerificationStatus.notFound);
  });

  test('verifyToken rejects expired links', () async {
    final result =
        await service.requestMagicLink(mobile: '+639123456789');
    await db.update(
      'magic_links',
      {'expires_at': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch},
      where: 'token = ?',
      whereArgs: [result.token],
    );

    final verify = await service.verifyToken(result.token);
    expect(verify.status, MagicLinkVerificationStatus.expired);
  });

  test('requestMagicLink enforces a resend cooldown', () async {
    await service.requestMagicLink(mobile: '+639123456789');
    expect(
      () => service.requestMagicLink(mobile: '+639123456789'),
      throwsA(isA<MagicLinkException>()),
    );
  });

  test('tokenFromLink parses the deep link', () {
    final uri = Uri.parse(
        'sakayta://auth/verify?token=abc123&mobile=%2B639123456789');
    expect(MagicLinkService.tokenFromLink(uri), 'abc123');

    expect(
      MagicLinkService.tokenFromLink(Uri.parse('https://example.com/x')),
      isNull,
    );
  });
}
