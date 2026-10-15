import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/user_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserAvatar & Image Provider Tests', () {
    test('Empty and null photo URLs return null image provider', () {
      expect(getUserAvatarImageProvider(null), isNull);
      expect(getUserAvatarImageProvider(''), isNull);
      expect(getUserAvatarImageProvider('   '), isNull);
    });

    test('Base64 data URI returns MemoryImage with valid bytes', () {
      final sampleBytes = utf8.encode('test_image_payload');
      final base64String = base64Encode(sampleBytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      final provider = getUserAvatarImageProvider(dataUri);
      expect(provider, isNotNull);
      expect(provider is MemoryImage, isTrue);
      final memoryImage = provider as MemoryImage;
      expect(utf8.decode(memoryImage.bytes), equals('test_image_payload'));
    });

    test('Network URL returns NetworkImage provider', () {
      const httpUrl = 'http://example.com/avatar.png';
      const httpsUrl = 'https://firebasestorage.googleapis.com/avatar.jpg';

      final httpProvider = getUserAvatarImageProvider(httpUrl);
      expect(httpProvider is NetworkImage, isTrue);

      final httpsProvider = getUserAvatarImageProvider(httpsUrl);
      expect(httpsProvider is NetworkImage, isTrue);
    });

    testWidgets('UserAvatar renders initials when photo is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              name: 'Maria Clara',
              radius: 20,
            ),
          ),
        ),
      );

      expect(find.text('MC'), findsOneWidget);
    });
  });

  group('Settings & Driver Preferences Persistence Tests', () {
    test('PrefsService stores and retrieves driver and notification settings',
        () async {
      final prefs = PrefsService.instance;

      expect(await prefs.darkMode, isFalse);
      expect(await prefs.notificationsEnabled, isTrue);
      expect(await prefs.soundAlertsEnabled, isTrue);
      expect(await prefs.autoAcceptRides, isFalse);
      expect(await prefs.pickupRadiusKm, equals(5.0));

      await prefs.setDarkMode(true);
      await prefs.setNotificationsEnabled(false);
      await prefs.setSoundAlertsEnabled(false);
      await prefs.setAutoAcceptRides(true);
      await prefs.setPickupRadiusKm(8.5);

      expect(await prefs.darkMode, isTrue);
      expect(await prefs.notificationsEnabled, isFalse);
      expect(await prefs.soundAlertsEnabled, isFalse);
      expect(await prefs.autoAcceptRides, isTrue);
      expect(await prefs.pickupRadiusKm, equals(8.5));
    });

    test('AppState updates driver preferences and notifies listeners',
        () async {
      final appState = AppState();
      var notificationCount = 0;
      appState.addListener(() {
        notificationCount++;
      });

      await appState.updateDriverPreferences(
        notifications: false,
        soundAlerts: false,
        autoAccept: true,
        radius: 12.0,
      );

      expect(appState.notificationsEnabled, isFalse);
      expect(appState.soundAlertsEnabled, isFalse);
      expect(appState.autoAcceptRides, isTrue);
      expect(appState.pickupRadiusKm, equals(12.0));
      expect(notificationCount, greaterThan(0));
    });

    test('AppState password change enforces validation requirements', () async {
      final appState = AppState();
      // Test password too short
      final shortRes = await appState.changeUserPassword('123');
      expect(shortRes.success, isFalse);
      expect(shortRes.errorMessage, contains('at least 6 characters'));

      // Test password empty
      final emptyRes = await appState.changeUserPassword('   ');
      expect(emptyRes.success, isFalse);
      expect(emptyRes.errorMessage, contains('at least 6 characters'));
    });
  });
}
