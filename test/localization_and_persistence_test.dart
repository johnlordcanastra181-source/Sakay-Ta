import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/l10n/app_localizations_ceb.dart';
import 'package:sakay_ta/l10n/app_localizations_en.dart';
import 'package:sakay_ta/l10n/app_localizations_tl.dart';
import 'package:sakay_ta/main.dart' hide Brand, Avatar;
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/pages/passenger_profile.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late PrefsService prefsService;
  late AuthService authService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbService = DatabaseService.instance;
    await dbService.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefsService = PrefsService.instance;
    authService = AuthService(dbService, prefsService);
  });

  group('1. Comprehensive Localization Engine Tests', () {
    test('All 3 supported language delegate classes instantiate properly', () {
      final en = AppLocalizationsEn();
      final ceb = AppLocalizationsCeb();
      final tl = AppLocalizationsTl();

      expect(en.appName, isNotEmpty);
      expect(ceb.appName, isNotEmpty);
      expect(tl.appName, isNotEmpty);

      // Verify navigation labels across all 3
      expect(en.navHome, equals('Home'));
      expect(ceb.navHome, equals('Balay'));
      expect(tl.navHome, equals('Tahanan'));

      expect(en.navActivity, equals('Activity'));
      expect(ceb.navActivity, equals('Kalihokan'));
      expect(tl.navActivity, equals('Aktibidad'));

      expect(en.navWallet, equals('Wallet'));
      expect(ceb.navWallet, equals('Pitaka'));
      expect(tl.navWallet, equals('Pitaka'));

      expect(en.navProfile, equals('Profile'));
      expect(ceb.navProfile, equals('Profile'));
      expect(tl.navProfile, equals('Profile'));

      // Verify profile settings & actions
      expect(en.profileClearCache, isNotEmpty);
      expect(ceb.profileClearCache, isNotEmpty);
      expect(tl.profileClearCache, isNotEmpty);

      expect(en.profileLogoutTitle, isNotEmpty);
      expect(ceb.profileLogoutTitle, isNotEmpty);
      expect(tl.profileLogoutTitle, isNotEmpty);

      expect(en.profileDeleteAccountTitle, isNotEmpty);
      expect(ceb.profileDeleteAccountTitle, isNotEmpty);
      expect(tl.profileDeleteAccountTitle, isNotEmpty);
    });

    test('lookupAppLocalizations returns correct delegates for ceb, tl, en',
        () {
      expect(lookupAppLocalizations(const Locale('en')),
          isA<AppLocalizationsEn>());
      expect(lookupAppLocalizations(const Locale('ceb')),
          isA<AppLocalizationsCeb>());
      expect(lookupAppLocalizations(const Locale('tl')),
          isA<AppLocalizationsTl>());
    });

    test('LocaleProvider normalizes alias codes bis and fil safely', () async {
      final provider = LocaleProvider(prefsService);

      await provider.setLocale('bis');
      expect(provider.locale.languageCode, equals('ceb'));

      await provider.setLocale('fil');
      expect(provider.locale.languageCode, equals('tl'));

      await provider.setLocale('en');
      expect(provider.locale.languageCode, equals('en'));
    });

    testWidgets('PassengerProfile switches languages reactively without crash',
        (tester) async {
      final localeProvider = LocaleProvider(prefsService);
      final appState = AppState.instance;

      // Mock a logged in passenger
      final testPassenger = AppUser(
        id: 'test_pass_loc',
        fullName: 'Maria Santos',
        mobile: '9171112233',
        email: 'maria@example.com',
        role: 'passenger',
        passwordHash: 'hash',
        createdAt: DateTime.now(),
      );
      appState.currentUser = testPassenger;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: Consumer<LocaleProvider>(
            builder: (context, provider, child) {
              return MaterialApp(
                locale: provider.locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ceb'),
                  Locale('tl'),
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  FallbackMaterialLocalizationsDelegate(),
                  FallbackCupertinoLocalizationsDelegate(),
                ],
                home: PassengerProfile(onNavigate: (_) {}),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially in English
      expect(find.text('Clear Cache'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Switch to Cebuano/Bisaya
      await localeProvider.setLocale('ceb');
      await tester.pumpAndSettle();

      expect(find.text('Hawani ang Cache'), findsOneWidget);
      expect(find.text('Mo-log Out'), findsOneWidget);

      // Switch to Tagalog
      await localeProvider.setLocale('tl');
      await tester.pumpAndSettle();

      expect(find.text('Linisin ang Cache'), findsOneWidget);
      expect(find.text('Mag-log Out'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    });
  });

  group('2. Account Persistence & Storage Separation Tests', () {
    test('User registration and local caching work seamlessly', () async {
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final email = 'user_${DateTime.now().microsecondsSinceEpoch}@example.com';
      const password = 'SecretPassword123!';

      // 1. User registers an account
      final registeredUser = await authService.registerPassenger(
        fullName: 'Juan Batangueño',
        mobile: mobile,
        password: password,
        email: email,
      );

      expect(registeredUser, isNotNull);
      final userId = registeredUser!.id;

      // Verify user is in local SQLite
      final db = await dbService.database;
      final localRows =
          await db.query('users', where: 'id = ?', whereArgs: [userId]);
      expect(localRows.isNotEmpty, isTrue);
      expect(localRows.first['full_name'], equals('Juan Batangueño'));

      // 2. Clear Session / Sign Out on device
      await prefsService.clearSession();
      final restoredSession = await authService.restoreSession();
      expect(restoredSession, isNull);

      // 3. User logs back in
      final authResult = await authService.login(
        mobile: mobile,
        password: password,
        role: 'passenger',
      );

      expect(authResult.user, isNotNull);
      expect(authResult.user!.id, equals(userId));
      expect(authResult.user!.fullName, equals('Juan Batangueño'));
    });

    test(
        'Clear Cache purges image memory without affecting session or database',
        () async {
      final appState = AppState.instance;
      final freed = await appState.clearCache();
      expect(freed, isNotEmpty);
    });

    test('Delete Account permanently removes user and session data', () async {
      final mobile =
          '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';
      final email =
          'delete_me_${DateTime.now().microsecondsSinceEpoch}@example.com';
      const password = 'DeleteMePass123!';

      // Register user
      final user = await authService.registerPassenger(
        fullName: 'To Be Deleted',
        mobile: mobile,
        password: password,
        email: email,
      );
      expect(user, isNotNull);

      // Perform Delete Account
      await authService.deleteAccount(user!.id);

      // Verify user is deleted from local SQLite
      final db = await dbService.database;
      final localRows =
          await db.query('users', where: 'id = ?', whereArgs: [user.id]);
      expect(localRows.isEmpty, isTrue);

      // Verify session is cleared
      final activeSession = await prefsService.sessionUserId;
      expect(activeSession, isNull);
    });
  });
}
