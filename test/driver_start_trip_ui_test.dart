import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/main.dart' as app_main;
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/widgets/user_avatar.dart';

void main() {
  group('ride-flow avatar safety', () {
    testWidgets('uses a valid embedded profile photo', (tester) async {
      const onePixelPng =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(photoUrl: onePixelPng, name: 'Maria Santos'),
          ),
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isA<MemoryImage>());
      expect(avatar.onForegroundImageError, isNotNull);
    });

    for (final value in <String?>[null, '', '   ', 'avatars/user/photo.jpg']) {
      testWidgets('falls back for ${value ?? 'null'}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(photoUrl: value, name: 'Maria Santos'),
            ),
          ),
        );

        expect(find.text('MS'), findsOneWidget);
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(avatar.foregroundImage, isNull);
        expect(avatar.onForegroundImageError, isNull);
      });
    }

    testWidgets('a network photo keeps initials behind its error fallback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              photoUrl: 'https://example.invalid/passenger.jpg',
              name: 'Maria Santos',
            ),
          ),
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isA<NetworkImage>());
      expect(avatar.onForegroundImageError, isNotNull);
      expect(find.text('MS'), findsOneWidget);

      // Flutter's test HTTP client rejects the URL. The configured image-error
      // callback consumes that failure while the initials remain visible.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('MS'), findsOneWidget);
    });
  });

  test('driver routes cannot enter passenger tracking or ride history', () {
    final driver = AppUser(
      id: 'driver-1',
      fullName: 'Driver One',
      passwordHash: '',
      role: UserRole.driver,
      createdAt: DateTime(2026),
    );
    final passenger = AppUser(
      id: 'passenger-1',
      fullName: 'Passenger One',
      passwordHash: '',
      role: UserRole.passenger,
      createdAt: DateTime(2026),
    );

    for (final passengerScreen in const [
      app_main.AppScreen.passengerHome,
      app_main.AppScreen.rides,
      app_main.AppScreen.tracking,
    ]) {
      expect(
        app_main.guardAppScreen(passengerScreen, driver),
        app_main.AppScreen.driverHome,
      );
      expect(
        app_main.guardAppScreen(passengerScreen, passenger),
        passengerScreen,
      );
    }
  });

  test('driver Start Trip stays on DriverHome and is single-flight', () {
    final driverHome = File('lib/pages/driver_home.dart').readAsStringSync();
    final state = File('lib/state/app_state.dart').readAsStringSync();
    final router = File('lib/main.dart').readAsStringSync();
    final tracking = File('lib/pages/ride_tracking.dart').readAsStringSync();

    expect(driverHome, contains("'Arrived at Pickup'"));
    expect(driverHome, contains("'Start Trip'"));
    expect(
        driverHome, isNot(contains('widget.onNavigate(AppScreen.tracking)')));
    expect(state, contains('if (_startingActiveTrip) return false;'));
    expect(state, contains('trip.status != RideStatus.arrived'));
    expect(state, contains('toStatus: RideStatus.started'));
    expect(state, contains('setStatusLocally(trip.id, RideStatus.started)'));
    expect(
        state, isNot(contains('trips.setStatus(trip.id, RideStatus.started)')));
    expect(router, contains('guardAppScreen(requested, user)'));
    expect(tracking, contains('UserAvatar('));
    expect(tracking, isNot(contains('onBackgroundImageError:')));
  });
}
