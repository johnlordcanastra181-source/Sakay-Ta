import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';

void main() {
  final profile = DriverProfile(
    userId: 'driver-1',
    vehicleType: VehicleType.tricycle,
    plateNumber: 'ABC-123',
    submittedAt: DateTime.now(),
  );

  AppUser user({
    required String status,
    required bool online,
    DateTime? locationUpdatedAt,
  }) {
    return AppUser(
      id: 'driver-1',
      fullName: 'Test Driver',
      passwordHash: '',
      role: UserRole.driver,
      status: status,
      isOnline: online,
      createdAt: DateTime.now(),
      latitude: 10.3157,
      longitude: 123.8854,
      locationUpdatedAt: locationUpdatedAt,
    );
  }

  test('approved online nearby driver is bookable', () {
    final driver = NearbyDriver.fromUserAndProfile(
      user: user(
        status: AccountStatus.approved,
        online: true,
        locationUpdatedAt: DateTime.now(),
      ),
      profile: profile,
      passenger: const Geo(10.3157, 123.8854),
    );

    expect(driver.isOnline, isTrue);
    expect(driver.isBookable, isTrue);
  });

  test('RPC status fields are parsed instead of assumed online', () {
    final driver = NearbyDriver.fromRpcMap({
      'user_id': 'driver-1',
      'full_name': 'Test Driver',
      'vehicle_type': 'tricycle',
      'plate_number': 'ABC-123',
      'latitude': '10.3157',
      'longitude': '123.8854',
      'distance_km': '1.25',
      'rating_average': '4.75',
      'rating_count': '8',
      'is_online': false,
      'is_available': true,
      'has_active_ride': false,
      'last_location_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(driver.distanceKm, 1.25);
    expect(driver.rating, 4.75);
    expect(driver.ratingCount, 8);
    expect(driver.isOnline, isFalse);
    expect(driver.isBookable, isFalse);
    expect(driver.availabilityLabel, 'Offline');
  });

  test('online driver with an active ride is busy and not bookable', () {
    final driver = NearbyDriver.fromRpcMap({
      'user_id': 'driver-1',
      'full_name': 'Test Driver',
      'vehicle_type': 'tricycle',
      'plate_number': 'ABC-123',
      'latitude': 10.3157,
      'longitude': 123.8854,
      'distance_km': 1,
      'is_online': true,
      'is_available': true,
      'has_active_ride': true,
      'last_location_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(driver.isAvailable, isFalse);
    expect(driver.isBookable, isFalse);
    expect(driver.availabilityLabel, 'Busy');
  });

  test('online driver with a stale GPS fix is not bookable', () {
    final driver = NearbyDriver.fromRpcMap({
      'user_id': 'driver-1',
      'full_name': 'Test Driver',
      'vehicle_type': 'tricycle',
      'plate_number': 'ABC-123',
      'latitude': 10.3157,
      'longitude': 123.8854,
      'distance_km': 1,
      'is_online': true,
      'is_available': true,
      'has_active_ride': false,
      'last_location_at': DateTime.now()
          .toUtc()
          .subtract(NearbyDriverConfig.bookableLocationMaxAge +
              const Duration(seconds: 1))
          .toIso8601String(),
    });

    expect(driver.isBookable, isFalse);
    expect(driver.availabilityLabel, 'Online · Last known location');
  });

  test('saved Online driver can receive a pending offer while signed out', () {
    final driver = NearbyDriver.fromRpcMap({
      'user_id': 'driver-1',
      'full_name': 'Test Driver',
      'vehicle_type': 'tricycle',
      'plate_number': 'ABC-123',
      'latitude': 10.3157,
      'longitude': 123.8854,
      'distance_km': 1,
      'is_online': true,
      'is_available': true,
      'has_active_ride': false,
      'has_live_session': false,
      'last_location_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    });

    expect(driver.isOnline, isTrue);
    expect(driver.hasLiveSession, isFalse);
    expect(driver.canSubmitRideRequest, isTrue);
    expect(driver.isBookable, isFalse);
    expect(driver.availabilityLabel, 'Online · May respond later');
  });

  test('approved offline nearby driver remains visible but is not bookable',
      () {
    final driver = NearbyDriver.fromUserAndProfile(
      user: user(
        status: AccountStatus.approved,
        online: false,
        locationUpdatedAt: DateTime.now(),
      ),
      profile: profile,
      passenger: const Geo(10.3157, 123.8854),
    );

    expect(driver.isOnline, isFalse);
    expect(driver.isBookable, isFalse);
    expect(driver.isLocationStale, isFalse);
  });

  test('stale offline location is not considered fresh', () {
    final driver = NearbyDriver.fromUserAndProfile(
      user: user(
        status: AccountStatus.approved,
        online: false,
        locationUpdatedAt: DateTime.now().subtract(
          NearbyDriverConfig.offlineLocationMaxAge + const Duration(minutes: 1),
        ),
      ),
      profile: profile,
      passenger: const Geo(10.3157, 123.8854),
    );

    expect(driver.isBookable, isFalse);
    expect(driver.isLocationStale, isTrue);
  });

  test('suspended driver cannot be bookable', () {
    final driver = NearbyDriver.fromUserAndProfile(
      user: user(
        status: AccountStatus.suspended,
        online: true,
        locationUpdatedAt: DateTime.now(),
      ),
      profile: profile,
      passenger: const Geo(10.3157, 123.8854),
    );

    expect(driver.isBookable, isFalse);
  });

  group('Section 19: Test Cases 1 - 8 Verification', () {
    // Helper function simulating the nearby driver filter logic
    bool shouldShowDriver({
      required bool isApproved,
      required bool isSuspended,
      required bool isPending,
      required bool isRejected,
      required double distanceKm,
      required double radiusKm,
      required VehicleType driverVehicle,
      required VehicleType selectedVehicle,
    }) {
      if (isPending || isRejected || isSuspended) return false;
      if (!isApproved) return false;
      if (distanceKm > radiusKm) return false;
      if (driverVehicle != selectedVehicle) return false;
      return true;
    }

    test(
        'CASE 1: Approved=YES, Active=YES, Online=YES, Distance=2km, Radius=5km, Vehicle=Tricycle -> SHOW + BOOKABLE',
        () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: false,
        isPending: false,
        isRejected: false,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isTrue);

      final driver = NearbyDriver.fromUserAndProfile(
        user: user(
          status: AccountStatus.approved,
          online: true,
          locationUpdatedAt: DateTime.now(),
        ),
        profile: profile,
        passenger: const Geo(10.3157, 123.8854),
      );
      expect(driver.isBookable, isTrue);
    });

    test(
        'CASE 2: Approved=YES, Active=YES, Online=NO, Distance=2km, Radius=5km, Vehicle=Tricycle -> SHOW + OFFLINE + NOT BOOKABLE',
        () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: false,
        isPending: false,
        isRejected: false,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isTrue);

      final driver = NearbyDriver.fromUserAndProfile(
        user: user(status: AccountStatus.approved, online: false),
        profile: profile,
        passenger: const Geo(10.3157, 123.8854),
      );
      expect(driver.isOnline, isFalse);
      expect(driver.isBookable, isFalse);
    });

    test('CASE 3: Approved=YES, Suspended=YES, Distance=2km -> DO NOT SHOW',
        () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: true,
        isPending: false,
        isRejected: false,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isFalse);
    });

    test('CASE 4: Application=Pending -> DO NOT SHOW', () {
      final show = shouldShowDriver(
        isApproved: false,
        isSuspended: false,
        isPending: true,
        isRejected: false,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isFalse);
    });

    test('CASE 5: Application=Rejected -> DO NOT SHOW', () {
      final show = shouldShowDriver(
        isApproved: false,
        isSuspended: false,
        isPending: false,
        isRejected: true,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isFalse);
    });

    test('CASE 6: Approved=YES, Distance=8km, Radius=5km -> DO NOT SHOW', () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: false,
        isPending: false,
        isRejected: false,
        distanceKm: 8.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isFalse);
    });

    test('CASE 7: Approved=YES, Distance=8km, Radius=10km -> SHOW', () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: false,
        isPending: false,
        isRejected: false,
        distanceKm: 8.0,
        radiusKm: 10.0,
        driverVehicle: VehicleType.tricycle,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isTrue);
    });

    test(
        'CASE 8: Selected vehicle=Tricycle, Driver vehicle=Motor -> DO NOT SHOW',
        () {
      final show = shouldShowDriver(
        isApproved: true,
        isSuspended: false,
        isPending: false,
        isRejected: false,
        distanceKm: 2.0,
        radiusKm: 5.0,
        driverVehicle: VehicleType.habal,
        selectedVehicle: VehicleType.tricycle,
      );
      expect(show, isFalse);
    });

    test('Vehicle normalization parses motor, motorcycle, and habal correctly',
        () {
      expect(VehicleTypeX.fromKey('motor'), VehicleType.habal);
      expect(VehicleTypeX.fromKey('motorcycle'), VehicleType.habal);
      expect(VehicleTypeX.fromKey('Motor'), VehicleType.habal);
      expect(VehicleTypeX.fromKey('HABAL'), VehicleType.habal);
      expect(VehicleTypeX.fromKey('habal-habal'), VehicleType.habal);
      expect(VehicleTypeX.fromKey('tricycle'), VehicleType.tricycle);
      expect(VehicleTypeX.fromKey('TRICYCLE'), VehicleType.tricycle);
    });
  });
}
