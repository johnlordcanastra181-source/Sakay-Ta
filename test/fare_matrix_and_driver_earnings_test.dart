import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/driver_matching_service.dart';
import 'package:sakay_ta/services/fare_calculator.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/booking_confirmation_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin Fare Matrix Rate Calculations', () {
    test(
        'Calculates exact Admin rates for 7.5 km (P40 Tricycle, P60 Habal-Habal)',
        () {
      final app = AppState.instance;

      final tricycleMatrix = app.getFareMatrixFor(VehicleType.tricycle);
      expect(tricycleMatrix.baseFare, 0.0);
      expect(tricycleMatrix.includedBaseDistance, 0.0);
      expect(tricycleMatrix.perKmRate, 5.0);
      expect(tricycleMatrix.minimumFare, 10.0);
      expect(tricycleMatrix.commissionPercent, 0.0);

      final habalMatrix = app.getFareMatrixFor(VehicleType.habal);
      expect(habalMatrix.baseFare, 20.0);
      expect(habalMatrix.includedBaseDistance, 0.0);
      expect(habalMatrix.perKmRate, 5.0);
      expect(habalMatrix.minimumFare, 15.0);
      expect(habalMatrix.commissionPercent, 0.0);

      // Verify 7.5 km trip fare calculation matches Admin portal simulator
      final tricycleFare = FareCalculator.calculateFare(
        matrix: tricycleMatrix,
        distanceKm: 7.5,
        durationMinutes: 0,
      );
      expect(tricycleFare, 40.0); // 7.5 * 5 = 37.5 -> rounded nearest P5 = P40

      final habalFare = FareCalculator.calculateFare(
        matrix: habalMatrix,
        distanceKm: 7.5,
        durationMinutes: 0,
      );
      expect(habalFare, 60.0); // 20 + 37.5 = 57.5 -> rounded nearest P5 = P60

      // Also verify via RideConfig & DriverMatchingService
      expect(RideConfig.fareFor(VehicleType.tricycle, 7.5), 40.0);
      expect(RideConfig.fareFor(VehicleType.habal, 7.5), 60.0);
      expect(
          DriverMatchingService.instance.calculateFare(
            vehicleType: VehicleType.tricycle,
            distanceKm: 7.5,
          ),
          40.0);
      expect(
          DriverMatchingService.instance.calculateFare(
            vehicleType: VehicleType.habal,
            distanceKm: 7.5,
          ),
          60.0);
    });

    test('Trip creation sets 100% of fare as driver earnings with 0 commission',
        () {
      const fare = 40.0;
      final trip = Trip(
        id: 'test-trip',
        passengerId: 'p-1',
        driverId: 'd-1',
        vehicleType: VehicleType.tricycle,
        pickupAddress: 'Pickup',
        dropoffAddress: 'Dropoff',
        pickup: const Geo(10.3, 123.8),
        dropoff: const Geo(10.35, 123.85),
        distanceKm: 7.5,
        durationMin: 15,
        fare: fare,
        commission: 0,
        net: fare,
        paymentMethod: PaymentMethod.cash,
        createdAt: DateTime.now(),
      );

      expect(trip.fare, 40.0);
      expect(trip.commission, 0.0);
      expect(trip.net, 40.0);
      expect(trip.paymentMethod, 'cash');
    });
  });

  group('BookingConfirmationModal UI Verification', () {
    testWidgets(
        'Displays Cash Payment directly to driver and Confirm Booking with fare',
        (tester) async {
      final driver = NearbyDriver(
        id: 'driver-1',
        name: 'Juan Driver',
        photoUrl: '',
        vehicleType: VehicleType.tricycle,
        plateNumber: 'ABC 1234',
        rating: 4.9,
        ratingCount: 20,
        completedTrips: 50,
        acceptanceRate: 98.0,
        location: const Geo(10.3, 123.8),
        distanceKm: 1.2,
        etaMinutes: 4,
        isOnline: true,
      );

      const destination = Place(
        'SM City Cebu',
        Geo(10.311, 123.918),
        'North Reclamation Area, Cebu City',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: BookingConfirmationModal(
              driver: driver,
              pickupAddress: 'Fuente Osmeña, Cebu City',
              destination: destination,
              distanceKm: 7.5,
              durationMins: 15,
              fare: 40.0,
              onConfirm: () async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Cash Payment is displayed prominently
      expect(find.text('PAYMENT METHOD'), findsOneWidget);
      expect(
          find.text('Cash Payment • Pay directly to driver'), findsOneWidget);

      // Verify Total Fare is P40
      expect(find.text('TOTAL FARE'), findsOneWidget);
      expect(find.text('₱40'), findsOneWidget);

      // Verify confirmation button shows Confirm Booking (₱40)
      expect(find.text('Confirm Booking (₱40)'), findsOneWidget);

      // Verify digital payment provider buttons are NOT shown
      expect(find.text('Book with GCash'), findsNothing);
      expect(find.text('Book with Maya'), findsNothing);
    });
  });
}
