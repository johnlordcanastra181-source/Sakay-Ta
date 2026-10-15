import '../core/constants.dart';

class PassengerPaymentMethod {
  final String id;
  final String type; // gcash, maya, card, cash
  final String title;
  final String accountIdentifier; // e.g. "+63 917 •••• 888" or "•••• 4242"
  final String accountName;
  final bool isDefault;
  final String status; // active, verified, pending, disconnected
  final DateTime linkedAt;
  final String? brand; // visa, mastercard, jcb, etc.

  const PassengerPaymentMethod({
    required this.id,
    required this.type,
    required this.title,
    required this.accountIdentifier,
    required this.accountName,
    this.isDefault = false,
    this.status = 'active',
    required this.linkedAt,
    this.brand,
  });

  bool get isGcash => type == PaymentMethod.gcash;
  bool get isMaya => type == PaymentMethod.maya;
  bool get isCard => type == PaymentMethod.card;
  bool get isCash => type == PaymentMethod.cash;

  PassengerPaymentMethod copyWith({
    String? id,
    String? type,
    String? title,
    String? accountIdentifier,
    String? accountName,
    bool? isDefault,
    String? status,
    DateTime? linkedAt,
    String? brand,
  }) {
    return PassengerPaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      accountName: accountName ?? this.accountName,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      linkedAt: linkedAt ?? this.linkedAt,
      brand: brand ?? this.brand,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'account_identifier': accountIdentifier,
        'account_name': accountName,
        'is_default': isDefault ? 1 : 0,
        'status': status,
        'linked_at': linkedAt.millisecondsSinceEpoch,
        'brand': brand,
      };

  factory PassengerPaymentMethod.fromMap(Map<String, Object?> map) =>
      PassengerPaymentMethod(
        id: map['id'] as String,
        type: (map['type'] as String?) ?? PaymentMethod.cash,
        title: (map['title'] as String?) ?? 'Payment Method',
        accountIdentifier: (map['account_identifier'] ??
            map['accountIdentifier'] ??
            '') as String,
        accountName:
            (map['account_name'] ?? map['accountName'] ?? '') as String,
        isDefault: map['is_default'] == 1 ||
            map['isDefault'] == true ||
            map['is_default'] == true,
        status: (map['status'] as String?) ?? 'active',
        linkedAt: () {
          final val = map['linked_at'] ?? map['linkedAt'];
          if (val is int) {
            return DateTime.fromMillisecondsSinceEpoch(val);
          }
          if (val is num) {
            return DateTime.fromMillisecondsSinceEpoch(val.toInt());
          }
          return DateTime.now();
        }(),
        brand: map['brand'] as String?,
      );

  static PassengerPaymentMethod defaultCash() => PassengerPaymentMethod(
        id: 'pm_cash_default',
        type: PaymentMethod.cash,
        title: 'Cash on Trip',
        accountIdentifier: 'Pay directly to driver upon drop-off',
        accountName: 'Cash',
        isDefault: true,
        status: 'active',
        linkedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class PaymentTransactionSession {
  final String sessionId;
  final String provider; // gcash, maya, card, cash
  final double amount;
  final String currency;
  final String? tripId;
  final String payerId;
  final String
      status; // pending, authenticating, processing, success, failed, cancelled
  final String referenceNumber;
  final String? checkoutUrl;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const PaymentTransactionSession({
    required this.sessionId,
    required this.provider,
    required this.amount,
    this.currency = 'PHP',
    this.tripId,
    required this.payerId,
    this.status = 'pending',
    required this.referenceNumber,
    this.checkoutUrl,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  PaymentTransactionSession copyWith({
    String? status,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return PaymentTransactionSession(
      sessionId: sessionId,
      provider: provider,
      amount: amount,
      currency: currency,
      tripId: tripId,
      payerId: payerId,
      status: status ?? this.status,
      referenceNumber: referenceNumber,
      checkoutUrl: checkoutUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'session_id': sessionId,
        'provider': provider,
        'amount': amount,
        'currency': currency,
        'trip_id': tripId,
        'payer_id': payerId,
        'status': status,
        'reference_number': referenceNumber,
        'checkout_url': checkoutUrl,
        'error_message': errorMessage,
        'created_at': createdAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
      };

  factory PaymentTransactionSession.fromMap(Map<String, Object?> map) =>
      PaymentTransactionSession(
        sessionId: map['session_id'] as String,
        provider: map['provider'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: (map['currency'] as String?) ?? 'PHP',
        tripId: map['trip_id'] as String?,
        payerId: map['payer_id'] as String,
        status: (map['status'] as String?) ?? 'pending',
        referenceNumber: (map['reference_number'] as String?) ?? '',
        checkoutUrl: map['checkout_url'] as String?,
        errorMessage: map['error_message'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
        completedAt: map['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
            : null,
      );
}
