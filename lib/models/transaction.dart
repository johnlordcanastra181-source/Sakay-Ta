class WalletTransaction {
  final String id;
  final String driverId;
  final String? tripId;
  final String type;
  final String method;
  final double amount;
  final String description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.driverId,
    this.tripId,
    required this.type,
    required this.method,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';

  Map<String, Object?> toMap() => {
        'id': id,
        'driver_id': driverId,
        'trip_id': tripId,
        'type': type,
        'method': method,
        'amount': amount,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WalletTransaction.fromMap(Map<String, Object?> map) =>
      WalletTransaction(
        id: map['id'] as String,
        driverId: map['driver_id'] as String,
        tripId: map['trip_id'] as String?,
        type: (map['type'] as String?) ?? 'income',
        method: (map['method'] as String?) ?? 'cash',
        amount: (map['amount'] as num).toDouble(),
        description: (map['description'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}

class ChatMessage {
  final String id;
  final String tripId;
  final String senderId;
  final String senderName;
  final bool isDriver;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.senderName,
    required this.isDriver,
    required this.text,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'sender_id': senderId,
        'sender_name': senderName,
        'is_driver': isDriver ? 1 : 0,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        senderId: map['sender_id'] as String,
        senderName: (map['sender_name'] as String?) ?? '',
        isDriver: (map['is_driver'] as int? ?? 0) == 1,
        text: (map['text'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}

class Review {
  final String id;
  final String tripId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'driver_id': driverId,
        'passenger_id': passengerId,
        'passenger_name': passengerName,
        'rating': rating,
        'comment': comment,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Review.fromMap(Map<String, Object?> map) => Review(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        driverId: map['driver_id'] as String,
        passengerId: map['passenger_id'] as String,
        passengerName: (map['passenger_name'] as String?) ?? '',
        rating: (map['rating'] as int?) ?? 0,
        comment: (map['comment'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    bool read = false,
    bool? isRead,
    required this.createdAt,
  }) : read = isRead ?? read;

  bool get isRead => read;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'read': read ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AppNotification.fromMap(Map<String, Object?> map) => AppNotification(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        read: (map['read'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int?) ?? 0,
        ),
      );
}

class PaymentCard {
  final String id;
  final String userId;
  final String holder;
  final String number;
  final String expiry;
  final String cvv;
  final String brand;

  const PaymentCard({
    required this.id,
    required this.userId,
    required this.holder,
    required this.number,
    required this.expiry,
    required this.cvv,
    this.brand = 'Visa',
  });

  String get masked => '•••• ${number.substring(number.length - 4)}';

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'holder': holder,
        'number': number,
        'expiry': expiry,
        'cvv': cvv,
        'brand': brand,
      };

  factory PaymentCard.fromMap(Map<String, Object?> map) => PaymentCard(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        holder: (map['holder'] as String?) ?? '',
        number: (map['number'] as String?) ?? '',
        expiry: (map['expiry'] as String?) ?? '',
        cvv: (map['cvv'] as String?) ?? '',
        brand: (map['brand'] as String?) ?? 'Visa',
      );
}
