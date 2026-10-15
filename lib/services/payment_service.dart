import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/firestore_models.dart';
import '../models/payment_method_model.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'online_payment_gateway.dart';

class PaymentService extends ChangeNotifier {
  PaymentService._({OnlinePaymentGatewayInterface? gateway})
      : gateway = gateway ?? PayMongoGatewayService();

  static final PaymentService instance = PaymentService._();

  /// Gateway interface for GCash and Maya online checkout & verification
  final OnlinePaymentGatewayInterface gateway;

  static const String _kSavedMethodsKey = 'passenger_saved_payment_methods_v2';
  static const String _kDefaultMethodKey =
      'passenger_default_payment_method_id';

  List<PassengerPaymentMethod> _methods = [
    PassengerPaymentMethod.defaultCash()
  ];
  String _defaultMethodId = 'pm_cash_default';

  // Active in-flight payment sessions to prevent duplicate checkout requests
  final Map<String, GatewayPaymentResult> _inFlightSessions = {};

  List<PassengerPaymentMethod> get methods => List.unmodifiable(_methods);
  PassengerPaymentMethod get defaultMethod =>
      PassengerPaymentMethod.defaultCash();

  String get defaultPaymentSummary => 'Cash';

  Future<void> init(String? userId) async {
    await _loadFromStorage(userId);
  }

  Future<void> _loadFromStorage(String? userId) async {
    _methods = [PassengerPaymentMethod.defaultCash()];
    _defaultMethodId = 'pm_cash_default';
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_kSavedMethodsKey}_$userId';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        // Previous wallet/card linking was simulated, so those records do
        // not represent provider-verified payment methods.
        _methods = decoded
            .map((item) => PassengerPaymentMethod.fromMap(
                Map<String, Object?>.from(item as Map)))
            .where((m) => m.type == PaymentMethod.cash)
            .toList();
        if (!_methods.any((m) => m.type == PaymentMethod.cash)) {
          _methods.add(PassengerPaymentMethod.defaultCash());
        }
      }
      final savedDefault = prefs.getString('${_kDefaultMethodKey}_$userId');
      if (savedDefault != null && _methods.any((m) => m.id == savedDefault)) {
        _defaultMethodId = savedDefault;
      }
      await _saveToStorage(userId);
    } catch (e) {
      debugPrint('PaymentService: error loading storage $e');
    }
    notifyListeners();
  }

  Future<void> _saveToStorage(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          userId != null ? '${_kSavedMethodsKey}_$userId' : _kSavedMethodsKey;
      final raw = jsonEncode(_methods.map((m) => m.toMap()).toList());
      await prefs.setString(key, raw);

      await prefs.setString(
          '${_kDefaultMethodKey}_${userId ?? "anon"}', _defaultMethodId);

      // Sync payment methods summary to Firestore passenger document if online
      if (userId != null && SupabaseService.isConfigured) {
        final summaryList = _methods.map((m) => m.title).toList();
        await SupabaseService.instance.savePassengerProfile(
          userId,
          paymentMethods: summaryList,
        );
      }
    } catch (e) {
      debugPrint('PaymentService: save storage error $e');
    }
    notifyListeners();
  }

  Future<void> setDefault(String userId, String methodId) async {
    _defaultMethodId = methodId;
    _methods = _methods.map((m) {
      return m.copyWith(isDefault: m.id == methodId);
    }).toList();
    await _saveToStorage(userId);
  }

  Future<void> addMethod(String userId, PassengerPaymentMethod method) async {
    _methods.removeWhere((m) => m.id == method.id);
    if (method.isDefault) {
      _methods = _methods.map((m) => m.copyWith(isDefault: false)).toList();
      _defaultMethodId = method.id;
    }
    _methods.insert(0, method);
    await _saveToStorage(userId);
  }

  Future<void> removeMethod(String userId, String methodId) async {
    if (methodId == 'pm_cash_default') {
      return; // Cash cannot be removed
    }
    _methods.removeWhere((m) => m.id == methodId);
    if (_defaultMethodId == methodId) {
      _defaultMethodId =
          _methods.isNotEmpty ? _methods.first.id : 'pm_cash_default';
      _methods = _methods
          .map((m) => m.copyWith(isDefault: m.id == _defaultMethodId))
          .toList();
    }
    await _saveToStorage(userId);
  }

  // =========================================================================
  // REAL-TIME ONLINE PAYMENT GATEWAY INTEGRATION (GCASH & MAYA)
  // =========================================================================

  /// Initiates an actual online payment checkout session via PayMongo/Maya gateway.
  /// Enforces Idempotency to prevent duplicate payments for the same ride.
  Future<GatewayPaymentResult> initiateOnlinePaymentSession({
    required String tripId,
    required String passengerId,
    required double amount,
    required String paymentMethodType, // 'gcash' | 'maya'
    String? driverId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? pickupAddress,
    String? dropoffAddress,
  }) async {
    // 1. Idempotency Check: Prevent duplicate payment initiation for the same ride
    final idempotencyKey = '${tripId}_$passengerId';
    if (_inFlightSessions.containsKey(idempotencyKey)) {
      final existing = _inFlightSessions[idempotencyKey]!;
      if (!existing.isFailed) {
        debugPrint(
            'PaymentService: Reusing existing checkout session for $tripId');
        return existing;
      }
    }

    // 2. Check if Firestore already has a payment record for this ride
    if (SupabaseService.isConfigured) {
      final existingDoc =
          await SupabaseService.instance.getPaymentForRide(tripId);
      if (existingDoc != null && existingDoc.status == 'paid') {
        final result = GatewayPaymentResult(
          sessionId: existingDoc.sessionId ?? 'session_$tripId',
          status: 'paid',
          amount: existingDoc.amount,
          currency: 'PHP',
          paymentMethodType: existingDoc.method,
          referenceNumber: existingDoc.reference ?? 'ST-PAID-$tripId',
          paidAt: existingDoc.verifiedAt ?? existingDoc.createdAt,
        );
        _inFlightSessions[idempotencyKey] = result;
        return result;
      }
    }

    // 3. Create actual checkout session with the payment gateway
    final sessionResult = await gateway.createCheckoutSession(
      tripId: tripId,
      passengerId: passengerId,
      amount: amount,
      paymentMethodType: paymentMethodType,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
    );

    _inFlightSessions[idempotencyKey] = sessionResult;

    // 4. Record pending payment intent in Firestore
    if (SupabaseService.isConfigured) {
      final paymentDoc = FirePayment(
        id: 'pay_$tripId',
        rideId: tripId,
        payerId: passengerId,
        payeeId: driverId ?? '',
        amount: amount,
        method: paymentMethodType,
        status: 'pending_payment',
        reference: sessionResult.referenceNumber,
        sessionId: sessionResult.sessionId,
        checkoutUrl: sessionResult.checkoutUrl,
        createdAt: DateTime.now(),
      );
      await SupabaseService.instance.savePayment(paymentDoc);
    }

    notifyListeners();
    return sessionResult;
  }

  /// Verifies transaction status directly against the payment gateway API.
  /// If verified as `paid`, atomically updates the database and credits the driver.
  Future<GatewayPaymentResult> verifyAndSettlePayment({
    required String sessionId,
    required String tripId,
    required String passengerId,
    required String driverId,
    required double fare,
    required double commission,
    required double net,
    required String method,
  }) async {
    // 1. Verify status directly with the gateway API
    final verification = await gateway.verifyPaymentStatus(sessionId);

    // 2. CRITICAL RULE: ONLY credit driver if gateway explicitly confirms status as PAID
    if (verification.isPaid) {
      final ref = verification.referenceNumber.isNotEmpty
          ? verification.referenceNumber
          : 'ST-${method.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}';

      // Atomic commit in Firestore: updates payment, ride status, driver earnings, and driver counters
      if (SupabaseService.isConfigured) {
        final settled = await SupabaseService.instance.atomicSettleRidePayment(
          paymentId: 'pay_$tripId',
          rideId: tripId,
          driverId: driverId,
          passengerId: passengerId,
          fare: fare,
          commission: commission,
          net: net,
          method: method,
          reference: ref,
          gatewayPaymentId: verification.paymentId ?? sessionId,
        );
        if (!settled) {
          throw StateError(
              'Payment was verified, but trusted settlement is still pending.');
        }
      }

      final idempotencyKey = '${tripId}_$passengerId';
      _inFlightSessions[idempotencyKey] = verification;
      notifyListeners();
      return verification;
    }

    return verification;
  }

  /// Real-time poller that repeatedly verifies status with exponential backoff
  /// while passenger completes GCash / Maya payment in browser / webview.
  Stream<GatewayPaymentResult> pollPaymentVerification({
    required String sessionId,
    required String tripId,
    required String passengerId,
    required String driverId,
    required double fare,
    required double commission,
    required double net,
    required String method,
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    final startTime = DateTime.now();
    var pollInterval = const Duration(seconds: 3);

    while (DateTime.now().difference(startTime) < timeout) {
      final result = await verifyAndSettlePayment(
        sessionId: sessionId,
        tripId: tripId,
        passengerId: passengerId,
        driverId: driverId,
        fare: fare,
        commission: commission,
        net: net,
        method: method,
      );

      yield result;

      if (result.isPaid || result.isFailed) {
        return;
      }

      await Future.delayed(pollInterval);
    }

    // Timed out: return final check
    yield await gateway.verifyPaymentStatus(sessionId);
  }

  /// Recovers any pending payment for a ride (e.g. after app restart)
  Future<GatewayPaymentResult?> recoverPendingRidePayment({
    required String tripId,
    required String passengerId,
    required String driverId,
    required double fare,
    required double commission,
    required double net,
    required String method,
  }) async {
    if (!SupabaseService.isConfigured) return null;

    final doc = await SupabaseService.instance.getPaymentForRide(tripId);
    if (doc != null &&
        doc.status == 'pending_payment' &&
        doc.sessionId != null) {
      return verifyAndSettlePayment(
        sessionId: doc.sessionId!,
        tripId: tripId,
        passengerId: passengerId,
        driverId: driverId,
        fare: fare,
        commission: commission,
        net: net,
        method: method,
      );
    }
    return null;
  }

  /// Initiates a verified refund for an online payment transaction.
  Future<GatewayPaymentResult> refundTripPayment({
    required String paymentId,
    required String tripId,
    required String driverId,
    required double amount,
    String? reason,
  }) async {
    final result = await gateway.refundPayment(
      paymentId: paymentId,
      amount: amount,
      reason: reason,
    );

    // Update Firestore payment record
    if (SupabaseService.isConfigured) {
      try {
        final payment = await SupabaseService.instance.getPayment(paymentId);
        if (payment != null) {
          await SupabaseService.instance.savePayment(
            payment.copyWith(status: 'refunded'),
          );
        }
      } catch (e) {
        debugPrint('PaymentService refund Firestore error: $e');
      }
    }

    // Log refund transaction locally
    if (driverId.isNotEmpty) {
      final tx = WalletTransaction(
        id: 'tx_ref_${DateTime.now().millisecondsSinceEpoch}',
        driverId: driverId,
        tripId: tripId,
        type: 'refund',
        method: result.paymentMethodType,
        amount: amount,
        description:
            'Refund processed: ${reason ?? "Trip cancelled"} (Ref: ${result.referenceNumber})',
        createdAt: DateTime.now(),
      );
      final database = await DatabaseService.instance.database;
      await database.insert('transactions', tx.toMap());
    }

    notifyListeners();
    return result;
  }

  /// Cancels an in-flight online payment checkout session.
  Future<GatewayPaymentResult> cancelTripPayment(String sessionId) async {
    final result = await gateway.cancelPaymentSession(sessionId);
    notifyListeners();
    return result;
  }

  /// Wallet authorization must be completed at the payment provider.
  Future<({bool success, String sessionId, String otpCode, String message})>
      requestGcashLinking(
              {required String mobileNumber,
              required String accountName}) async =>
          (
            success: false,
            sessionId: '',
            otpCode: '',
            message:
                'Wallet linking is unavailable. Use provider checkout when paying for a ride.'
          );

  Future<({bool success, String sessionId, String otpCode, String message})>
      requestMayaLinking(
              {required String mobileNumber,
              required String accountName}) async =>
          (
            success: false,
            sessionId: '',
            otpCode: '',
            message:
                'Wallet linking is unavailable. Use provider checkout when paying for a ride.'
          );

  Future<PassengerPaymentMethod?> confirmGcashLinking({
    required String userId,
    required String mobileNumber,
    required String accountName,
    required String enteredOtp,
    required String expectedOtp,
  }) async =>
      throw StateError(
          'Wallet authorization must be verified by the provider.');

  Future<PassengerPaymentMethod?> confirmMayaLinking({
    required String userId,
    required String mobileNumber,
    required String accountName,
    required String enteredOtp,
    required String expectedOtp,
  }) async =>
      throw StateError(
          'Wallet authorization must be verified by the provider.');

  Future<PassengerPaymentMethod?> addCreditCard({
    required String userId,
    required String cardNumber,
    required String holderName,
    required String expiry,
    required String cvv,
  }) async =>
      throw StateError('Add your card through secure provider checkout.');

  /// Executes an end-to-end payment transaction session (backward compatible wrapper)
  Future<PaymentTransactionSession> executePaymentSession({
    required String userId,
    required String tripId,
    required double amount,
    required String paymentMethodType,
    String? payeeId,
  }) async {
    final now = DateTime.now();
    final result = await initiateOnlinePaymentSession(
      tripId: tripId,
      passengerId: userId,
      amount: amount,
      paymentMethodType: paymentMethodType,
      driverId: payeeId,
    );

    return PaymentTransactionSession(
      sessionId: result.sessionId,
      provider: paymentMethodType,
      amount: amount,
      currency: 'PHP',
      tripId: tripId,
      payerId: userId,
      status: result.status == 'paid' ? 'success' : 'processing',
      referenceNumber: result.referenceNumber,
      createdAt: now,
      completedAt: result.isPaid ? DateTime.now() : null,
    );
  }
}
