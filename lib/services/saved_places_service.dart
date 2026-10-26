import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';
import 'supabase_database_service.dart';
import 'supabase_service.dart';

class SavedPlacesService extends ChangeNotifier {
  SavedPlacesService._();
  static final SavedPlacesService instance = SavedPlacesService._();

  static const String _kSavedPlacesKey = 'passenger_saved_places_v2';

  List<SavedPlace> _places = [];
  List<SavedPlace> get places => List.unmodifiable(_places);

  String get summary {
    if (_places.isEmpty) return 'No saved places yet';
    if (_places.length == 1) {
      final p = _places.first;
      return '${p.name} · ${p.address}';
    }
    final names = _places.map((p) => p.name).take(3).join(', ');
    return '$names (${_places.length} saved places)';
  }

  Future<void> init(String? userId) async {
    await _loadFromStorage(userId);
    if (userId != null && userId.isNotEmpty && SupabaseDatabaseService.isConfigured) {
      await _syncWithRemote(userId);
    }
  }

  Future<void> _syncWithRemote(String userId) async {
    try {
      final remotePlaces =
          await SupabaseDatabaseService.instance.getSavedPlaces(userId);
      if (remotePlaces.isNotEmpty) {
        _places = remotePlaces;
        await _saveToStorageOnly(userId);
      } else if (_places.isNotEmpty) {
        // Upload any existing local places to Supabase
        for (final place in _places) {
          await SupabaseDatabaseService.instance.saveSavedPlace(place);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('SavedPlacesService: remote sync error: $e');
    }
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
        if (_places.length != stored.length) await _saveToStorageOnly(userId);
      }
    } catch (e) {
      debugPrint('SavedPlacesService: load error $e');
    }
    notifyListeners();
  }

  Future<void> _saveToStorageOnly(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          userId != null ? '${_kSavedPlacesKey}_$userId' : _kSavedPlacesKey;
      final raw = jsonEncode(_places.map((p) => p.toMap()).toList());
      await prefs.setString(key, raw);

      // Also mirror formatted addresses to passenger profile if available
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
    _places.insert(0, place);
    await _saveToStorageOnly(userId);

    if (userId.isNotEmpty && SupabaseDatabaseService.isConfigured) {
      try {
        await SupabaseDatabaseService.instance.saveSavedPlace(place);
      } catch (e) {
        debugPrint('SavedPlacesService: remote add error: $e');
      }
    }
  }

  Future<void> updatePlace(String userId, SavedPlace place) async {
    final idx = _places.indexWhere((p) => p.id == place.id);
    if (idx != -1) {
      _places[idx] = place;
    } else {
      _places.insert(0, place);
    }
    await _saveToStorageOnly(userId);

    if (userId.isNotEmpty && SupabaseDatabaseService.isConfigured) {
      try {
        await SupabaseDatabaseService.instance.saveSavedPlace(place);
      } catch (e) {
        debugPrint('SavedPlacesService: remote update error: $e');
      }
    }
  }

  Future<void> deletePlace(String userId, String placeId) async {
    _places.removeWhere((p) => p.id == placeId);
    await _saveToStorageOnly(userId);

    if (userId.isNotEmpty && SupabaseDatabaseService.isConfigured) {
      try {
        await SupabaseDatabaseService.instance.deleteSavedPlace(userId, placeId);
      } catch (e) {
        debugPrint('SavedPlacesService: remote delete error: $e');
      }
    }
  }
}
