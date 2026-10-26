import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/philippine_time.dart';
import 'package:sakay_ta/core/supabase_config.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart' show LocaleProvider;
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/pages/driver_home.dart';
import 'package:sakay_ta/pages/passenger_profile.dart';
import 'package:sakay_ta/pages/ride_tracking.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/booking_confirmation_modal.dart';
import 'package:sakay_ta/widgets/driver_matching_bottom_sheet.dart';
import 'package:sakay_ta/widgets/rate_driver_modal.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PhilippineTime.initialize();
  });

  group('Systemic Security, Integrity, and Reliability Tests (18 Items)', () {
    test('Item 1: SupabaseConfig removes invalid hardcoded JWT and uses client-safe publishable key', () {
      expect(SupabaseConfig.publishableKey.startsWith('eyJ'), isFalse);
      expect(SupabaseConfig.publishableKey.startsWith('sb_secret_'), isFalse);
      expect(SupabaseConfig.publishableKey.startsWith('sb_publishable_'), isTrue);
      expect(SupabaseConfig.isConfigured, isTrue);
    });

    test('Item 2: Bcrypt password hashing and backward-compatible FNV-1a verification', () {
      const secret = 'DriverSafePass#2026';
      final bcryptHash = DatabaseService.hashPassword(secret);

      // Must be salted bcrypt ($2a$ or $2b$)
      expect(bcryptHash.startsWith(r'$2'), isTrue);
      expect(DatabaseService.verifyPassword(secret, bcryptHash), isTrue);
      expect(DatabaseService.verifyPassword('WrongPass', bcryptHash), isFalse);

      // Legacy 8-char FNV-1a hash must still verify for seamless migration
      final legacyHash = DatabaseService.legacyFnv1aHash(secret);
      expect(legacyHash.length, 8);
      expect(DatabaseService.verifyPassword(secret, legacyHash), isTrue);
      expect(DatabaseService.verifyPassword('WrongPass', legacyHash), isFalse);
    });

    test('Item 3: AppState.defaultSuperAdmin has no hardcoded password or email', () {
      expect(AppState.defaultSuperAdmin.passwordHash, isEmpty);
      expect(AppState.defaultSuperAdmin.email, isEmpty);
    });

    test('Item 17: PhilippineTime uses canonical IANA Asia/Manila timezone', () {
      expect(PhilippineTime.location.name, 'Asia/Manila');
      expect(PhilippineTime.offset, const Duration(hours: 8));

      final sampleUtc = DateTime.utc(2026, 10, 25, 18, 30); // Oct 26 02:30 Manila
      final manila = PhilippineTime.toPhilippine(sampleUtc);
      expect(manila.year, 2026);
      expect(manila.month, 10);
      expect(manila.day, 26);
      expect(manila.hour, 2);

      final bounds = PhilippineTime.utcBoundsForPhilippineDay(value: sampleUtc);
      expect(bounds.startUtc, DateTime.utc(2026, 10, 25, 16, 0));
      expect(bounds.endUtc, DateTime.utc(2026, 10, 26, 16, 0));
    });

    test('Item 18: SQLite foreign_keys PRAGMA is enabled in DatabaseService', () async {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery('PRAGMA foreign_keys');
      expect(rows, isNotEmpty);
      expect(rows.first.values.first, 1);
    });

    test('PhilippineTime day-boundary comparisons align at Manila midnight', () {
      // Oct 26, 2026 02:30 Manila = Oct 25, 2026 18:30 UTC
      final sampleUtc = DateTime.utc(2026, 10, 25, 18, 30);
      final manilaInstant = PhilippineTime.toPhilippine(sampleUtc);
      final dayStart = PhilippineTime.startOfDay(sampleUtc);
      final dayEnd = dayStart.add(const Duration(days: 1));

      expect(manilaInstant.isBefore(dayStart), isFalse);
      expect(manilaInstant.isBefore(dayEnd), isTrue);
    });

    testWidgets('PassengerProfile and DriverHome build without context.select assertion', (tester) async {
      final appState = AppState.instance;
      appState.currentUser = AppUser(
        id: 'user-profile-test-1',
        fullName: 'John Lord Canastra',
        mobile: '09171234567',
        email: 'john@example.com',
        passwordHash: '',
        role: UserRole.passenger,
        status: AccountStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(PrefsService.instance),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
            home: PassengerProfile(onNavigate: (_) {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('John Lord Canastra'), findsOneWidget);

      // Now test DriverHome with a driver user
      appState.currentUser = appState.currentUser!.copyWith(role: UserRole.driver);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(PrefsService.instance),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
            home: DriverHome(onNavigate: (_) {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Completed trip immediately opens RateDriverModal on Passenger UI without overflow on 320x480 screen', (tester) async {
      // Simulate ultra-compact 320x480 low-end device screen
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState.instance;
      appState.currentUser = AppUser(
        id: 'passenger-1',
        fullName: 'John Lord Canastra',
        mobile: '09171234567',
        email: 'john@example.com',
        passwordHash: '',
        role: UserRole.passenger,
        status: AccountStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );
      final completedTrip = Trip(
        id: 'trip-rate-test-1',
        passengerId: 'passenger-1',
        passengerName: 'John Lord Canastra',
        driverId: 'driver-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Poblacion, Badian, Cebu',
        dropoffAddress: 'Kawasan Falls, Matutinao, Badian, Cebu',
        pickup: const Geo(9.8689, 123.3982),
        dropoff: const Geo(9.8034, 123.3741),
        distanceKm: 6.4,
        durationMin: 15,
        fare: 85.0,
        commission: 8.5,
        net: 76.5,
        status: RideStatus.completed,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime(2026, 10, 25, 10, 0),
        completedAt: DateTime(2026, 10, 25, 10, 15),
      );
      appState.pendingRatingTrip = completedTrip;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(PrefsService.instance),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
            home: RideTracking(
              onNavigate: (_) {},
              rideId: completedTrip.id,
            ),
          ),
        ),
      );

      // Let stream resolve and post-frame RateDriverModal open
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(find.text('Ride Completed!'), findsOneWidget);
      // RateDriverModal should automatically pop up immediately
      expect(find.byType(RateDriverModal), findsOneWidget);
      expect(find.text('Submit Rating'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('BookingConfirmationModal and DriverMatchingBottomSheet render with zero overflow on 320x480 screen', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleDriver = NearbyDriver(
        id: 'drv-compact-1',
        name: 'Kuya Roberto Dela Cruz',
        photoUrl: '',
        vehicleType: VehicleType.tricycle,
        plateNumber: 'ABC-1234',
        rating: 4.9,
        ratingCount: 42,
        completedTrips: 128,
        acceptanceRate: 0.98,
        location: const Geo(9.8689, 123.3982),
        distanceKm: 0.8,
        etaMinutes: 3,
        isOnline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BookingConfirmationModal(
                    driver: sampleDriver,
                    pickupAddress: 'Poblacion Public Market, Badian, Cebu',
                    destination: const Place(
                      'Lambug Beach Resort, Badian, Cebu',
                      Geo(9.8034, 123.3741),
                    ),
                    distanceKm: 5.2,
                    durationMins: 14,
                    fare: 120.0,
                    onConfirm: () async => true,
                  ),
                  DriverMatchingBottomSheet(
                    nearbyDrivers: [sampleDriver],
                    selectedDriver: sampleDriver,
                    searchRadiusKm: 5.0,
                    selectedVehicle: VehicleType.tricycle,
                    routeDistanceKm: 5.2,
                    routeDurationMins: 14,
                    tricycleFare: 120.0,
                    habalFare: 95.0,
                    onSelectDriver: (_) {},
                    onSelectVehicle: (_) {},
                    onUpdateRadius: (_) {},
                    onConfirmBooking: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
