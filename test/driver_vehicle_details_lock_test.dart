import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/pages/passenger_profile.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'support/isolated_database.dart';

void main() {
  setUp(() async {
    await useIsolatedDatabase();
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppState.instance.currentUser = null;
    AppState.instance.driverProfile = null;
  });

  Widget buildTestWidget(AppState appState) {
    final prefs = PrefsService.instance;
    final localeProvider = LocaleProvider(prefs);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PassengerProfile(onNavigate: (_) {}),
      ),
    );
  }

  group('Driver Vehicle Details Lock & Conditional TODA Display', () {
    testWidgets(
        '1. Tricycle driver sees VEHICLE & TODA DETAILS and actual TODA affiliation, with NO Edit button',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      final appState = AppState.instance;

      final driverUser = AppUser(
        id: 'driver-tri-1',
        fullName: 'Juan Tricycle Driver',
        email: 'juan.tri@sakayta.ph',
        mobile: '09171112222',
        passwordHash: 'hash',
        role: UserRole.driver,
        status: AccountStatus.approved,
        createdAt: DateTime.now(),
      );

      final tricycleProfile = DriverProfile(
        userId: driverUser.id,
        vehicleType: VehicleType.tricycle,
        plateNumber: 'TRI-1234',
        make: 'Kawasaki',
        model: 'Barako II',
        color: 'Navy Blue',
        todaId: 'toda-tagb-7',
        todaName: 'TODA 7 - Tagbilaran Central',
        submittedAt: DateTime(2026, 1, 1),
      );

      appState.currentUser = driverUser;
      appState.driverProfile = tricycleProfile;

      await tester.pumpWidget(buildTestWidget(appState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Title must be VEHICLE & TODA DETAILS
      expect(find.text('VEHICLE & TODA DETAILS'), findsOneWidget);
      expect(find.text('VEHICLE DETAILS'), findsNothing);

      // Vehicle type label
      expect(find.text('Tricycle Unit'), findsOneWidget);
      expect(find.text('Habal-Habal Motorcycle'), findsNothing);

      // Vehicle details
      expect(find.text('TRI-1234'), findsOneWidget);
      expect(find.text('Kawasaki Barako II'), findsOneWidget);
      expect(find.text('Navy Blue'), findsOneWidget);

      // TODA row must be visible with actual TODA name
      expect(find.text('TODA Affiliation'), findsOneWidget);
      expect(find.text('TODA 7 - Tagbilaran Central'), findsOneWidget);

      // EDIT BUTTON MUST NOT EXIST
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets(
        '2. Tricycle driver with missing TODA displays "Not provided" placeholder',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      final appState = AppState.instance;

      final driverUser = AppUser(
        id: 'driver-tri-2',
        fullName: 'Pedro Independent Driver',
        email: 'pedro.tri@sakayta.ph',
        mobile: '09173334444',
        passwordHash: 'hash',
        role: UserRole.driver,
        status: AccountStatus.approved,
        createdAt: DateTime.now(),
      );

      final tricycleNoToda = DriverProfile(
        userId: driverUser.id,
        vehicleType: VehicleType.tricycle,
        plateNumber: 'TRI-5678',
        make: 'Bajaj',
        model: 'RE',
        color: 'Yellow',
        todaId: null,
        todaName: null, // missing TODA
        submittedAt: DateTime(2026, 1, 1),
      );

      appState.currentUser = driverUser;
      appState.driverProfile = tricycleNoToda;

      await tester.pumpWidget(buildTestWidget(appState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('VEHICLE & TODA DETAILS'), findsOneWidget);
      expect(find.text('TODA Affiliation'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      // Ensure it does NOT show hardcoded fake 'Tagbilaran TODA'
      expect(find.text('Tagbilaran TODA'), findsNothing);

      // NO Edit button
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets(
        '3. Habal-Habal Motorcycle driver sees VEHICLE DETAILS and NO TODA row, with NO Edit button',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      final appState = AppState.instance;

      final driverUser = AppUser(
        id: 'driver-habal-1',
        fullName: 'Mario Motorcycle Driver',
        email: 'mario.habal@sakayta.ph',
        mobile: '09175556666',
        passwordHash: 'hash',
        role: UserRole.driver,
        status: AccountStatus.approved,
        createdAt: DateTime.now(),
      );

      final habalProfile = DriverProfile(
        userId: driverUser.id,
        vehicleType: VehicleType.habal,
        plateNumber: 'MC-9999',
        make: 'Honda',
        model: 'TMX 125',
        color: 'Gloss Black',
        todaId: null,
        todaName: null,
        submittedAt: DateTime(2026, 1, 1),
      );

      appState.currentUser = driverUser;
      appState.driverProfile = habalProfile;

      await tester.pumpWidget(buildTestWidget(appState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Title must be VEHICLE DETAILS
      expect(find.text('VEHICLE DETAILS'), findsOneWidget);
      expect(find.text('VEHICLE & TODA DETAILS'), findsNothing);

      // Vehicle type label
      expect(find.text('Habal-Habal Motorcycle'), findsOneWidget);
      expect(find.text('Tricycle Unit'), findsNothing);

      // Vehicle details
      expect(find.text('MC-9999'), findsOneWidget);
      expect(find.text('Honda TMX 125'), findsOneWidget);
      expect(find.text('Gloss Black'), findsOneWidget);

      // TODA ROW MUST BE COMPLETELY OMITTED
      expect(find.text('TODA Affiliation'), findsNothing);
      expect(find.text('Tagbilaran TODA'), findsNothing);
      expect(find.text('Not provided'), findsNothing);
      expect(find.text('Not affiliated'), findsNothing);

      // EDIT BUTTON MUST NOT EXIST
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    test('4. AppState.updateDriverVehicleInfo throws UnsupportedError', () async {
      final appState = AppState.instance;

      expect(
        () => appState.updateDriverVehicleInfo(
          plateNumber: 'NEW-1234',
          make: 'Yamaha',
          model: 'Sniper',
          color: 'Red',
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Registered vehicle details cannot be modified'),
          ),
        ),
      );
    });

    testWidgets(
        '5. Preserved features: Profile photo avatar and online/offline toggle remain functional',
        (tester) async {
      debugDefaultTargetPlatformOverride = null;
      final appState = AppState.instance;

      final driverUser = AppUser(
        id: 'driver-test-features',
        fullName: 'Feature Test Driver',
        email: 'features@sakayta.ph',
        mobile: '09178889999',
        passwordHash: 'hash',
        role: UserRole.driver,
        status: AccountStatus.approved,
        isOnline: true,
        createdAt: DateTime.now(),
      );

      final profile = DriverProfile(
        userId: driverUser.id,
        vehicleType: VehicleType.tricycle,
        plateNumber: 'TRI-8888',
        make: 'Honda',
        model: 'TMX',
        color: 'Silver',
        submittedAt: DateTime(2026, 1, 1),
      );

      appState.currentUser = driverUser;
      appState.driverProfile = profile;

      await tester.pumpWidget(buildTestWidget(appState));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Online status switch exists and displays online text
      final onlineSwitchFinder = find.byWidgetPredicate(
        (w) => w is Switch && w.activeTrackColor == const Color(0xFF22C55E),
      );
      expect(onlineSwitchFinder, findsOneWidget);
      final onlineSwitch = tester.widget<Switch>(onlineSwitchFinder);
      expect(onlineSwitch.value, isTrue);
      expect(onlineSwitch.onChanged, isNotNull);
      expect(find.text('Online & Ready for Rides'), findsOneWidget);

      // Profile avatar with driver name exists
      expect(find.text('Feature Test Driver'), findsWidgets);
    });
  });
}

