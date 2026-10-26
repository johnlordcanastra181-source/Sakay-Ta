import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'database_service.dart';
import 'map_service_interface.dart';

export 'map_service_interface.dart'
    show RouteDetails, IMapGeocodingService, IMapRoutingService;

/// Production OpenStreetMap service providing Nominatim Geocoding and OSRM Road Routing
/// with persistent caching of real provider responses.
class OsmMapService implements IMapGeocodingService, IMapRoutingService {
  OsmMapService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  static final OsmMapService instance = OsmMapService();
  final http.Client _client;

  // 5-second timeout: rural 2G/3G round-trips to OSM/OSRM servers abroad
  // regularly exceed 3s. Cached results are always tried first.
  static const Duration _timeout = Duration(milliseconds: 5000);
  static const String _nominatimHost = 'nominatim.openstreetmap.org';
  static const String _osrmHost = 'router.project-osrm.org';
  static const String _userAgent =
      'SakayTa-PassengerApp/1.1 (philippines-transportation)';

  // In-memory fast cache
  final Map<String, List<Place>> _autocompleteCache = {};
  final Map<String, String> _reverseGeocodeCache = {};
  final Map<String, RouteDetails> _routeCache = {};

  @override
  Future<List<Place>> autocomplete(
    String query, {
    Geo? near,

    /// When set, Nominatim results are biased toward this province name.
    /// This is advisory only — post-selection validation is the hard enforcement.
    String? provinceHint,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Build province-biased query: append province name to the search string
    // so Nominatim prioritises in-province results first.
    final biasedQuery = (provinceHint != null && provinceHint.isNotEmpty)
        ? '$trimmed, $provinceHint, Philippines'
        : trimmed;

    final cacheKey =
        'ac_${biasedQuery.toLowerCase()}_${near?.lat.toStringAsFixed(3)}_${near?.lng.toStringAsFixed(3)}';

    // 1. Check in-memory cache
    if (_autocompleteCache.containsKey(cacheKey)) {
      return _autocompleteCache[cacheKey]!;
    }

    // 2. Check persistent SQLite cache
    try {
      final cachedJson = await DatabaseService.instance.getMapCache(cacheKey);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as List;
        final cachedList = decoded
            .map((item) => Place(
                  item['name'] as String,
                  Geo(
                    (item['lat'] as num).toDouble(),
                    (item['lng'] as num).toDouble(),
                  ),
                  item['address'] as String,
                  item['placeId'] as String?,
                  item['province'] as String? ?? '',
                ))
            .toList();
        _autocompleteCache[cacheKey] = cachedList;
        return cachedList;
      }
    } catch (e) {
      debugPrint('OsmMapService non-fatal note: $e');
    }

    // 3. Query network with fast timeout
    try {
      final queryParams = <String, String>{
        'q': biasedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '7',
        'countrycodes': 'ph',
      };

      if (near != null && near.lat != 0 && near.lng != 0) {
        queryParams['viewbox'] = _viewbox(near);
        queryParams['bounded'] = '0';
      }

      final uri = Uri.https(_nominatimHost, '/search', queryParams);
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
          'Accept-Language': 'en,fil,ceb',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <Place>[];
      }

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return <Place>[];

      final results = data
          .map<Place?>((item) {
            if (item is! Map<String, dynamic>) return null;
            final lat = double.tryParse((item['lat'] ?? '').toString());
            final lng = double.tryParse((item['lon'] ?? '').toString());
            if (lat == null || lng == null) return null;

            final displayName = (item['display_name'] ?? '').toString();
            final address = item['address'] as Map<String, dynamic>? ?? {};

            final primaryName = (item['name'] ?? '').toString().isNotEmpty
                ? item['name'].toString()
                : (address['amenity'] ??
                        address['building'] ??
                        address['shop'] ??
                        address['road'] ??
                        address['village'] ??
                        address['suburb'] ??
                        address['neighbourhood'] ??
                        displayName.split(',').first)
                    .toString();

            final subtitleParts = <String>[];
            if (address['quarter'] != null ||
                address['neighbourhood'] != null ||
                address['suburb'] != null ||
                address['village'] != null) {
              final sub = (address['quarter'] ??
                      address['neighbourhood'] ??
                      address['suburb'] ??
                      address['village'])
                  .toString();
              if (sub != primaryName) subtitleParts.add(sub);
            }
            if (address['city'] != null ||
                address['municipality'] != null ||
                address['town'] != null) {
              subtitleParts.add((address['city'] ??
                      address['municipality'] ??
                      address['town'])
                  .toString());
            }
            if (address['province'] != null || address['state'] != null) {
              subtitleParts
                  .add((address['province'] ?? address['state']).toString());
            }

            final subtitle = subtitleParts.isNotEmpty
                ? subtitleParts.take(3).join(', ')
                : displayName.split(',').skip(1).take(2).join(', ').trim();

            final placeId = (item['place_id'] ?? '').toString();

            return Place(
              primaryName.trim().isNotEmpty
                  ? primaryName.trim()
                  : 'Selected Location',
              Geo(lat, lng),
              subtitle.isNotEmpty ? subtitle : 'Philippines',
              placeId.isNotEmpty ? placeId : null,
              (address['province'] ?? address['state'] ?? '').toString().trim(),
            );
          })
          .whereType<Place>()
          .toList();

      if (provinceHint != null && provinceHint.isNotEmpty) {
        results.retainWhere((p) {
          if (p.province.isEmpty) {
            // If Nominatim didn't return a province component, try checking the full display name
            return p.address
                    .toLowerCase()
                    .contains(provinceHint.toLowerCase()) ||
                p.name.toLowerCase().contains(provinceHint.toLowerCase());
          }
          return p.province.toLowerCase() == provinceHint.toLowerCase();
        });
      }

      if (results.isEmpty) {
        return <Place>[];
      }

      _autocompleteCache[cacheKey] = results;

      // Save to SQLite cache asynchronously
      final jsonToStore = jsonEncode(results
          .map((p) => {
                'name': p.name,
                'lat': p.geo.lat,
                'lng': p.geo.lng,
                'address': p.address,
                'placeId': p.placeId,
                'province': p.province,
              })
          .toList());
      unawaited(DatabaseService.instance.saveMapCache(
        cacheKey,
        'autocomplete',
        jsonToStore,
      ));

      return results;
    } catch (e) {
      debugPrint('OsmMapService: autocomplete offline fallback ($e)');
      return <Place>[];
    }
  }

  @override
  Future<Place?> fetchPlaceDetails(String placeId) async {
    final trimmed = placeId.trim();
    if (trimmed.isEmpty) return null;

    final cacheKey = 'pd_$trimmed';
    try {
      final cachedJson = await DatabaseService.instance.getMapCache(cacheKey);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        return Place(
          decoded['name'] as String,
          Geo((decoded['lat'] as num).toDouble(),
              (decoded['lng'] as num).toDouble()),
          decoded['address'] as String,
          decoded['placeId'] as String?,
        );
      }
    } catch (e) {
      debugPrint('OsmMapService non-fatal note: $e');
    }

    try {
      final response = await _client.get(
        Uri.https(_nominatimHost, '/lookup', {
          'format': 'jsonv2',
          'addressdetails': '1',
          'place_ids': trimmed,
        }),
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
          'Accept-Language': 'en,fil,ceb',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) return null;
      final map = data.first as Map<String, dynamic>;
      final lat = double.tryParse((map['lat'] ?? '').toString());
      final lng = double.tryParse((map['lon'] ?? '').toString());
      if (lat == null || lng == null) return null;

      final displayName = (map['display_name'] ?? '').toString();
      final name = (map['name'] ?? '').toString();
      final parts = displayName
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final place = Place(
        name.isNotEmpty
            ? name
            : (parts.isNotEmpty ? parts.first : 'Selected Location'),
        Geo(lat, lng),
        parts.length > 1 ? parts.skip(1).take(3).join(', ') : displayName,
        (map['place_id'] ?? '').toString(),
      );

      final jsonToStore = jsonEncode({
        'name': place.name,
        'lat': place.geo.lat,
        'lng': place.geo.lng,
        'address': place.address,
        'placeId': place.placeId,
      });
      unawaited(DatabaseService.instance
          .saveMapCache(cacheKey, 'details', jsonToStore));

      return place;
    } catch (e) {
      debugPrint('OsmMapService: fetchPlaceDetails offline fallback ($e)');
      return null;
    }
  }

  @override
  Future<String?> reverseGeocode(Geo location) async {
    final cacheKey =
        'rg_${location.lat.toStringAsFixed(4)},${location.lng.toStringAsFixed(4)}';
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      return _reverseGeocodeCache[cacheKey]!;
    }

    try {
      final cached = await DatabaseService.instance.getMapCache(cacheKey);
      if (cached != null) {
        _reverseGeocodeCache[cacheKey] = cached;
        return cached;
      }
    } catch (e) {
      debugPrint('OsmMapService non-fatal note: $e');
    }

    try {
      final response = await _client.get(
        Uri.https(_nominatimHost, '/reverse', {
          'lat': '${location.lat}',
          'lon': '${location.lng}',
          'format': 'jsonv2',
          'zoom': '18',
          'addressdetails': '1',
        }),
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
          'Accept-Language': 'en,fil,ceb',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackReverseAddress(location);
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address != null) {
        final road =
            address['road'] ?? address['pedestrian'] ?? address['footway'];
        final barangay = address['quarter'] ??
            address['neighbourhood'] ??
            address['suburb'] ??
            address['village'];
        final city =
            address['city'] ?? address['municipality'] ?? address['town'];
        final province = address['province'] ?? address['state'];

        final parts = <String>[];
        if (road != null) parts.add(road.toString());
        if (barangay != null) parts.add('Brgy. $barangay');
        if (city != null) parts.add(city.toString());
        if (province != null && province != city) {
          parts.add(province.toString());
        }

        if (parts.isNotEmpty) {
          final formatted = parts.join(', ');
          _reverseGeocodeCache[cacheKey] = formatted;
          unawaited(DatabaseService.instance
              .saveMapCache(cacheKey, 'reverse', formatted));
          return formatted;
        }
      }

      final displayName = (data['display_name'] ?? '').toString().trim();
      if (displayName.isNotEmpty) {
        final formatted =
            displayName.split(',').take(4).map((p) => p.trim()).join(', ');
        _reverseGeocodeCache[cacheKey] = formatted;
        unawaited(DatabaseService.instance
            .saveMapCache(cacheKey, 'reverse', formatted));
        return formatted;
      }
      return _fallbackReverseAddress(location);
    } catch (e) {
      debugPrint('OsmMapService: reverseGeocode offline fallback ($e)');
      return _fallbackReverseAddress(location);
    }
  }

  /// Reverse-geocodes [location] and returns a record containing both the
  /// human-readable [address] string and the structured [province] extracted
  /// from Nominatim's `address.province` / `address.state` field.
  ///
  /// Returns `(address: null, province: null)` on network failure.
  Future<({String? address, String? province})> reverseGeocodeStructured(
      Geo location) async {
    try {
      final response = await _client.get(
        Uri.https(_nominatimHost, '/reverse', {
          'lat': '${location.lat}',
          'lon': '${location.lng}',
          'format': 'jsonv2',
          'zoom': '18',
          'addressdetails': '1',
        }),
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
          'Accept-Language': 'en,fil,ceb',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (address: null, province: null);
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final addrMap = data['address'] as Map<String, dynamic>? ?? {};

      // Province detection: prefer `province`, fall back to `state`.
      // In the Philippines, Nominatim uses `province` for most regions
      // (e.g. "Bohol", "Cebu") and `state` for special regions (NCR, BARMM).
      final rawProvince =
          (addrMap['province'] ?? addrMap['state'] ?? '').toString().trim();
      final province = rawProvince.isEmpty ? null : rawProvince;

      // Build a readable address string (same logic as reverseGeocode).
      final road =
          addrMap['road'] ?? addrMap['pedestrian'] ?? addrMap['footway'];
      final barangay = addrMap['quarter'] ??
          addrMap['neighbourhood'] ??
          addrMap['suburb'] ??
          addrMap['village'];
      final city =
          addrMap['city'] ?? addrMap['municipality'] ?? addrMap['town'];

      final parts = <String>[];
      if (road != null) parts.add(road.toString());
      if (barangay != null) parts.add('Brgy. $barangay');
      if (city != null) parts.add(city.toString());
      if (province != null && province != city.toString()) {
        parts.add(province);
      }

      final address = parts.isNotEmpty ? parts.join(', ') : null;
      return (address: address, province: province);
    } catch (e) {
      debugPrint('OsmMapService: reverseGeocodeStructured error ($e)');
      return (address: null, province: null);
    }
  }

  @override
  Future<RouteDetails?> computeRoute({
    required Geo origin,
    required Geo destination,
  }) async {
    final cacheKey =
        'rt_${origin.lat.toStringAsFixed(4)},${origin.lng.toStringAsFixed(4)}->${destination.lat.toStringAsFixed(4)},${destination.lng.toStringAsFixed(4)}';

    if (_routeCache.containsKey(cacheKey)) {
      return _routeCache[cacheKey]!;
    }

    try {
      final cached = await DatabaseService.instance.getMapCache(cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final points = (data['points'] as List)
            .map((p) =>
                Geo((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList();
        final details = RouteDetails(
          distanceKm: (data['distanceKm'] as num).toDouble(),
          durationMins: (data['durationMins'] as num).toInt(),
          polylinePoints: points,
          source: 'Offline Cache',
        );
        _routeCache[cacheKey] = details;
        return details;
      }
    } catch (e) {
      debugPrint('OsmMapService non-fatal note: $e');
    }

    try {
      final coordinates =
          '${origin.lng},${origin.lat};${destination.lng},${destination.lat}';
      final response = await _client.get(
        Uri.https(_osrmHost, '/route/v1/driving/$coordinates', {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        }),
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? const [];
      if (routes.isEmpty) {
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinatesList = (geometry?['coordinates'] as List?) ?? const [];

      final points = coordinatesList
          .map((item) {
            final pair = item as List;
            if (pair.length < 2) return null;
            final lng = (pair[0] as num?)?.toDouble();
            final lat = (pair[1] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return Geo(lat, lng);
          })
          .whereType<Geo>()
          .toList();

      final routeDetails = RouteDetails(
        distanceKm: distanceMeters / 1000,
        durationMins: math.max(1, (durationSeconds / 60).round()),
        polylinePoints: points,
        source: 'OSRM Open Routing',
      );

      _routeCache[cacheKey] = routeDetails;

      final jsonToStore = jsonEncode({
        'distanceKm': routeDetails.distanceKm,
        'durationMins': routeDetails.durationMins,
        'points': routeDetails.polylinePoints
            .map((p) => {'lat': p.lat, 'lng': p.lng})
            .toList(),
      });
      unawaited(DatabaseService.instance
          .saveMapCache(cacheKey, 'route', jsonToStore));

      return routeDetails;
    } catch (e) {
      debugPrint('OsmMapService: computeRoute offline fallback ($e)');
      return null;
    }
  }

  String _fallbackReverseAddress(Geo location) {
    return 'Location (${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)})';
  }

  String _viewbox(Geo near) {
    const delta = 0.25;
    final left = near.lng - delta;
    final top = near.lat + delta;
    final right = near.lng + delta;
    final bottom = near.lat - delta;
    return '$left,$top,$right,$bottom';
  }
}
