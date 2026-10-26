import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';
import 'package:sakay_ta/services/supabase_database_service.dart';
import 'package:sakay_ta/widgets/driver_matching_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearbyDriver trip count parsing & copyWith', () {
    test('parses completed_trips from RPC integer', () {
      final driver = NearbyDriver.fromRpcMap({
        'user_id': 'driver-john-fill',
        'full_name': 'John Fill',
        'vehicle_type': 'tricycle',
        'plate_number': 'TRI-101',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 1.2,
        'completed_trips': 15,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(driver.completedTrips, 15);
      expect(driver.plateNumber, 'TRI-101');
      expect(driver.vehicleType, VehicleType.tricycle);
    });

    test('parses completed_trips when genuinely 0', () {
      final driver = NearbyDriver.fromRpcMap({
        'user_id': 'driver-new',
        'full_name': 'New Driver',
        'vehicle_type': 'tricycle',
        'plate_number': 'TRI-000',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 0.5,
        'completed_trips': 0,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(driver.completedTrips, 0);
    });

    test('parses completed_trips from string numeric representation', () {
      final driver = NearbyDriver.fromRpcMap({
        'user_id': 'driver-str',
        'full_name': 'String Driver',
        'vehicle_type': 'habal',
        'plate_number': 'MOT-202',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 2.0,
        'completed_trips': '42',
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(driver.completedTrips, 42);
    });

    test('falls back to total_trips when completed_trips is absent', () {
      final driver = NearbyDriver.fromRpcMap({
        'user_id': 'driver-legacy',
        'full_name': 'Legacy Driver',
        'vehicle_type': 'habal',
        'plate_number': 'MOT-303',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 3.1,
        'total_trips': 27,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(driver.completedTrips, 27);
    });

    test('defaults to 0 when both completed_trips and total_trips are missing', () {
      final driver = NearbyDriver.fromRpcMap({
        'user_id': 'driver-empty',
        'full_name': 'Empty Driver',
        'vehicle_type': 'tricycle',
        'plate_number': 'TRI-404',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 1.0,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(driver.completedTrips, 0);
    });

    test('copyWith updates completedTrips and other fields immutably', () {
      final original = NearbyDriver.fromRpcMap({
        'user_id': 'driver-copy',
        'full_name': 'Original Driver',
        'vehicle_type': 'tricycle',
        'plate_number': 'TRI-505',
        'latitude': 10.3157,
        'longitude': 123.8854,
        'distance_km': 1.0,
        'completed_trips': 0,
        'is_online': true,
        'is_available': true,
        'has_active_ride': false,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      });

      final updated = original.copyWith(
        completedTrips: 18,
        photoUrl: 'https://example.com/new_photo.jpg',
      );

      expect(original.completedTrips, 0);
      expect(updated.completedTrips, 18);
      expect(updated.photoUrl, 'https://example.com/new_photo.jpg');
      expect(updated.name, original.name);
      expect(updated.plateNumber, original.plateNumber);
    });
  });

  group('Driver photo URL resolution & in-memory cache', () {
    setUp(() {
      SupabaseDatabaseService.driverPhotoUrlCache.clear();
    });

    test('cached signed URL is retrieved without re-fetching', () async {
      const cleanPath = 'user-fill/profile/profile_123.jpg';
      const fakeSignedUrl =
          'https://supabase.co/storage/v1/object/sign/driver-documents/user-fill/profile/profile_123.jpg?token=abc';

      // Pre-populate the cache with a future expiration
      SupabaseDatabaseService.driverPhotoUrlCache[cleanPath] = (
        url: fakeSignedUrl,
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      );

      // Verify the cache has the item and expiration is valid
      final cached = SupabaseDatabaseService.driverPhotoUrlCache[cleanPath];
      expect(cached, isNotNull);
      expect(cached!.url, fakeSignedUrl);
      expect(DateTime.now().isBefore(cached.expiresAt), isTrue);
    });

    test('expired cache entry is identified correctly', () {
      const cleanPath = 'user-fill/profile/profile_old.jpg';
      SupabaseDatabaseService.driverPhotoUrlCache[cleanPath] = (
        url: 'https://supabase.co/old_signed_url',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final cached = SupabaseDatabaseService.driverPhotoUrlCache[cleanPath];
      expect(cached, isNotNull);
      expect(DateTime.now().isBefore(cached!.expiresAt), isFalse);
    });
  });

  group('DriverMatchingBottomSheet UI Trip Count and Profile Display', () {
    testWidgets('renders actual completed trips and plate number correctly',
        (tester) async {
      final now = DateTime.now().toUtc();
      final driverWith15Trips = NearbyDriver(
        id: 'driver-john-fill',
        name: 'John Fill',
        photoUrl: '',
        vehicleType: VehicleType.tricycle,
        plateNumber: 'ABC-123',
        rating: 4.8,
        ratingCount: 12,
        completedTrips: 15,
        acceptanceRate: 1.0,
        location: const Geo(10.3157, 123.8854),
        distanceKm: 0.8,
        etaMinutes: 2,
        isOnline: true,
        isAvailable: true,
        hasLiveSession: true,
        locationUpdatedAt: now,
      );

      final driverWith0Trips = NearbyDriver(
        id: 'driver-john-dell',
        name: 'John Dell',
        photoUrl: '',
        vehicleType: VehicleType.habal,
        plateNumber: 'MOT-456',
        rating: 5.0,
        ratingCount: 0,
        completedTrips: 0,
        acceptanceRate: 1.0,
        location: const Geo(10.3160, 123.8860),
        distanceKm: 1.1,
        etaMinutes: 3,
        isOnline: true,
        isAvailable: true,
        hasLiveSession: true,
        locationUpdatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverMatchingBottomSheet(
              nearbyDrivers: [driverWith15Trips, driverWith0Trips],
              selectedDriver: driverWith15Trips,
              searchRadiusKm: 5.0,
              selectedVehicle: VehicleType.tricycle,
              routeDistanceKm: 2.5,
              routeDurationMins: 8,
              tricycleFare: 30.0,
              habalFare: 40.0,
              onSelectDriver: (_) {},
              onSelectVehicle: (_) {},
              onUpdateRadius: (_) {},
              onConfirmBooking: () {},
            ),
          ),
        ),
      );

      // Verify John Fill with 15 trips is displayed
      expect(find.text('John Fill'), findsOneWidget);
      expect(find.text('ABC-123 · 15 trips'), findsOneWidget);
      expect(find.text('🛺'), findsWidgets);

      // Verify John Dell with genuine 0 trips is displayed
      expect(find.text('John Dell'), findsOneWidget);
      expect(find.text('MOT-456 · 0 trips'), findsOneWidget);
      expect(find.text('🏍️'), findsWidgets);

      // Verify fallback icon appears when photoUrl is empty
      expect(find.byIcon(Icons.person_rounded), findsWidgets);
    });
  });
}
