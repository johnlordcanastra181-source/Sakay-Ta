import 'package:flutter/material.dart';
import '../core/constants.dart';

class SavedPlace {
  final String id;
  final String userId;
  final String name; // Home, Work, School, Market, Custom
  final String address;
  final Geo geo;
  final String category; // home, work, school, market, gym, custom
  final DateTime createdAt;

  const SavedPlace({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.geo,
    this.category = 'custom',
    required this.createdAt,
  });

  IconData get icon => switch (category.toLowerCase()) {
        'home' => Icons.home_rounded,
        'work' => Icons.work_rounded,
        'school' => Icons.school_rounded,
        'market' => Icons.shopping_basket_rounded,
        'gym' => Icons.fitness_center_rounded,
        _ => Icons.location_on_rounded,
      };

  Color get iconColor => switch (category.toLowerCase()) {
        'home' => const Color(0xFF059669),
        'work' => const Color(0xFF3B82F6),
        'school' => const Color(0xFFD97706),
        'market' => const Color(0xFF8B5CF6),
        'gym' => const Color(0xFFEC4899),
        _ => const Color(0xFF6E5600),
      };

  SavedPlace copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    Geo? geo,
    String? category,
    DateTime? createdAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      geo: geo ?? this.geo,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'address': address,
        'lat': geo.lat,
        'lng': geo.lng,
        'category': category,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory SavedPlace.fromMap(Map<String, Object?> map) => SavedPlace(
        id: map['id'] as String,
        userId: (map['user_id'] ?? map['userId'] ?? '') as String,
        name: (map['name'] as String?) ?? 'Saved Place',
        address: (map['address'] as String?) ?? '',
        geo: Geo(
          (map['lat'] as num?)?.toDouble() ?? 10.3157,
          (map['lng'] as num?)?.toDouble() ?? 123.8854,
        ),
        category: (map['category'] as String?) ?? 'custom',
        createdAt: () {
          final val = map['created_at'] ?? map['createdAt'];
          if (val is int) {
            return DateTime.fromMillisecondsSinceEpoch(val);
          }
          if (val is num) {
            return DateTime.fromMillisecondsSinceEpoch(val.toInt());
          }
          return DateTime.now();
        }(),
      );
}
