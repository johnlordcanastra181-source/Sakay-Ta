import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/models/app_user.dart';
import 'package:sakay_ta/models/driver_profile.dart';
import 'package:sakay_ta/models/firestore_models.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/state/app_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService.instance.database;
    await db.delete('transactions');
    final app = AppState.instance;
    await app.init();
  });

  group('Driver Wallet Real-Time Financials & Atomic Operations Tests', () {
    test('Cash and GCash trips are correctly separated and stream in real time', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'wallet_test_driver_1',
        fullName: 'Jose Rizal',
        mobile: '09170000001',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );
      app.currentUser = driver;
      app.driverProfile = DriverProfile(
        userId: driver.id,
        vehicleType: VehicleType.tricycle,
        submittedAt: DateTime.now(),
      );
      await app.refreshTransactions();

      // Record a Cash trip income
      await app.earnings.recordTripIncome(
        driverId: driver.id,
        tripId: 'trip_cash_1',
        fare: 100.0,
        method: 'cash',
      );

      // Record a GCash digital trip income
      await app.earnings.recordTripIncome(
        driverId: driver.id,
        tripId: 'trip_gcash_1',
        fare: 150.0,
        method: 'gcash',
      );

      await app.refreshTransactions();

      // Check transactions stream
      final transactions = await app.transactionsStream().first;
      expect(transactions.length, 2);

      final cashTotal = await app.streamCashEarnings(driver.id).first;
      final digitalTotal = await app.streamDigitalEarnings(driver.id).first;
      final totalBal = await app.streamAvailableBalance(driver.id).first;

      expect(cashTotal, 100.0);
      expect(digitalTotal, 150.0);
      expect(totalBal, 250.0);
    });

    test('Withdrawal atomically deducts balance and logs transaction', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'wallet_test_driver_2',
        fullName: 'Andres Bonifacio',
        mobile: '09170000002',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );
      app.currentUser = driver;
      app.driverProfile = DriverProfile(
        userId: driver.id,
        vehicleType: VehicleType.tricycle,
        submittedAt: DateTime.now(),
      );

      // Credit earnings: 500 fare
      await app.earnings.recordTripIncome(
        driverId: driver.id,
        tripId: 'trip_for_withdrawal',
        fare: 500.0,
        method: 'gcash',
      );
      await app.refreshTransactions();

      final initialBal = await app.streamAvailableBalance(driver.id).first;
      expect(initialBal, greaterThanOrEqualTo(500.0));

      final balBefore = initialBal;

      // Withdraw 200 via GCash
      await app.withdraw(
        amount: 200.0,
        method: 'gcash',
        accountDetails: '09170000002',
      );

      final postWithdrawBal = await app.streamAvailableBalance(driver.id).first;
      expect(postWithdrawBal, closeTo(balBefore - 200.0, 0.01));

      final txs = await app.transactionsStream().first;
      final withdrawalTx = txs.firstWhere((t) => t.type == 'withdrawal');
      expect(withdrawalTx.amount, -200.0);
      expect(withdrawalTx.method, 'gcash');
    });

    test('Withdrawal validation prevents overdrafts and zero amounts', () async {
      final app = AppState.instance;

      final driver = AppUser(
        id: 'wallet_test_driver_3',
        fullName: 'Apolinario Mabini',
        mobile: '09170000003',
        passwordHash: 'hash',
        role: UserRole.driver,
        isOnline: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );
      app.currentUser = driver;

      // Try withdrawing amount larger than balance
      expect(
        () async => await app.withdraw(amount: 9999999.0, method: 'gcash'),
        throwsA(isA<Exception>()),
      );

      // Try withdrawing invalid negative amount
      expect(
        () async => await app.withdraw(amount: -50.0, method: 'gcash'),
        throwsA(isA<Exception>()),
      );

      // Try withdrawing zero amount
      expect(
        () async => await app.withdraw(amount: 0.0, method: 'gcash'),
        throwsA(isA<Exception>()),
      );
    });

    test('DriverEarning model preserves paymentMethod in serialization', () {
      final earning = DriverEarning(
        id: 'earn_test_1',
        driverId: 'driver_1',
        rideId: 'ride_1',
        fare: 85.0,
        commission: 10.2,
        net: 74.8,
        paymentMethod: 'gcash',
        createdAt: DateTime.now(),
      );

      final map = earning.toMap();
      expect(map['paymentMethod'], 'gcash');

      final deserialized = DriverEarning.fromMap(map);
      expect(deserialized.paymentMethod, 'gcash');
      expect(deserialized.net, 74.8);
    });

    test('cash wallet entries use gross fare despite legacy commission net', () {
      final cashEarning = DriverEarning(
        id: 'earn_legacy_cash',
        driverId: 'driver_1',
        rideId: 'ride_legacy_cash',
        fare: 225.20,
        commission: 140.20,
        net: 85.00,
        paymentMethod: 'cash',
        settlementStatus: 'confirmed',
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final cashEntry = WalletEntry.fromEarning(cashEarning);

      expect(cashEntry.amount, closeTo(225.20, 0.001));

      final digitalEntry = WalletEntry.fromEarning(DriverEarning(
        id: 'earn_digital',
        driverId: 'driver_1',
        rideId: 'ride_digital',
        fare: 225.20,
        commission: 140.20,
        net: 85.00,
        paymentMethod: 'gcash',
        settlementStatus: 'confirmed',
        createdAt: DateTime.utc(2026, 10, 1),
      ));
      expect(digitalEntry.amount, 85.00);
    });
  });
}
