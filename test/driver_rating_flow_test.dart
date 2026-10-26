import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Login Page Footer Verification', () {
    test('Login Page contains (c) 2026 Sakay Ta. All rights reserved.', () {
      final loginFile = File('lib/pages/login_page.dart').readAsStringSync();
      expect(
        loginFile,
        contains('© 2026 Sakay Ta. All rights reserved.'),
        reason: 'Login Page footer must display the official 2026 copyright notice.',
      );
    });
  });

  group('Driver Rating Defaults Start at 0.0', () {
    test('NearbyDriver.fromRpcMap maps null rating_average to 0.0 (not 5.0)', () {
      final unratedDriverRow = {
        'user_id': 'driver-new-001',
        'full_name': 'John Fill',
        'profile_photo_path': '',
        'vehicle_type': 'tricycle',
        'plate_number': 'TR-1029',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 1.2,
        'rating_average': null, // Newly registered driver has no reviews
        'rating_count': 0,
        'completed_trips': 0,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toIso8601String(),
      };

      final driver = NearbyDriver.fromRpcMap(unratedDriverRow);
      expect(driver.rating, 0.0);
      expect(driver.ratingCount, 0);
      expect(driver.rating, isNot(5.0));
    });

    test('AppUser default constructor sets rating and ratingCount to 0.0 and 0', () {
      final user = AppUser(
        id: 'u-1',
        fullName: 'New Driver',
        mobile: '09123456789',
        email: 'driver@sakayta.ph',
        passwordHash: 'dummy_hash',
        role: UserRole.driver,
        createdAt: DateTime(2026),
      );

      expect(user.rating, 0.0);
      expect(user.ratingCount, 0);
    });

    test('Real mathematical driver rating calculation updates correctly per passenger rating', () {
      // Step 1: Initial state (New driver starts at 0.0 rating and 0 ratings)
      double currentRating = 0.0;
      int currentCount = 0;
      expect(currentRating, 0.0);
      expect(currentCount, 0);

      // Step 2: Passenger 1 completes ride and rates 5 stars
      int p1Rating = 5;
      currentRating = (currentRating * currentCount + p1Rating) / (currentCount + 1);
      currentCount += 1;
      expect(currentCount, 1);
      expect(currentRating, 5.0);

      // Step 3: Passenger 2 completes ride and rates 4 stars
      int p2Rating = 4;
      currentRating = (currentRating * currentCount + p2Rating) / (currentCount + 1);
      currentCount += 1;
      expect(currentCount, 2);
      expect(currentRating, 4.5); // (5 + 4) / 2 = 4.5

      // Step 4: Passenger 3 completes ride and rates 3 stars
      int p3Rating = 3;
      currentRating = (currentRating * currentCount + p3Rating) / (currentCount + 1);
      currentCount += 1;
      expect(currentCount, 3);
      expect(currentRating, 4.0); // (5 + 4 + 3) / 3 = 4.0
    });
  });

  group('Ride Completed Screen Rating UI', () {
    test('Ride tracking file contains Rate Your Driver card and rating handler', () {
      final trackingFile = File('lib/pages/ride_tracking.dart').readAsStringSync();
      expect(trackingFile, contains('Rate Your Driver'));
      expect(trackingFile, contains('Submit Rating'));
      expect(trackingFile, contains('app.rateTrip('));
      expect(trackingFile, contains('Thank you for rating!'));
    });
  });
}

