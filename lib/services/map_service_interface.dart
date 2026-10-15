import '../core/constants.dart';

/// Details of a computed road route.
class RouteDetails {
  const RouteDetails({
    required this.distanceKm,
    required this.durationMins,
    required this.polylinePoints,
    this.source = 'OSRM',
  });

  final double distanceKm;
  final int durationMins;
  final List<Geo> polylinePoints;
  final String source;
}

/// Abstract interface for geocoding services (e.g. Nominatim, Photon, Pelias).
abstract class IMapGeocodingService {
  /// Autocompletes and searches for places matching [query], optionally
  /// biased towards [near] coordinates and [provinceHint] administrative area.
  Future<List<Place>> autocomplete(
    String query, {
    Geo? near,
    String? provinceHint,
  });

  /// Fetches detailed information for a place by its unique ID.
  Future<Place?> fetchPlaceDetails(String placeId);

  /// Reverse geocodes [location] to a human-readable street/barangay address.
  Future<String?> reverseGeocode(Geo location);
}

/// Abstract interface for road routing services (e.g. OSRM, GraphHopper, Valhalla).
abstract class IMapRoutingService {
  /// Calculates a driving/riding route between [origin] and [destination].
  Future<RouteDetails?> computeRoute({
    required Geo origin,
    required Geo destination,
  });
}
