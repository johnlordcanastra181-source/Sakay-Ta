import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/auth_service.dart';
import 'package:sakay_ta/services/connectivity_service.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/osm_map_service.dart';
import 'package:sakay_ta/services/prefs_service.dart';
import 'package:sakay_ta/services/sync_service.dart';
import 'package:sakay_ta/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ConnectivityService Tests', () {
    test('Probes fast 204 endpoint and detects online quality', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final service = ConnectivityService(httpClient: mockClient);
      final quality = await service.checkRealConnectivity();

      expect(
          quality == ConnectionQuality.online ||
              quality == ConnectionQuality.intermittent,
          isTrue);
      service.dispose();
    });

    test('Detects offline when health check endpoints fail', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable (no carrier)');
      });

      final service = ConnectivityService(httpClient: mockClient);
      // Run twice to trigger consecutive failure threshold
      await service.checkRealConnectivity();
      final quality = await service.checkRealConnectivity();

      expect(quality, equals(ConnectionQuality.offline));
      expect(service.isOffline, isTrue);
      service.dispose();
    });
  });

  group('DatabaseService Map Cache & Sync Queue Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
    });

    test('Stores and retrieves persistent map cache entries', () async {
      const testKey = 'test_cache_cebu_ayala';
      const testJson =
          '{"name":"Ayala Center Cebu","lat":10.3173,"lng":123.9058}';

      await dbService.saveMapCache(
        testKey,
        'autocomplete',
        testJson,
        ttl: const Duration(hours: 1),
      );

      final cached = await dbService.getMapCache(testKey);
      expect(cached, equals(testJson));
    });

    test('Expires stale map cache entries correctly', () async {
      const staleKey = 'test_cache_stale';
      const testJson = '{"name":"Stale Place"}';

      // Save with negative TTL (already expired)
      await dbService.saveMapCache(
        staleKey,
        'autocomplete',
        testJson,
        ttl: const Duration(seconds: -1),
      );

      final cached = await dbService.getMapCache(staleKey);
      expect(cached, isNull);
    });
  });

  group('SyncService Offline Queue & Batch Synchronization', () {
    late DatabaseService dbService;
    late AuthService authService;
    late TripService tripService;
    late SyncService syncService;

    setUp(() async {
      dbService = DatabaseService.instance;
      authService = AuthService(dbService, PrefsService.instance);
      tripService = TripService(dbService, authService);
      syncService = SyncService(dbService, tripService);
      await syncService.clearQueue();
    });

    tearDown(() async {
      await syncService.clearQueue();
    });

    test('Queues offline ride booking and drains queue on syncAll', () async {
      expect(await syncService.pendingCount(), equals(0));

      await syncService.queueBooking(
        passengerId: 'test-passenger-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Lahug Central, Cebu City',
        dropoffAddress: 'Ayala Center Cebu',
        pickup: const Geo(10.3300, 123.8900),
        dropoff: const Geo(10.3173, 123.9058),
        paymentMethod: PaymentMethod.cash,
      );

      expect(await syncService.pendingCount(), equals(1));
      final items = await syncService.pendingItems();
      expect(items.first['type'], equals('booking'));

      final result = await syncService.syncAll();
      expect(result.synced, equals(1));
      expect(result.remaining, equals(0));
    });

    test('Queues trip status transitions and ratings offline', () async {
      const tripId = 'test_offline_trip_123';

      await syncService.queueTripStatus(
        tripId: tripId,
        status: RideStatus.started,
        latitude: 10.3157,
        longitude: 123.8854,
      );

      await syncService.queueRating(
        tripId: tripId,
        fromUserId: 'test-passenger-1',
        toUserId: 'test-driver-1',
        rating: 5,
        comment: 'Very polite driver, smooth tricycle ride!',
      );

      await syncService.queuePayment(
        paymentId: 'pay_123',
        tripId: tripId,
        payerId: 'test-passenger-1',
        payeeId: 'test-driver-1',
        amount: 25.0,
        method: PaymentMethod.cash,
        reference: 'ST-CASH-123',
      );

      expect(await syncService.pendingCount(), equals(3));

      final items = await syncService.pendingItems();
      final types = items.map((i) => i['type']).toList();
      expect(types, containsAll(['trip_status', 'rating', 'payment']));

      await syncService.clearQueue();
      expect(await syncService.pendingCount(), equals(0));
    });
  });

  group('OsmMapService Offline Geodesic & Places Fallback Tests', () {
    test('Calculates geodesic route with road curvature offline', () async {
      const origin = Geo(10.3157, 123.8854); // Cebu City
      const destination = Geo(10.3173, 123.9058); // Ayala Center Cebu

      final route = await OsmMapService.instance.computeRoute(
        origin: origin,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(route!.distanceKm, greaterThan(0));
      expect(route.durationMins, greaterThan(0));
      expect(route.polylinePoints.length, greaterThanOrEqualTo(2));
      expect(route.polylinePoints.first.lat, equals(origin.lat));
      expect(route.polylinePoints.last.lat, equals(destination.lat));
    });

    test(
        'Provides fallback Philippine landmarks when autocomplete query runs offline',
        () async {
      final results = await OsmMapService.instance.autocomplete('Ayala');
      expect(results.isNotEmpty, isTrue);
      expect(
          results.any((p) => p.name.toLowerCase().contains('ayala')), isTrue);
    });

    test('Provides clean fallback reverse geocoding address offline', () async {
      const cebuCityCenter = Geo(10.3157, 123.8854);
      final address =
          await OsmMapService.instance.reverseGeocode(cebuCityCenter);
      expect(address, isNotNull);
      expect(address!.isNotEmpty, isTrue);
    });
  });
}
