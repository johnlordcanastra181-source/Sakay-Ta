import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart';
import 'package:sakay_ta/pages/passenger_signup.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/state/auth_bloc.dart';

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
      ChangeNotifierProxyProvider<AuthService, AuthBloc>(
        create: (context) => AuthBloc(authService: context.read<AuthService>()),
        update: (context, authService, bloc) =>
            bloc ?? AuthBloc(authService: authService),
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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
    await DatabaseService.instance.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signup with valid email does not open an OTP screen',
      (tester) async {
    await tester.pumpWidget(_buildSignup());
    await tester.pumpAndSettle();

    final testEmail = 'juan_${DateTime.now().microsecondsSinceEpoch}@gmail.com';
    final testMobile =
        '9${DateTime.now().microsecondsSinceEpoch.toString().substring(7, 16)}';

    // Fill in required text fields.
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Dela Cruz');
    await tester.enterText(find.byType(TextFormField).at(1), testEmail);
    await tester.enterText(find.byType(TextFormField).at(2), testMobile);

    // Scroll down to password and enter
    final passwordField =
        find.byWidgetPredicate((w) => w is EditableText && w.obscureText);
    await tester.ensureVisible(passwordField);
    await tester.pumpAndSettle();
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    // Scroll down to terms and tap
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Scroll down to submit button and tap
    final submitBtn = find.text('Create Account');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(submitBtn, warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 2000));
    });

    await tester.pumpAndSettle();
    expect(find.text('Verify Email Code'), findsNothing);
    expect(find.text('Send Email OTP Code'), findsNothing);
  });
}
