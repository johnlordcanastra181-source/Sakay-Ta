import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/booking_confirmation_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip & Booking Model Multi-Passenger Serialization', () {
    test('Trip defaults passengerCount to 1 when omitted', () {
      final trip = Trip(
        id: 'trip-1',
        passengerId: 'p-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Pickup Point',
        dropoffAddress: 'Dropoff Point',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 2.5,
        durationMin: 10,
        fare: 25.0,
        commission: 0,
        net: 25.0,
        createdAt: DateTime.now(),
      );

      expect(trip.passengerCount, equals(1));

      final map = trip.toMap();
      expect(map['passenger_count'], equals(1));

      final fromMapTrip = Trip.fromMap(map);
      expect(fromMapTrip.passengerCount, equals(1));
    });

    test('Trip preserves explicit passengerCount in toMap and fromMap', () {
      final trip = Trip(
        id: 'trip-2',
        passengerId: 'p-2',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Pickup 2',
        dropoffAddress: 'Dropoff 2',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 3.0,
        durationMin: 12,
        fare: 35.0,
        commission: 0,
        net: 35.0,
        createdAt: DateTime.now(),
        passengerCount: 3,
      );

      expect(trip.passengerCount, equals(3));
      final map = trip.toMap();
      expect(map['passenger_count'], equals(3));

      final restored = Trip.fromMap(map);
      expect(restored.passengerCount, equals(3));
    });

    test('Trip copyWith updates passengerCount correctly', () {
      final original = Trip(
        id: 'trip-3',
        passengerId: 'p-3',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Pickup 3',
        dropoffAddress: 'Dropoff 3',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 1.5,
        durationMin: 6,
        fare: 15.0,
        commission: 0,
        net: 15.0,
        createdAt: DateTime.now(),
        passengerCount: 1,
      );

      final updated = original.copyWith(passengerCount: 4);
      expect(updated.passengerCount, equals(4));
      expect(updated.id, equals('trip-3'));
    });

    test('Booking model serializes passengerCount correctly', () {
      final booking = Booking(
        id: 'book-1',
        passengerId: 'p-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Origin',
        dropoffAddress: 'Dest',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        passengerCount: 2,
        createdAt: DateTime.now(),
      );

      expect(booking.passengerCount, equals(2));
      final map = booking.toMap();
      expect(map['passenger_count'], equals(2));

      final fromMapBooking = Booking.fromMap(map);
      expect(fromMapBooking.passengerCount, equals(2));
    });
  });

  group('AppState Multi-Passenger Capacity Logic', () {
    late AppState app;

    setUp(() {
      app = AppState();
    });

    test('Tricycle driver has maxCapacity = 4', () {
      app.driverProfile = DriverProfile(
        userId: 'user-driver-1',
        vehicleType: VehicleType.tricycle,
        licenseNumber: 'LIC-1234',
        plateNumber: '7788TG',
        todaId: 'toda-1',
        submittedAt: DateTime.now(),
      );

      expect(app.maxCapacity, equals(4));
      expect(app.availableSeats, equals(4));
      expect(app.hasCapacityForMore, isTrue);
      expect(app.activePassengersCount, equals(0));
    });

    test('Habal-Habal driver has maxCapacity = 1', () {
      app.driverProfile = DriverProfile(
        userId: 'user-driver-2',
        vehicleType: VehicleType.habal,
        licenseNumber: 'LIC-5678',
        plateNumber: '1234MC',
        todaId: 'toda-1',
        submittedAt: DateTime.now(),
      );

      expect(app.maxCapacity, equals(1));
      expect(app.availableSeats, equals(1));
      expect(app.hasCapacityForMore, isTrue);
      expect(app.activePassengersCount, equals(0));
    });

    test('Multi-rider occupancy and seat calculation for Tricycle up to 4 pax', () {
      app.driverProfile = DriverProfile(
        userId: 'user-driver-1',
        vehicleType: VehicleType.tricycle,
        licenseNumber: 'LIC-1234',
        plateNumber: '7788TG',
        todaId: 'toda-1',
        submittedAt: DateTime.now(),
      );

      final trip1 = Trip(
        id: 't-1',
        passengerId: 'p-1',
        driverId: 'user-driver-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'A',
        dropoffAddress: 'B',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 2.0,
        durationMin: 8,
        fare: 20.0,
        commission: 0,
        net: 20.0,
        createdAt: DateTime.now(),
        status: RideStatus.accepted,
        passengerCount: 1,
      );

      app.activeTrips = [trip1];
      expect(app.activePassengersCount, equals(1));
      expect(app.availableSeats, equals(3));
      expect(app.hasCapacityForMore, isTrue);

      final trip2 = Trip(
        id: 't-2',
        passengerId: 'p-2',
        driverId: 'user-driver-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'C',
        dropoffAddress: 'D',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 3.0,
        durationMin: 10,
        fare: 30.0,
        commission: 0,
        net: 30.0,
        createdAt: DateTime.now(),
        status: RideStatus.started,
        passengerCount: 2,
      );

      app.activeTrips = [trip1, trip2];
      expect(app.activePassengersCount, equals(3));
      expect(app.availableSeats, equals(1));
      expect(app.hasCapacityForMore, isTrue);

      final trip3 = Trip(
        id: 't-3',
        passengerId: 'p-3',
        driverId: 'user-driver-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'E',
        dropoffAddress: 'F',
        pickup: const Geo(9.85, 123.98),
        dropoff: const Geo(9.86, 123.99),
        distanceKm: 1.0,
        durationMin: 5,
        fare: 15.0,
        commission: 0,
        net: 15.0,
        createdAt: DateTime.now(),
        status: RideStatus.accepted,
        passengerCount: 1,
      );

      app.activeTrips = [trip1, trip2, trip3];
      expect(app.activePassengersCount, equals(4));
      expect(app.availableSeats, equals(0));
      expect(app.hasCapacityForMore, isFalse);

      // Dropping off passenger 1 frees up 1 seat
      app.activeTrips = [trip2, trip3];
      expect(app.activePassengersCount, equals(3));
      expect(app.availableSeats, equals(1));
      expect(app.hasCapacityForMore, isTrue);
    });
  });

  group('BookingConfirmationModal Passenger Selector UI', () {
    testWidgets('Tricycle displays passenger selector and allows 1 to 4 pax',
        (tester) async {
      final driver = NearbyDriver(
        id: 'driver-1',
        name: 'John Fill',
        photoUrl: '',
        vehicleType: VehicleType.tricycle,
        plateNumber: '7788TG',
        rating: 5.0,
        ratingCount: 8,
        completedTrips: 8,
        acceptanceRate: 1.0,
        location: const Geo(9.85, 123.98),
        distanceKm: 0.8,
        etaMinutes: 2,
        isOnline: true,
        isAvailable: true,
      );

      const destination = Place(
        'Calape Public Market',
        Geo(9.89, 123.87),
      );

      int? confirmedCount;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BookingConfirmationModal(
              driver: driver,
              pickupAddress: 'Brgy. Poblacion Centro, Clarin, Bohol',
              destination: destination,
              distanceKm: 19.7,
              durationMins: 26,
              fare: 170.0,
              onConfirmWithCount: (count) async {
                confirmedCount = count;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PASSENGERS section is visible
      expect(find.text('PASSENGERS'), findsOneWidget);
      expect(find.text('1 Pax (Max 4)'), findsOneWidget);

      // Tap '+' button to increment to 2
      final addIcon = find.byIcon(Icons.add_circle_outline);
      expect(addIcon, findsOneWidget);
      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      expect(find.text('2 Pax (Max 4)'), findsOneWidget);

      // Tap '+' again to 3
      await tester.tap(addIcon);
      await tester.pumpAndSettle();
      expect(find.text('3 Pax (Max 4)'), findsOneWidget);

      // Tap '+' again to 4 (max)
      await tester.tap(addIcon);
      await tester.pumpAndSettle();
      expect(find.text('4 Pax (Max 4)'), findsOneWidget);

      // Tap Confirm Booking
      final confirmBtn = find.text('Confirm Booking');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(confirmedCount, equals(4));
    });

    testWidgets('Habal-Habal is fixed at 1 Pax (Single Rider)', (tester) async {
      final driver = NearbyDriver(
        id: 'driver-2',
        name: 'Motor Rider',
        photoUrl: '',
        vehicleType: VehicleType.habal,
        plateNumber: '1234MC',
        rating: 4.9,
        ratingCount: 15,
        completedTrips: 20,
        acceptanceRate: 1.0,
        location: const Geo(9.85, 123.98),
        distanceKm: 1.2,
        etaMinutes: 3,
        isOnline: true,
        isAvailable: true,
      );

      const destination = Place(
        'Calape Port',
        Geo(9.89, 123.87),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: BookingConfirmationModal(
              driver: driver,
              pickupAddress: 'Clarin Plaza',
              destination: destination,
              distanceKm: 19.7,
              durationMins: 20,
              fare: 220.0,
              onConfirm: () async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Pax (Single Rider)'), findsOneWidget);
      // Counter buttons should not exist for motorcycle
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });
  });
}

