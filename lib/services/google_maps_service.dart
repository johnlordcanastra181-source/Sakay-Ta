import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'map_service_interface.dart';

export 'map_service_interface.dart'
    show RouteDetails, IMapGeocodingService, IMapRoutingService;

/// Optional Google Maps provider implementing [IMapGeocodingService] and [IMapRoutingService].
/// Note: Default and recommended provider for Sakay Ta is [OsmMapService].
class GoogleMapsService implements IMapGeocodingService, IMapRoutingService {
  GoogleMapsService._();

  static final GoogleMapsService instance = GoogleMapsService._();

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _webApiKey =
      String.fromEnvironment('WEB_GOOGLE_MAPS_API_KEY');
  static const String _mapsHost = 'maps.googleapis.com';
  static const String _placesHost = 'places.googleapis.com';
  static const Duration _timeout = Duration(seconds: 12);

  String get apiKey {
    final preferred = _apiKey.trim();
    if (preferred.isNotEmpty && preferred != 'YOUR_GOOGLE_MAPS_API_KEY') {
      return preferred;
    }
    final webFallback = _webApiKey.trim();
    if (webFallback.isNotEmpty && webFallback != 'YOUR_GOOGLE_MAPS_API_KEY') {
      return webFallback;
    }
    return '';
  }

  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<List<Place>> autocomplete(
    String query, {
    Geo? near,
    // provinceHint is handled server-side via includedRegionCodes for Google
    // Maps; the parameter is accepted here to satisfy the interface contract.
    String? provinceHint,
  }) async {
    if (!isConfigured || query.trim().isEmpty) return const [];

    final payload = <String, dynamic>{
      'input': query,
      'includedRegionCodes': ['ph'],
    };

    if (near != null) {
      payload['locationBias'] = {
        'circle': {
          'center': {
            'latitude': near.lat,
            'longitude': near.lng,
          },
          'radius': 50000.0,
        },
      };
    }

    final response = await http
        .post(
          Uri.https(_placesHost, '/v1/places:autocomplete'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Places autocomplete failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = (data['suggestions'] as List?) ?? const [];
    final places = <Place>[];

    for (final item in suggestions) {
      final suggestion = item as Map<String, dynamic>;
      final prediction = suggestion['placePrediction'];
      if (prediction is! Map<String, dynamic>) continue;
      final placeId = (prediction['placeId'] ?? '').toString();
      if (placeId.isEmpty) continue;

      final text = _nestedString(prediction, ['text', 'text']);
      final secondary = _nestedString(
        prediction,
        ['structuredFormat', 'secondaryText', 'text'],
      );

      places.add(
        Place(
          text.isEmpty ? 'Selected destination' : text,
          near ?? const Geo(0, 0),
          secondary.isEmpty ? 'Philippines' : secondary,
          placeId,
        ),
      );
    }

    return places;
  }

  @override
  Future<Place?> fetchPlaceDetails(String placeId) async {
    if (!isConfigured || placeId.trim().isEmpty) return null;

    final response = await http.get(
      Uri.https(_placesHost, '/v1/places/$placeId'),
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
      },
    ).timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Place details failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return null;

    final displayName = _nestedString(data, ['displayName', 'text']);
    final address = (data['formattedAddress'] ?? '').toString();

    return Place(
      displayName.isEmpty ? address : displayName,
      Geo(lat, lng),
      address.isEmpty ? 'Philippines' : address,
      placeId,
    );
  }

  @override
  Future<RouteDetails?> computeRoute({
    required Geo origin,
    required Geo destination,
  }) async {
    if (!isConfigured) return null;

    final response = await http
        .post(
          Uri.https(_mapsHost, '/directions/v2:computeRoutes'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
          },
          body: jsonEncode({
            'origin': {
              'location': {
                'latLng': {
                  'latitude': origin.lat,
                  'longitude': origin.lng,
                },
              },
            },
            'destination': {
              'location': {
                'latLng': {
                  'latitude': destination.lat,
                  'longitude': destination.lng,
                },
              },
            },
            'travelMode': 'DRIVE',
            'routingPreference': 'TRAFFIC_UNAWARE',
            'polylineQuality': 'OVERVIEW',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Route lookup failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? const [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final distanceMeters = (route['distanceMeters'] as num?)?.toDouble() ?? 0;
    final durationSeconds = _parseDurationSeconds(route['duration']);
    final encodedPolyline =
        _nestedString(route, ['polyline', 'encodedPolyline']);

    return RouteDetails(
      distanceKm: distanceMeters / 1000,
      durationMins: math.max(1, (durationSeconds / 60).round()),
      polylinePoints: encodedPolyline.isEmpty
          ? [origin, destination]
          : _decodePolyline(encodedPolyline),
    );
  }

  @override
  Future<String?> reverseGeocode(Geo location) async {
    if (!isConfigured) return null;

    final response = await http
        .get(
          Uri.https(_mapsHost, '/maps/api/geocode/json', {
            'latlng': '${location.lat},${location.lng}',
            'key': apiKey,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Reverse geocoding failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final formatted = (first['formatted_address'] ?? '').toString();
    return formatted.isEmpty ? null : formatted;
  }

  int _parseDurationSeconds(dynamic rawDuration) {
    final value = (rawDuration ?? '').toString().trim();
    if (!value.endsWith('s')) return 0;
    return (double.tryParse(value.substring(0, value.length - 1)) ?? 0).round();
  }

  String _nestedString(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else {
        return '';
      }
    }
    return (current ?? '').toString();
  }

  List<Geo> _decodePolyline(String encoded) {
    final points = <Geo>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(Geo(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
