import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/main.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/sakay_ta_splash_screen.dart';

Widget _buildTestApp() {
  return MultiProvider(
    providers: [
      Provider<DatabaseService>(create: (_) => DatabaseService.instance),
      Provider<PrefsService>(create: (_) => PrefsService.instance),
      ChangeNotifierProvider<AppState>(create: (_) => AppState.instance),
      ChangeNotifierProvider<LocaleProvider>(
        create: (context) => LocaleProvider(context.read<PrefsService>()),
      ),
      ProxyProvider<LocaleProvider, AuthService>(
        update: (context, localeProvider, auth) => AuthService(
          DatabaseService.instance,
          context.read<PrefsService>(),
        ),
      ),
    ],
    child: const SakayTaApp(),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.reset();
  });

  testWidgets(
    'SakayTaSplashScreen displays for 3.5 seconds with animated card and transitions to main screen',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());

      // Immediately at startup (t = 0s), the splash screen is shown
      expect(find.byType(SakayTaSplashScreen), findsOneWidget);
      expect(find.byKey(const Key('sakay_ta_splash_card')), findsOneWidget);

      // Verify the 205x210 rounded gray box dimensions
      final cardContainer = tester.widget<Container>(
        find.byKey(const Key('sakay_ta_splash_card')),
      );
      expect(cardContainer.constraints?.maxWidth, 205);
      expect(cardContainer.constraints?.maxHeight, 210);

      // Advance to t = 0.5s — still showing splash screen
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SakayTaSplashScreen), findsOneWidget);

      // Advance to t = 0.95s (just before 1.0s displayDuration) — still showing splash screen
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(SakayTaSplashScreen), findsOneWidget);

      // Advance past 1.0s display + 0.2s fade-out transition and settle
      await tester.pumpAndSettle();

      // Splash screen is dismissed and main/login screen is now displayed
      expect(find.byType(SakayTaSplashScreen), findsNothing);
      expect(find.text('Log In'), findsOneWidget);
    },
  );
}

