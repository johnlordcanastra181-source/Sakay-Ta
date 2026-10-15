import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart';
import 'package:sakay_ta/pages/passenger_signup.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/state/auth_bloc.dart';

Widget _buildApp() {
  return MultiProvider(
    providers: [
      Provider<DatabaseService>(create: (_) => DatabaseService.instance),
      Provider<PrefsService>(create: (_) => PrefsService.instance),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState.instance,
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (context) => LocaleProvider(context.read<PrefsService>()),
      ),
      ProxyProvider<LocaleProvider, AuthService>(
        update: (context, localeProvider, auth) => AuthService(
          DatabaseService.instance,
          context.read<PrefsService>(),
        ),
      ),
      ChangeNotifierProvider<AuthBloc>(
        create: (context) => AuthBloc(authService: context.read<AuthService>()),
      ),
    ],
    child: const SakayTaApp(),
  );
}

Widget _buildSignup() {
  return MultiProvider(
    providers: [
      Provider<DatabaseService>(create: (_) => DatabaseService.instance),
      Provider<PrefsService>(create: (_) => PrefsService.instance),
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState.instance,
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (context) => LocaleProvider(context.read<PrefsService>()),
      ),
      ProxyProvider<LocaleProvider, AuthService>(
        update: (context, localeProvider, auth) => AuthService(
          DatabaseService.instance,
          context.read<PrefsService>(),
        ),
      ),
      ChangeNotifierProvider<AuthBloc>(
        create: (context) => AuthBloc(authService: context.read<AuthService>()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
      home: PassengerSignupPage(onNavigate: (_) {}),
    ),
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

  testWidgets('shows Sakay Ta login screen', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('signup rejects invalid email address', (tester) async {
    await tester.pumpWidget(_buildSignup());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Dela Cruz');
    await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');

    // Fill password
    final passwordField = find.byType(TextFormField).last;
    await tester.ensureVisible(passwordField);
    await tester.enterText(passwordField, 'password123');

    // Accept terms
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pumpAndSettle();

    final submitBtn = find.text('Create Account');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Scroll back to email field to ensure error text is rendered in viewport
    await tester.ensureVisible(find.byType(TextFormField).at(1));
    await tester.pumpAndSettle();

    expect(find.textContaining('valid email'), findsWidgets);
  });
}
