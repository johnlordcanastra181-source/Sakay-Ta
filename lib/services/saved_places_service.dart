import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';
import 'supabase_service.dart';

class SavedPlacesService extends ChangeNotifier {
  SavedPlacesService._();
  static final SavedPlacesService instance = SavedPlacesService._();

  static const String _kSavedPlacesKey = 'passenger_saved_places_v2';

  List<SavedPlace> _places = [];
  List<SavedPlace> get places => List.unmodifiable(_places);

  String get summary {
    if (_places.isEmpty) return 'No saved places';
    final names = _places.map((p) => p.name).take(3).join(', ');
    return names.isNotEmpty ? names : 'No saved places';
  }

  Future<void> init(String? userId) async {
    await _loadFromStorage(userId);
  }

  Future<void> _loadFromStorage(String? userId) async {
    _places = [];
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_kSavedPlacesKey}_$userId';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final stored = decoded
            .map((item) =>
                SavedPlace.fromMap(Map<String, Object?>.from(item as Map)))
            .toList();
        _places = stored
            .where((p) =>
                p.userId == userId &&
                !(p.id == 'place_home_default' &&
                    p.address == 'Banilad, Cebu City, Cebu') &&
                !(p.id == 'place_work_default' &&
                    p.address == 'Cebu IT Park, Lahug, Cebu City'))
            .toList();
        if (_places.length != stored.length) await _saveToStorage(userId);
      }
    } catch (e) {
      debugPrint('SavedPlacesService: load error $e');
    }
    notifyListeners();
  }

  Future<void> _saveToStorage(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          userId != null ? '${_kSavedPlacesKey}_$userId' : _kSavedPlacesKey;
      final raw = jsonEncode(_places.map((p) => p.toMap()).toList());
      await prefs.setString(key, raw);

      // Also mirror formatted addresses to Firestore passenger profile
      if (userId != null && SupabaseService.isConfigured) {
        final addressStrings =
            _places.map((p) => '${p.name}: ${p.address}').toList();
        await SupabaseService.instance.savePassengerProfile(
          userId,
          savedAddresses: addressStrings,
          defaultAddress: _places.isNotEmpty ? _places.first.address : null,
        );
      }
    } catch (e) {
      debugPrint('SavedPlacesService: save error $e');
    }
    notifyListeners();
  }

  Future<void> addPlace(String userId, SavedPlace place) async {
    _places.removeWhere((p) => p.id == place.id);
    _places.add(place);
    await _saveToStorage(userId);
  }

  Future<void> updatePlace(String userId, SavedPlace place) async {
    final idx = _places.indexWhere((p) => p.id == place.id);
    if (idx != -1) {
      _places[idx] = place;
    } else {
      _places.add(place);
    }
    await _saveToStorage(userId);
  }

  Future<void> deletePlace(String userId, String placeId) async {
    _places.removeWhere((p) => p.id == placeId);
    await _saveToStorage(userId);
  }
}
