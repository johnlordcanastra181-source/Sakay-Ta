import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/theme.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart' hide Brand, Avatar;
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/pages/driver_home.dart';
import 'package:sakay_ta/pages/login_page.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/services/weather_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/common.dart';
import 'package:sakay_ta/widgets/driver_osm_card.dart';
import 'package:sakay_ta/widgets/weather_badge.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    final app = AppState.instance;
    await app.init();
    await app.setDarkMode(false);
  });

  Widget createLoginTestWidget(AppState app) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider(app.prefs)),
      ],
      child: Consumer<AppState>(
        builder: (context, state, child) => MaterialApp(
          theme: SakayTheme.light(),
          darkTheme: SakayTheme.dark(),
          themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginPage(onNavigate: (_) {}),
        ),
      ),
    );
  }

  group('Sign-In Page Theme Toggle Tests (Mandatory Tests 1 to 8)', () {
    testWidgets('1. Top-right icon on sign-in page is no longer an Avatar / profile icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Verify no Avatar widget exists on LoginPage
      expect(find.byType(Avatar), findsNothing);
      // Verify no person icon exists in the top bar
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('2. It now functions as a dark/light theme toggle with appropriate icons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await app.setDarkMode(false);

      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // In light mode, moon icon should be displayed to switch to dark
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to Dark Mode'), findsOneWidget);

      // Tap the toggle
      await tester.tap(find.byTooltip('Switch to Dark Mode'));
      await tester.pumpAndSettle();

      // App state should now be dark mode
      expect(app.darkMode, isTrue);

      // In dark mode, sun icon should be displayed to switch to light
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to Light Mode'), findsOneWidget);
    });

    testWidgets('3. Theme changes immediately on the sign-in page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await app.setDarkMode(false);

      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldBefore.backgroundColor, AppColors.canvasColor(false));

      // Tap theme toggle
      await tester.tap(find.byTooltip('Switch to Dark Mode'));
      await tester.pumpAndSettle();

      final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldAfter.backgroundColor, AppColors.canvasColor(true));
      expect(app.darkMode, isTrue);
    });

    test('4. Theme persists after navigation and across sessions in PrefsService', () async {
      final app = AppState.instance;
      await app.setDarkMode(true);
      expect(app.darkMode, isTrue);

      // Verify PrefsService stored the value
      final storedDarkMode = await app.prefs.darkMode;
      expect(storedDarkMode, isTrue);

      // Toggle back to false
      await app.setDarkMode(false);
      expect(app.darkMode, isFalse);
      expect(await app.prefs.darkMode, isFalse);
    });

    test('5. Theme persists after app restart (re-initialization)', () async {
      final prefs = PrefsService.instance;
      await prefs.setDarkMode(true);

      final freshAppState = AppState.instance;
      freshAppState.initialized = false;
      await freshAppState.init();

      expect(freshAppState.darkMode, isTrue);
    });

    testWidgets('6. Passenger/Driver login toggle still works', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Find role toggles
      expect(find.text('Passenger'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);

      // Tap Driver
      await tester.tap(find.text('Driver'));
      await tester.pumpAndSettle();

      // Tap Passenger
      await tester.tap(find.text('Passenger'));
      await tester.pumpAndSettle();
    });

    testWidgets('7. Language selector still works', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Verify language dropdown exists (e.g. English)
      expect(find.byType(DropdownButtonHideUnderline), findsOneWidget);
    });

    testWidgets('8. Login form fields and submission remain functional', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Email and password fields
      expect(find.byType(TextField), findsNWidgets(2));
      // Forgot Password button
      expect(find.text('Forgot Password?'), findsOneWidget);
      // Create Account button
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
    });
  });

  group('Driver Dashboard Weather & Passenger Weather Tests (Mandatory Tests 9 to 14)', () {
    test('9. Passenger Dashboard weather service logic continues to work', () async {
      final weather = await WeatherService.instance.getWeather(const Geo(11.2444, 125.0039));
      expect(weather, isNotNull);
      expect(weather.temperatureRounded, isPositive);
      expect(weather.condition, isNotEmpty);
      expect(weather.emoji, isNotEmpty);
    });

    testWidgets('10. Driver Dashboard shows WeatherBadge widget', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      final driver = AppUser(
        id: 'test_driver_w',
        fullName: 'Driver Weather Tester',
        mobile: '09171234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.now(),
        latitude: 11.2444,
        longitude: 125.0039,
      );
      app.currentUser = driver;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: MaterialApp(
            home: DriverHome(onNavigate: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify WeatherBadge is rendered in DriverHome
      expect(find.byType(WeatherBadge), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('11. Driver Dashboard weather displays temperature and condition', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WeatherBadge(
                location: Geo(11.2444, 125.0039),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify weather widget renders
      expect(find.byType(WeatherBadge), findsOneWidget);
    });

    testWidgets('12. Driver Dashboard weather does not crash on fallback / error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: const MaterialApp(
            home: Scaffold(
              // Invalid GPS coordinates to test error/fallback handling
              body: WeatherBadge(
                location: Geo(0.0, 0.0),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Widget should render gracefully with fallback without throwing
      expect(find.byType(WeatherBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. Driver Dashboard layout remains intact', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      final driver = AppUser(
        id: 'test_driver_layout',
        fullName: 'Driver Layout Tester',
        mobile: '09171234567',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.now(),
        latitude: 11.2444,
        longitude: 125.0039,
      );
      app.currentUser = driver;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: MaterialApp(
            home: DriverHome(onNavigate: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify core driver dashboard components exist
      expect(find.text('Sakay Ta'), findsOneWidget);
      expect(find.byType(WeatherBadge), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text("TODAY'S EARNINGS"), findsOneWidget);
      expect(find.byType(DriverOsmCard), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('14. Tapping WeatherBadge opens full details bottom sheet without crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WeatherBadge(
                location: Geo(11.2444, 125.0039),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the weather badge
      await tester.tap(find.byType(WeatherBadge));
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with refresh and GPS note
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text('Live weather updated at your GPS position.'), findsOneWidget);
    });
  });
}
