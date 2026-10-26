import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/core/neumorphic_theme.dart';
import 'package:sakay_ta/core/theme.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart' hide Brand, Avatar;
import 'package:sakay_ta/pages/login_page.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/neumorphic_widgets.dart';

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

  Widget wrapWithTheme(Widget child, {bool isDark = false}) {
    return MaterialApp(
      theme: SakayTheme.light(),
      darkTheme: SakayTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  Widget createLoginTestWidget(AppState app, {bool isDark = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(app.prefs)),
      ],
      child: Consumer<AppState>(
        builder: (context, state, child) => MaterialApp(
          theme: SakayTheme.light(),
          darkTheme: SakayTheme.dark(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginPage(onNavigate: (_) {}),
        ),
      ),
    );
  }

  group('NeumorphicTextField Design & Overflow Contract Tests', () {
    testWidgets(
        '1. NeumorphicTextField overrides theme filled background with transparent fill and clipBehavior',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: NeumorphicTextField(
              hintText: 'Enter destination...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify outer AnimatedContainer has clipBehavior: Clip.antiAlias
      final animatedContainerFinder = find.byType(AnimatedContainer);
      expect(animatedContainerFinder, findsOneWidget);
      final animatedContainer =
          tester.widget<AnimatedContainer>(animatedContainerFinder);
      expect(animatedContainer.clipBehavior, Clip.antiAlias);

      // Verify TextField InputDecoration properties
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration!;

      // Background must NOT inherit Theme's white filled rectangle
      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, Colors.transparent);
      expect(decoration.isDense, isTrue);

      // Icon constraints must be tightly bounded
      expect(decoration.prefixIconConstraints,
          const BoxConstraints(minWidth: 44, minHeight: 44));
      expect(decoration.suffixIconConstraints,
          const BoxConstraints(minWidth: 44, minHeight: 44));

      // All borders must be InputBorder.none to prevent duplicate rectangles
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
    });

    testWidgets(
        '2. NeumorphicTextField respects external FocusNode and smoothly toggles focus',
        (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        wrapWithTheme(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: NeumorphicTextField(
              hintText: 'Search destination...',
              focusNode: focusNode,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedContainerBefore =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decBefore =
          animatedContainerBefore.decoration as BoxDecoration;
      expect(decBefore.border?.top.color, const Color(0xFFDDE3ED));

      // Request focus
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final animatedContainerAfter =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decAfter = animatedContainerAfter.decoration as BoxDecoration;
      expect(decAfter.border?.top.color, NeumorphicColors.brandPrimary);
      expect(decAfter.border?.top.width, 1.6);

      focusNode.dispose();
    });
  });

  group('Login Page Email & Password Neumorphic Fields Verification', () {
    testWidgets(
        '3. Both Email and Password in LoginPage use unified NeumorphicTextFields',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Must find 2 NeumorphicTextField widgets on the login screen
      final fieldsFinder = find.byType(NeumorphicTextField);
      expect(fieldsFinder, findsNWidgets(2));

      // Verify Email icon and Password lock icon exist
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Verify initial password visibility icon
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Verify password text field is obscured initially
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, 2);
      final emailField = textFields[0];
      final passwordField = textFields[1];

      expect(emailField.obscureText, isFalse);
      expect(passwordField.obscureText, isTrue);

      // Verify both fields have filled == false (no white rogue box)
      expect(emailField.decoration?.filled, isFalse);
      expect(emailField.decoration?.fillColor, Colors.transparent);
      expect(passwordField.decoration?.filled, isFalse);
      expect(passwordField.decoration?.fillColor, Colors.transparent);
    });

    testWidgets(
        '4. Password visibility toggle works cleanly without changing layout or overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;
      await tester.pumpWidget(createLoginTestWidget(app));
      await tester.pumpAndSettle();

      // Tap the show/hide password toggle button
      final toggleFinder = find.byIcon(Icons.visibility_off_outlined);
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Visibility icon flipped to visibility_rounded
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      // Password is now un-obscured
      final textFieldsAfter =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFieldsAfter[1].obscureText, isFalse);

      // Tap again to obscure
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      final textFieldsFinal =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFieldsFinal[1].obscureText, isTrue);
    });

    testWidgets(
        '5. Small screen (320px) and Dark Mode render without RenderFlex overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final app = AppState.instance;

      // Light Mode test on narrow screen
      await tester.pumpWidget(createLoginTestWidget(app, isDark: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dark Mode test on narrow screen
      await tester.pumpWidget(createLoginTestWidget(app, isDark: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Passenger Home Search Destination & Registration Fields Contracts', () {
    test('6. Passenger Home Search Destination has seamless inset decoration and transparent fill', () {
      final file = File('lib/pages/passenger_home.dart');
      final source = file.readAsStringSync();

      expect(source.contains('clipBehavior: Clip.antiAlias'), isTrue);
      expect(source.contains('isDense: true'), isTrue);
      expect(source.contains('filled: false'), isTrue);
      expect(source.contains('fillColor: Colors.transparent'), isTrue);
      expect(source.contains('prefixIconConstraints:\n                                        const BoxConstraints(\n                                            minWidth: 42, minHeight: 42)') ||
          source.contains('minWidth: 42, minHeight: 42'), isTrue);
      expect(source.contains('suffixIconConstraints:\n                                        const BoxConstraints(\n                                            minWidth: 42, minHeight: 42)') ||
          source.contains('minWidth: 42, minHeight: 42'), isTrue);
      expect(source.contains('Icons.search_rounded'), isTrue);
      expect(source.contains('ClearDestinationEvent'), isTrue);
    });

    test('7. Passenger Signup and Driver Registration fields prevent white fill and duplicate borders', () {
      final signupSource = File('lib/pages/passenger_signup.dart').readAsStringSync();
      expect(signupSource.contains('clipBehavior: Clip.antiAlias'), isTrue);
      expect(signupSource.contains('isDense: true'), isTrue);
      expect(signupSource.contains('filled: false'), isTrue);
      expect(signupSource.contains('fillColor: Colors.transparent'), isTrue);
      expect(signupSource.contains('prefixIconConstraints:\n                  const BoxConstraints(minWidth: 44, minHeight: 44)') ||
          signupSource.contains('minWidth: 44, minHeight: 44'), isTrue);

      final driverSource = File('lib/pages/driver_registration.dart').readAsStringSync();
      expect(driverSource.contains('clipBehavior: Clip.antiAlias'), isTrue);
      expect(driverSource.contains('isDense: true'), isTrue);
      expect(driverSource.contains('filled: false'), isTrue);
      expect(driverSource.contains('fillColor: Colors.transparent'), isTrue);
      expect(driverSource.contains('suffixIconConstraints:\n              const BoxConstraints(minWidth: 40, minHeight: 40)') ||
          driverSource.contains('minWidth: 40, minHeight: 40'), isTrue);
    });
  });
}

