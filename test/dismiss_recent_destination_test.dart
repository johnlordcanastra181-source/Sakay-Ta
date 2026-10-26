import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/state/passenger_search_bloc.dart';
import 'support/isolated_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Passenger can dismiss recent destination using DismissRecentDestinationEvent',
      () async {
    await useIsolatedDatabase();
    final db = await DatabaseService.instance.database;
    final app = AppState.instance;

    final passenger = AppUser(
      id: 'passenger-dismiss-test',
      fullName: 'Test Passenger',
      mobile: '09123456789',
      passwordHash: '',
      role: UserRole.passenger,
      createdAt: DateTime(2026),
    );
    await db.insert('users', passenger.toMap());
    app.currentUser = passenger;

    final bloc = PassengerSearchBloc(detectLocation: false);
    addTearDown(() {
      bloc.dispose();
      app.currentUser = null;
    });

    Trip makeTrip(String id, String dropoffAddress, Geo dropoff) => Trip(
          id: id,
          passengerId: passenger.id,
          vehicleType: VehicleType.tricycle,
          pickupAddress: 'Pickup Point',
          dropoffAddress: dropoffAddress,
          pickup: const Geo(14.6, 121),
          dropoff: dropoff,
          distanceKm: 2,
          durationMin: 8,
          fare: 40,
          commission: 4.8,
          net: 35.2,
          status: RideStatus.completed,
          createdAt: DateTime.now(),
        );

    await db.insert('trip',
        makeTrip('trip-1', 'Ayala Center Cebu', const Geo(10.317, 123.905)).toMap());
    await db.insert('trip',
        makeTrip('trip-2', 'SM City Cebu', const Geo(10.311, 123.918)).toMap());

    final loaded = bloc.stream.firstWhere((s) => s.recentDestinations.length == 2);
    await app.refreshTrips();
    final stateWithTwo = await loaded.timeout(const Duration(seconds: 5));
    expect(stateWithTwo.recentDestinations.map((p) => p.name).toList(),
        containsAll(['Ayala Center Cebu', 'SM City Cebu']));

    // Dismiss Ayala Center Cebu
    final placeToDismiss = stateWithTwo.recentDestinations
        .firstWhere((p) => p.name == 'Ayala Center Cebu');
    bloc.add(DismissRecentDestinationEvent(placeToDismiss));

    // Instant emission without Ayala Center Cebu
    expect(
        bloc.state.recentDestinations.map((p) => p.name).toList(),
        equals(['SM City Cebu']));

    // Subsequent history updates also do not restore dismissed place
    await app.refreshTrips();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
        bloc.state.recentDestinations.map((p) => p.name).toList(),
        equals(['SM City Cebu']));

    // Verify persisted in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedKeys = prefs.getStringList(
            'passenger_dismissed_recent_destinations_${passenger.id}') ??
        [];
    expect(savedKeys, contains('ayala center cebu'));
  });
}

