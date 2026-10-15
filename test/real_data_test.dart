import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/saved_place.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/payment_service.dart';
import 'package:sakay_ta/services/saved_places_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/state/passenger_search_bloc.dart';
import 'support/isolated_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('New passengers have no invented places, wallets, location or weather',
      () async {
    await SavedPlacesService.instance.init('new-passenger');
    await PaymentService.instance.init('new-passenger');
    expect(SavedPlacesService.instance.places, isEmpty);
    expect(PaymentService.instance.methods.map((m) => m.type),
        [PaymentMethod.cash]);
    const state = PassengerSearchState();
    expect(state.recentDestinations, isEmpty);
    expect(state.popularPlaces, isEmpty);
    expect(state.hasLocation, isFalse);
    expect(state.weatherTemperatureLabel, 'Unavailable');
    final linking = await PaymentService.instance.requestGcashLinking(
        mobileNumber: '09170000000', accountName: 'A Passenger');
    expect(linking.success, isFalse);
    expect(linking.otpCode, isEmpty);
  });

  test('Legacy sample addresses are removed while user-created places survive',
      () async {
    SavedPlace place(String id, String address) => SavedPlace(
        id: id,
        userId: 'passenger-a',
        name: 'Home',
        address: address,
        geo: const Geo(14.6, 121),
        createdAt: DateTime(2026));
    SharedPreferences.setMockInitialValues({
      'passenger_saved_places_v2_passenger-a': jsonEncode([
        place('place_home_default', 'Banilad, Cebu City, Cebu').toMap(),
        place('my-place', 'My actual address').toMap(),
      ]),
    });
    await SavedPlacesService.instance.init('passenger-a');
    expect(SavedPlacesService.instance.places.map((p) => p.id), ['my-place']);
    await SavedPlacesService.instance.init('passenger-b');
    expect(SavedPlacesService.instance.places, isEmpty);
    await SavedPlacesService.instance.init('passenger-a');
    expect(
        SavedPlacesService.instance.places.single.address, 'My actual address');
    await SavedPlacesService.instance.init(null);
    expect(SavedPlacesService.instance.places, isEmpty);
  });

  test(
      'Recent destinations follow persisted passenger rides and account changes',
      () async {
    await useIsolatedDatabase();
    final db = await DatabaseService.instance.database;
    expect(await db.query('users'), isEmpty);
    expect(await db.query('reports'), isEmpty);
    expect(await db.query('toda_associations'), isEmpty);
    final app = AppState.instance;
    final a = AppUser(
        id: 'passenger-a',
        fullName: 'Passenger A',
        mobile: '',
        passwordHash: '',
        role: UserRole.passenger,
        createdAt: DateTime(2026));
    final b = a.copyWith(id: 'passenger-b', fullName: 'Passenger B');
    await db.insert('users', a.toMap());
    await db.insert('users', b.toMap());
    app.currentUser = a;
    final bloc = PassengerSearchBloc(detectLocation: false);
    addTearDown(() {
      bloc.dispose();
      app.currentUser = null;
    });
    expect(bloc.state.recentDestinations, isEmpty);
    Trip ride(String id, String passenger, String address, int day, Geo dropoff,
            {String status = RideStatus.completed}) =>
        Trip(
            id: id,
            passengerId: passenger,
            vehicleType: VehicleType.tricycle,
            pickupAddress: 'Actual pickup',
            dropoffAddress: address,
            pickup: const Geo(14.6, 121),
            dropoff: dropoff,
            distanceKm: 2,
            durationMin: 8,
            fare: 40,
            commission: 4.8,
            net: 35.2,
            status: status,
            createdAt: DateTime(2026, 9, day));
    for (final trip in [
      ride('a-old', a.id, 'Actual destination', 1, const Geo(14.61, 121.01)),
      ride('a-new', a.id, 'Actual destination', 3, const Geo(14.61, 121.01)),
      ride('a-cancelled', a.id, 'Cancelled destination', 4,
          const Geo(14.62, 121.02),
          status: RideStatus.cancelled),
      ride('b-ride', b.id, 'Other passenger destination', 5,
          const Geo(14.63, 121.03)),
    ]) {
      await db.insert('trip', trip.toMap());
    }
    final loadedA =
        bloc.stream.firstWhere((s) => s.recentDestinations.isNotEmpty);
    await app.refreshTrips();
    expect(
        (await loadedA.timeout(const Duration(seconds: 5)))
            .recentDestinations
            .map((p) => p.name),
        ['Actual destination']);
    final newRide = await app.trips.requestTrip(
      passengerId: a.id,
      vehicleType: VehicleType.tricycle,
      pickupAddress: 'Actual pickup',
      dropoffAddress: 'Newly booked destination',
      pickup: const Geo(14.6, 121),
      dropoff: const Geo(14.64, 121.04),
      estimatedFare: 40.0,
      queued: true,
    );
    expect(newRide.passengerName, a.fullName);
    expect((await db.query('booking')).single['passenger_id'], a.id);
    final updatedHistory = bloc.stream.firstWhere((s) =>
        s.recentDestinations.any((p) => p.name == 'Newly booked destination'));
    await app.refreshTrips();
    expect(
        (await updatedHistory.timeout(const Duration(seconds: 5)))
            .recentDestinations
            .first
            .name,
        'Newly booked destination');
    final loadedB = bloc.stream.firstWhere((s) => s.recentDestinations
        .any((p) => p.name == 'Other passenger destination'));
    app.currentUser = b;
    await app.refreshTrips();
    expect(
        (await loadedB.timeout(const Duration(seconds: 5)))
            .recentDestinations
            .single
            .name,
        'Other passenger destination');
    expect(await bloc.confirmSelectedBooking(), isFalse);
  });
}
