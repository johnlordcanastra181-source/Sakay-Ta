import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/l10n/app_localizations.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/firestore_models.dart';
import 'package:sakay_ta/models/trip.dart';
import 'package:sakay_ta/pages/my_rides.dart';
import 'package:sakay_ta/pages/wallet_page.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/widgets/ride_details_modal.dart';

class _TestHistoryWalletAppState extends AppState {
  _TestHistoryWalletAppState() : super.forTesting();

  Stream<List<RideEntry>> Function({String? status})? onRideHistoryStream;
  Stream<List<WalletEntry>> Function()? onTransactionsStream;
  Stream<AppUser?> Function(String userId)? onStreamUserProfile;
  Stream<Trip?> Function(String userId)? onStreamActiveTrip;
  List<RideEntry>? cachedHistoryOverride;
  List<WalletEntry>? cachedWalletOverride;
  final Map<String, RideEntry> cachedRideByIdOverride = {};
  int rideFetchByIdCalls = 0;

  @override
  List<RideEntry>? getCachedRideHistory({String? status}) {
    final all = cachedHistoryOverride;
    if (all == null) return null;
    if (status == null || status == 'all') return all;
    return all.where((e) => e.trip.status == status).toList();
  }

  @override
  List<WalletEntry>? getCachedWalletEntries(String driverId) {
    return cachedWalletOverride;
  }

  @override
  RideEntry? getCachedRideEntryById(String rideId) {
    return cachedRideByIdOverride[rideId];
  }

  @override
  Future<RideEntry?> getOrFetchRideEntryById(String rideId) async {
    final cached = getCachedRideEntryById(rideId);
    if (cached != null) return cached;
    rideFetchByIdCalls++;
    final trip = Trip(
      id: rideId,
      passengerId: 'passenger-1',
      passengerName: 'Maria Clara',
      driverId: 'driver-1',
      vehicleType: VehicleType.tricycle,
      pickup: const Geo(7.4478, 125.8078),
      dropoff: const Geo(7.4520, 125.8120),
      pickupAddress: 'Tagum Public Market',
      dropoffAddress: 'Gaisano Mall Tagum',
      distanceKm: 2.4,
      durationMin: 8,
      fare: 45.0,
      commission: 0.0,
      net: 45.0,
      paymentMethod: 'cash',
      status: RideStatus.completed,
      createdAt: DateTime(2026, 10, 16, 10, 0),
      completedAt: DateTime(2026, 10, 16, 10, 8),
    );
    final entry = RideEntry(
      trip: trip,
      driverName: 'Juan Dela Cruz',
      plateNumber: 'ABC-1234',
    );
    cachedRideByIdOverride[rideId] = entry;
    return entry;
  }

  @override
  Stream<List<RideEntry>> rideHistoryStream({String? status}) {
    if (onRideHistoryStream != null) {
      return onRideHistoryStream!(status: status);
    }
    return const Stream.empty();
  }

  @override
  Stream<List<WalletEntry>> transactionsStream() {
    if (onTransactionsStream != null) {
      return onTransactionsStream!();
    }
    return const Stream.empty();
  }

  @override
  Stream<AppUser?> streamUserProfile(String uid) {
    if (onStreamUserProfile != null) {
      return onStreamUserProfile!(uid);
    }
    return Stream.value(currentUser);
  }

  @override
  Stream<Trip?> streamActiveTripForPassenger(String passengerId) {
    if (onStreamActiveTrip != null) {
      return onStreamActiveTrip!(passengerId);
    }
    return Stream.value(null);
  }

  @override
  Stream<Trip?> streamActiveTripForDriver(String driverId) {
    if (onStreamActiveTrip != null) {
      return onStreamActiveTrip!(driverId);
    }
    return Stream.value(null);
  }
}

Widget _wrapWithApp(_TestHistoryWalletAppState appState, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Trip _sampleTrip({
  required String id,
  String status = RideStatus.completed,
  String? driverId = 'driver-1',
  String passengerName = 'Maria Clara',
  double fare = 55.0,
}) {
  return Trip(
    id: id,
    passengerId: 'passenger-1',
    passengerName: passengerName,
    driverId: driverId,
    vehicleType: VehicleType.tricycle,
    pickup: const Geo(7.4478, 125.8078),
    dropoff: const Geo(7.4520, 125.8120),
    pickupAddress: 'Apokon Road, Tagum City',
    dropoffAddress: 'New City Hall, Tagum City',
    distanceKm: 3.2,
    durationMin: 11,
    fare: fare,
    commission: 0.0,
    net: fare,
    paymentMethod: 'cash',
    status: status,
    rating: 5,
    createdAt: DateTime(2026, 10, 16, 9, 30),
    completedAt:
        status == RideStatus.completed ? DateTime(2026, 10, 16, 9, 41) : null,
  );
}

void main() {
  testWidgets(
      'Driver Wallet shows loading indicator during initial load and never flashes "No transactions yet" before records arrive',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'driver-1',
      fullName: 'Juan Dela Cruz',
      email: 'juan@sakayta.app',
      mobile: '09171234567',
      passwordHash: '',
      role: UserRole.driver,
      status: AccountStatus.approved,
      isOnline: true,
      createdAt: DateTime(2026, 1, 1),
    );
    appState.driverProfile = DriverProfile(
      userId: 'driver-1',
      licenseNumber: 'L01-23-456789',
      licenseExpiry: '2028-10-10',
      vehicleType: VehicleType.tricycle,
      plateNumber: 'ABC-1234',
      submittedAt: DateTime(2026, 1, 1),
    );

    final txController = StreamController<List<WalletEntry>>();
    addTearDown(txController.close);
    appState.onTransactionsStream = () => txController.stream;

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );

    // 1. While initial query is pending, loading indicator is shown and "No transactions yet" is NOT shown.
    expect(find.text('Loading payment history...'), findsOneWidget);
    expect(find.text('No transactions yet'), findsNothing);

    // 2. Emit actual driver earnings record.
    final entry = WalletEntry.fromEarning(
      DriverEarning(
        id: 'earn-1',
        driverId: 'driver-1',
        rideId: 'ride-101',
        fare: 65.0,
        commission: 0.0,
        net: 65.0,
        paymentMethod: 'cash',
        settlementStatus: 'confirmed',
        createdAt: DateTime(2026, 10, 16, 12, 0),
      ),
    );
    txController.add([entry]);
    await tester.pump();

    expect(find.text('Loading payment history...'), findsNothing);
    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('Ride #ride-101'), findsOneWidget);
    expect(find.text('+₱65.00'), findsOneWidget);
    expect(find.text('65.00'), findsOneWidget);

    // 3. Emit a second update (e.g. newly completed ride) to verify stream does not deadlock.
    final entry2 = WalletEntry.fromEarning(
      DriverEarning(
        id: 'earn-2',
        driverId: 'driver-1',
        rideId: 'ride-102',
        fare: 85.0,
        commission: 0.0,
        net: 85.0,
        paymentMethod: 'cash',
        settlementStatus: 'confirmed',
        createdAt: DateTime(2026, 10, 16, 12, 30),
      ),
    );
    txController.add([entry2, entry]);
    await tester.pump();

    expect(find.text('Ride #ride-102'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);
  });

  testWidgets(
      'Driver Wallet shows 3 recent transactions initially and toggles View All / Show Less seamlessly',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'driver-toggle',
      fullName: 'Juan Driver',
      email: 'juan@sakayta.app',
      mobile: '09170001111',
      passwordHash: '',
      role: UserRole.driver,
      status: AccountStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

    final entries = List.generate(
      5,
      (i) => WalletEntry.fromEarning(
        DriverEarning(
          id: 'earn-$i',
          driverId: 'driver-toggle',
          rideId: 'ride-00$i',
          fare: 25.0 * (i + 1),
          commission: 0.0,
          net: 25.0 * (i + 1),
          paymentMethod: 'cash',
          settlementStatus: 'confirmed',
          createdAt: DateTime(2026, 10, 16, 10 + i, 0),
        ),
      ),
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final txController = StreamController<List<WalletEntry>>();
    addTearDown(txController.close);
    appState.onTransactionsStream = () => txController.stream;

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );

    txController.add(entries);
    await tester.pumpAndSettle();

    // 1. Initially only the top 3 items are shown
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // Count badge
    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Ride #ride-004'), findsOneWidget);
    expect(find.text('Ride #ride-003'), findsOneWidget);
    expect(find.text('Ride #ride-002'), findsOneWidget);
    expect(find.text('Ride #ride-001'), findsNothing);
    expect(find.text('Ride #ride-000'), findsNothing);

    // 2. Tap View All -> all 5 items are instantly revealed without lag
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.text('Show Less'), findsWidgets);
    expect(find.text('Ride #ride-004'), findsOneWidget);
    expect(find.text('Ride #ride-003'), findsOneWidget);
    expect(find.text('Ride #ride-002'), findsOneWidget);
    expect(find.text('Ride #ride-001'), findsOneWidget);
    expect(find.text('Ride #ride-000'), findsOneWidget);

    // 3. Tap Show Less -> collapses back to the top 3 items
    await tester.tap(find.text('Show Less').first);
    await tester.pumpAndSettle();

    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Ride #ride-004'), findsOneWidget);
    expect(find.text('Ride #ride-003'), findsOneWidget);
    expect(find.text('Ride #ride-002'), findsOneWidget);
    expect(find.text('Ride #ride-001'), findsNothing);
    expect(find.text('Ride #ride-000'), findsNothing);
  });

  testWidgets(
      'Driver Wallet with zero records shows "No transactions yet" only after initial fetch completes',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'driver-empty',
      fullName: 'Pedro Penduko',
      email: 'pedro@sakayta.app',
      mobile: '09181234567',
      passwordHash: '',
      role: UserRole.driver,
      status: AccountStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

    final txController = StreamController<List<WalletEntry>>();
    addTearDown(txController.close);
    appState.onTransactionsStream = () => txController.stream;

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );

    expect(find.text('Loading payment history...'), findsOneWidget);
    expect(find.text('No transactions yet'), findsNothing);

    txController.add(const []);
    await tester.pump();

    expect(find.text('Loading payment history...'), findsNothing);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets(
      'Driver Wallet query failure shows explicit error state with Retry button and recovers on retry',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'driver-err',
      fullName: 'Juan Dela Cruz',
      email: 'juan@sakayta.app',
      mobile: '09171234567',
      passwordHash: '',
      role: UserRole.driver,
      status: AccountStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

    var attempts = 0;
    appState.onTransactionsStream = () {
      attempts++;
      if (attempts == 1) {
        return Stream<List<WalletEntry>>.error(Exception('Network timeout'));
      }
      return Stream.value([
        WalletEntry.fromEarning(
          DriverEarning(
            id: 'earn-recovered',
            driverId: 'driver-err',
            rideId: 'ride-777',
            fare: 50.0,
            commission: 0.0,
            net: 50.0,
            paymentMethod: 'cash',
            settlementStatus: 'confirmed',
            createdAt: DateTime(2026, 10, 16, 14, 0),
          ),
        ),
      ]);
    };

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );
    await tester.pump();

    expect(
      find.text('Unable to load wallet data. Check your connection.'),
      findsOneWidget,
    );
    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Ride #ride-777'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets(
      'Passenger Wallet does not show premature empty state and opens Receipt modal on tap',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'passenger-1',
      fullName: 'Maria Clara',
      email: 'maria@sakayta.app',
      mobile: '09191234567',
      passwordHash: '',
      role: UserRole.passenger,
      status: AccountStatus.active,
      createdAt: DateTime(2026, 1, 1),
    );

    final historyController = StreamController<List<RideEntry>>();
    addTearDown(historyController.close);
    appState.onRideHistoryStream = ({status}) => historyController.stream;

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );

    // Initial loading state: no premature "No payment records yet."
    expect(find.text('Loading payment history...'), findsOneWidget);
    expect(find.text('No payment records yet.'), findsNothing);

    final completedEntry = RideEntry(
      trip: _sampleTrip(id: 'ride-pass-1', fare: 75.0),
      driverName: 'Juan Dela Cruz',
      plateNumber: 'TAG-1001',
    );
    historyController.add([completedEntry]);
    await tester.pump();

    expect(find.text('Loading payment history...'), findsNothing);
    expect(find.text('Paid via CASH'), findsOneWidget);
    expect(find.text('₱75.00'), findsOneWidget);

    // Tap payment record to open receipt details modal immediately.
    await tester.tap(find.text('Paid via CASH'));
    await tester.pumpAndSettle();

    expect(find.byType(RideDetailsModal), findsOneWidget);
    expect(find.text('Trip Receipt & Details'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
  });

  testWidgets(
      'History Page switches filters in memory without re-subscribing and handles deleted driver profiles gracefully',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'passenger-1',
      fullName: 'Maria Clara',
      email: 'maria@sakayta.app',
      mobile: '09191234567',
      passwordHash: '',
      role: UserRole.passenger,
      status: AccountStatus.active,
      createdAt: DateTime(2026, 1, 1),
    );

    var streamSubscriptions = 0;
    final entries = [
      RideEntry(
        trip: _sampleTrip(
          id: 'ride-completed-deleted-driver',
          status: RideStatus.completed,
          driverId:
              null, // Simulates deleted driver account (ON DELETE SET NULL)
          fare: 45.0,
        ),
        driverName: 'Assigned Driver',
        plateNumber: '',
      ),
      RideEntry(
        trip: _sampleTrip(
          id: 'ride-cancelled-1',
          status: RideStatus.cancelled,
          driverId: null,
          fare: 30.0,
        ),
        driverName: '',
        plateNumber: '',
      ),
    ];

    appState.onRideHistoryStream = ({status}) {
      streamSubscriptions++;
      return Stream.value(entries);
    };

    await tester.pumpWidget(
      _wrapWithApp(appState, MyRides(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(streamSubscriptions, 1);
    expect(find.text('Assigned Driver'), findsOneWidget);
    expect(find.text('₱45.00'), findsOneWidget);
    expect(find.text('₱30.00'), findsOneWidget);

    // Switch filter to Completed -> filters in memory without new stream subscription
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(streamSubscriptions, 1);
    expect(find.text('₱45.00'), findsOneWidget);
    expect(find.text('₱30.00'), findsNothing);

    // Switch filter to Cancelled -> filters in memory without new stream subscription
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(streamSubscriptions, 1);
    expect(find.text('₱45.00'), findsNothing);
    expect(find.text('₱30.00'), findsOneWidget);
  });

  testWidgets(
      'Opening a Driver Wallet receipt fetches once and reuses in-memory cache on repeat open',
      (tester) async {
    final appState = _TestHistoryWalletAppState();
    appState.currentUser = AppUser(
      id: 'driver-1',
      fullName: 'Juan Dela Cruz',
      email: 'juan@sakayta.app',
      mobile: '09171234567',
      passwordHash: '',
      role: UserRole.driver,
      status: AccountStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

    final earningEntry = WalletEntry.fromEarning(
      DriverEarning(
        id: 'earn-cache-1',
        driverId: 'driver-1',
        rideId: 'ride-cache-99',
        fare: 45.0,
        commission: 0.0,
        net: 45.0,
        paymentMethod: 'cash',
        settlementStatus: 'confirmed',
        createdAt: DateTime(2026, 10, 16, 15, 0),
      ),
    );
    appState.onTransactionsStream = () => Stream.value([earningEntry]);

    await tester.pumpWidget(
      _wrapWithApp(appState, WalletPage(onNavigate: (_) {})),
    );
    await tester.pumpAndSettle();

    // 1st tap: fetches RideEntry once and caches it
    await tester.tap(find.text('Ride #ride-cache-99'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Receipt & Details'), findsOneWidget);
    expect(find.text('Tagum Public Market'), findsOneWidget);
    expect(appState.rideFetchByIdCalls, 1);

    // Close receipt modal
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 2nd tap: reuses cached RideEntry with 0 additional fetches
    await tester.tap(find.text('Ride #ride-cache-99'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Receipt & Details'), findsOneWidget);
    expect(appState.rideFetchByIdCalls, 1);
  });

  test(
      'SQL migration 202610160001 adds composite indexes and batch driver display info RPC',
      () {
    final migration = File(
      'supabase/migrations/202610160001_optimize_history_and_wallet_queries.sql',
    ).readAsStringSync();

    expect(migration, contains('rides_passenger_status_created_idx'));
    expect(migration, contains('rides_driver_status_created_idx'));
    expect(migration, contains('driver_earnings_driver_created_idx'));
    expect(migration, contains('withdrawals_driver_requested_idx'));
    expect(migration, contains('payments_passenger_created_idx'));
    expect(migration, contains('payments_driver_created_idx'));
    expect(
      migration,
      contains(
          'CREATE OR REPLACE FUNCTION public.get_ride_driver_display_info'),
    );
    expect(
      migration,
      contains(
          'GRANT EXECUTE ON FUNCTION public.get_ride_driver_display_info(uuid[]) TO authenticated'),
    );
  });
}
