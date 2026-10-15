import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/main.dart' hide Brand, Avatar;
import 'package:sakay_ta/models/saved_place.dart';
import 'package:sakay_ta/pages/my_rides.dart';
import 'package:sakay_ta/pages/passenger_profile.dart';
import 'package:sakay_ta/services/payment_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/services/saved_places_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/passenger_bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PaymentService Tests', () {
    test('Initializes with GCash, Maya, and Cash defaults', () async {
      final service = PaymentService.instance;
      await service.init('test_user_123');

      expect(service.methods.isNotEmpty, isTrue);
      expect(service.methods.any((m) => m.type == PaymentMethod.gcash), isTrue);
      expect(service.methods.any((m) => m.type == PaymentMethod.maya), isTrue);
      expect(service.methods.any((m) => m.type == PaymentMethod.cash), isTrue);
      expect(service.defaultPaymentSummary, contains('GCash'));
    });

    test('Can switch default payment method', () async {
      final service = PaymentService.instance;
      await service.init('test_user_123');

      final mayaMethod = service.methods.firstWhere((m) => m.type == PaymentMethod.maya);
      await service.setDefault('test_user_123', mayaMethod.id);

      expect(service.defaultMethod.type, equals(PaymentMethod.maya));
    });

    test('Can link new GCash account with OTP validation', () async {
      final service = PaymentService.instance;
      await service.init('test_user_123');

      final req = await service.requestGcashLinking(
        mobileNumber: '09179876543',
        accountName: 'Maria Santos',
      );
      expect(req.success, isTrue);
      expect(req.otpCode.isNotEmpty, isTrue);

      final linked = await service.confirmGcashLinking(
        userId: 'test_user_123',
        mobileNumber: '09179876543',
        accountName: 'Maria Santos',
        enteredOtp: req.otpCode,
        expectedOtp: req.otpCode,
      );

      expect(linked, isNotNull);
      expect(linked!.accountName, equals('Maria Santos'));
      expect(service.methods.any((m) => m.accountName == 'Maria Santos'), isTrue);
    });

    test('Can execute digital payment transaction session', () async {
      final service = PaymentService.instance;
      await service.init('test_user_123');

      final session = await service.executePaymentSession(
        userId: 'test_user_123',
        tripId: 'trip_999',
        amount: 45.0,
        paymentMethodType: PaymentMethod.gcash,
      );

      expect(session.isSuccess, isTrue);
      expect(session.referenceNumber, startsWith('ST-GCASH-'));
      expect(session.amount, equals(45.0));
    });
  });

  group('SavedPlacesService Tests', () {
    test('Initializes with default Home and Work places', () async {
      final service = SavedPlacesService.instance;
      await service.init('test_user_123');

      expect(service.places.length, greaterThanOrEqualTo(2));
      expect(service.places.any((p) => p.name == 'Home'), isTrue);
      expect(service.places.any((p) => p.name == 'Work'), isTrue);
      expect(service.summary, contains('Home'));
    });

    test('Can add, update and delete a saved place', () async {
      final service = SavedPlacesService.instance;
      await service.init('test_user_123');

      final newPlace = SavedPlace(
        id: 'place_school_1',
        userId: 'test_user_123',
        name: 'University Campus',
        address: 'Downtown, Cebu City',
        geo: const Geo(10.3000, 123.8900),
        category: 'school',
        createdAt: DateTime.now(),
      );

      await service.addPlace('test_user_123', newPlace);
      expect(service.places.any((p) => p.id == 'place_school_1'), isTrue);

      final updatedPlace = newPlace.copyWith(name: 'Main Campus');
      await service.updatePlace('test_user_123', updatedPlace);
      expect(service.places.firstWhere((p) => p.id == 'place_school_1').name, equals('Main Campus'));

      await service.deletePlace('test_user_123', 'place_school_1');
      expect(service.places.any((p) => p.id == 'place_school_1'), isFalse);
    });
  });

  group('UI & Widget Rendering Tests', () {
    testWidgets('PassengerBottomNav renders 4 items with active tab highlighted',
        (tester) async {
      AppScreen? navigatedScreen;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
          ],
          supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
          home: Scaffold(
            bottomNavigationBar: PassengerBottomNav(
              currentIndex: 1,
              onNavigate: (s) => navigatedScreen = s,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      expect(navigatedScreen, equals(AppScreen.profile));
    });

    testWidgets('MyRides page renders Header, Tabs, and Upcoming Empty State with Book Now button',
        (tester) async {
      AppScreen? navigatedScreen;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: AppState.instance),
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(PrefsService.instance),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              FallbackCupertinoLocalizationsDelegate(),
            ],
            supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
            home: MyRides(onNavigate: (s) => navigatedScreen = s),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('No upcoming rides'), findsOneWidget);
      expect(find.text('Book Now'), findsOneWidget);

      await tester.tap(find.text('Book Now'));
      expect(navigatedScreen, equals(AppScreen.passengerHome));
    });

    testWidgets('PassengerProfile renders profile, Trusted Passenger badge, Stats, Settings, and Log Out',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: AppState.instance),
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(PrefsService.instance),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              FallbackCupertinoLocalizationsDelegate(),
            ],
            supportedLocales: const [Locale('en'), Locale('ceb'), Locale('tl')],
            home: PassengerProfile(onNavigate: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Trusted Passenger'), findsOneWidget);
      expect(find.text('Total Rides'), findsOneWidget);
      expect(find.text('Joined Since'), findsOneWidget);
      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('Saved Places'), findsOneWidget);
      expect(find.text('Preferences & Support'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}
