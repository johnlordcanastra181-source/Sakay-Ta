import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:geolocator/geolocator.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../core/time_utils.dart';
import '../services/driver_matching_service.dart';
import '../services/osm_map_service.dart';
import '../services/payment_service.dart';
import '../services/weather_service.dart';
import 'app_state.dart';

/// Road-winding factor applied to straight-line distance when the OSRM road
/// router is unreachable (weak/no mobile data). Rural Philippine roads are
/// typically 20-35% longer than the crow-flies distance.
const double kApproximateRoadFactor = 1.25;

/// Builds an approximate route when OSRM cannot be reached so the passenger
/// can still see a fare and book. Returns null for invalid/zero-length trips.
RouteDetails? approximateRoute(Geo origin, Geo destination) {
  if (origin.lat == 0 && origin.lng == 0) return null;
  if (destination.lat == 0 && destination.lng == 0) return null;
  final straight = Geo.distanceKm(origin, destination);
  if (!straight.isFinite || straight <= 0.01) return null;
  final km = double.parse((straight * kApproximateRoadFactor).toStringAsFixed(2));
  // ~25 km/h average tricycle / habal-habal speed on rural roads.
  final mins = (km / 25 * 60).ceil().clamp(1, 240);
  return RouteDetails(
    distanceKm: km,
    durationMins: mins,
    polylinePoints: [origin, destination],
    source: 'Approximate (offline)',
  );
}

// --- EVENTS ---
abstract class PassengerSearchEvent {}

class DismissRecentDestinationEvent extends PassengerSearchEvent {
  final Place destination;
  DismissRecentDestinationEvent(this.destination);
}

class DetectLocationEvent extends PassengerSearchEvent {
  final bool forceRecenter;
  DetectLocationEvent({this.forceRecenter = true});
}

class LocationUpdatedEvent extends PassengerSearchEvent {
  final Geo location;
  LocationUpdatedEvent(this.location);
}

class RefreshWeatherEvent extends PassengerSearchEvent {}

class SearchDestinationEvent extends PassengerSearchEvent {
  final String query;
  SearchDestinationEvent(this.query);
}

class SelectDestinationEvent extends PassengerSearchEvent {
  final Place destination;
  SelectDestinationEvent(this.destination);
}

class UpdatePickupLocationEvent extends PassengerSearchEvent {
  final Geo pickupLocation;
  final String? pickupAddress;
  UpdatePickupLocationEvent(this.pickupLocation, {this.pickupAddress});
}

class ClearDestinationEvent extends PassengerSearchEvent {}

class UpdateSearchRadiusEvent extends PassengerSearchEvent {
  final double radiusKm;
  UpdateSearchRadiusEvent(this.radiusKm);
}

class SelectVehicleTypeEvent extends PassengerSearchEvent {
  final VehicleType vehicleType;
  SelectVehicleTypeEvent(this.vehicleType);
}

class SelectDriverEvent extends PassengerSearchEvent {
  final NearbyDriver driver;
  SelectDriverEvent(this.driver);
}

class AutoMatchDriverEvent extends PassengerSearchEvent {}

class ConfirmBookingEvent extends PassengerSearchEvent {}

class ExportMapEvent extends PassengerSearchEvent {}

class ShareTripEvent extends PassengerSearchEvent {}

// --- STATES ---
class PassengerSearchState {
  final bool isLoadingLocation;
  final bool isLocationPermissionDenied;
  final Geo passengerLocation;
  final String currentAddressLabel;
  final String currentBarangay;
  final String currentMunicipality;
  final String currentProvince;

  final String searchQuery;
  final bool isSearching;
  final List<Place> autocompleteSuggestions;
  final List<Place> recentDestinations;
  final List<Place> popularPlaces;

  final Place? selectedDestination;
  final bool isRouting;
  final double routeDistanceKm;
  final int routeDurationMins;
  final List<Geo> routePoints;
  final double tricycleFare;
  final double habalFare;

  final VehicleType selectedVehicle;
  final double searchRadiusKm;
  final List<NearbyDriver> nearbyDrivers;
  final NearbyDriver? selectedDriver;
  final int availableDriverCount;

  final bool isOffline;
  final bool isExportingMap;
  final String? mapExportImagePath;
  final String? shareTripLink;
  final String? errorMessage;
  final bool isBookingConfirmed;

  // Real-Time Location-Aware Weather
  final bool isLoadingWeather;
  final String weatherCondition;
  final String weatherEmoji;
  final int weatherTempC;
  final DateTime? weatherLastUpdated;

  const PassengerSearchState({
    this.isLoadingLocation = false,
    this.isLocationPermissionDenied = false,
    this.passengerLocation = const Geo(0, 0),
    this.currentAddressLabel = 'Location unavailable',
    this.currentBarangay = '',
    this.currentMunicipality = '',
    this.currentProvince = '',
    this.searchQuery = '',
    this.isSearching = false,
    this.autocompleteSuggestions = const [],
    this.recentDestinations = const [],
    this.popularPlaces = const [],
    this.selectedDestination,
    this.isRouting = false,
    this.routeDistanceKm = 0.0,
    this.routeDurationMins = 0,
    this.routePoints = const [],
    this.tricycleFare = 0,
    this.habalFare = 0,
    this.selectedVehicle = VehicleType.tricycle,
    this.searchRadiusKm = 5.0,
    this.nearbyDrivers = const [],
    this.selectedDriver,
    this.availableDriverCount = 0,
    this.isOffline = false,
    this.isExportingMap = false,
    this.mapExportImagePath,
    this.shareTripLink,
    this.errorMessage,
    this.isBookingConfirmed = false,
    this.isLoadingWeather = false,
    this.weatherCondition = 'Fair',
    this.weatherEmoji = '🌤️',
    this.weatherTempC = 29,
    this.weatherLastUpdated,
  });

  /// Time-aware Cebuano greeting
  String get cebuanoGreeting => TimeGreeting.getCebuanoGreeting();

  /// Time-aware English greeting
  String get englishGreeting => TimeGreeting.getGreeting();

  bool get hasLocation =>
      passengerLocation.lat != 0 || passengerLocation.lng != 0;

  String get weatherTemperatureLabel =>
      weatherTempC > 0 ? '$weatherTempC°C' : '29°C';

  PassengerSearchState copyWith({
    bool? isLoadingLocation,
    bool? isLocationPermissionDenied,
    Geo? passengerLocation,
    String? currentAddressLabel,
    String? currentBarangay,
    String? currentMunicipality,
    String? currentProvince,
    String? searchQuery,
    bool? isSearching,
    List<Place>? autocompleteSuggestions,
    List<Place>? recentDestinations,
    List<Place>? popularPlaces,
    Place? selectedDestination,
    bool clearDestination = false,
    bool? isRouting,
    double? routeDistanceKm,
    int? routeDurationMins,
    List<Geo>? routePoints,
    double? tricycleFare,
    double? habalFare,
    VehicleType? selectedVehicle,
    double? searchRadiusKm,
    List<NearbyDriver>? nearbyDrivers,
    NearbyDriver? selectedDriver,
    bool clearSelectedDriver = false,
    int? availableDriverCount,
    bool? isOffline,
    bool? isExportingMap,
    String? mapExportImagePath,
    String? shareTripLink,
    String? errorMessage,
    bool clearError = false,
    bool? isBookingConfirmed,
    bool? isLoadingWeather,
    String? weatherCondition,
    String? weatherEmoji,
    int? weatherTempC,
    DateTime? weatherLastUpdated,
  }) {
    return PassengerSearchState(
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLocationPermissionDenied:
          isLocationPermissionDenied ?? this.isLocationPermissionDenied,
      passengerLocation: passengerLocation ?? this.passengerLocation,
      currentAddressLabel: currentAddressLabel ?? this.currentAddressLabel,
      currentBarangay: currentBarangay ?? this.currentBarangay,
      currentMunicipality: currentMunicipality ?? this.currentMunicipality,
      currentProvince: currentProvince ?? this.currentProvince,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      autocompleteSuggestions:
          autocompleteSuggestions ?? this.autocompleteSuggestions,
      recentDestinations: recentDestinations ?? this.recentDestinations,
      popularPlaces: popularPlaces ?? this.popularPlaces,
      selectedDestination: clearDestination
          ? null
          : (selectedDestination ?? this.selectedDestination),
      isRouting: isRouting ?? this.isRouting,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      routeDurationMins: routeDurationMins ?? this.routeDurationMins,
      routePoints: routePoints ?? this.routePoints,
      tricycleFare: tricycleFare ?? this.tricycleFare,
      habalFare: habalFare ?? this.habalFare,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
      selectedDriver:
          clearSelectedDriver ? null : (selectedDriver ?? this.selectedDriver),
      availableDriverCount: availableDriverCount ?? this.availableDriverCount,
      isOffline: isOffline ?? this.isOffline,
      isExportingMap: isExportingMap ?? this.isExportingMap,
      mapExportImagePath: mapExportImagePath ?? this.mapExportImagePath,
      shareTripLink: shareTripLink ?? this.shareTripLink,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isBookingConfirmed: isBookingConfirmed ?? this.isBookingConfirmed,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      weatherEmoji: weatherEmoji ?? this.weatherEmoji,
      weatherTempC: weatherTempC ?? this.weatherTempC,
      weatherLastUpdated: weatherLastUpdated ?? this.weatherLastUpdated,
    );
  }
}

// --- BLOC IMPLEMENTATION ---
class PassengerSearchBloc {
  final DriverMatchingService matchingService = DriverMatchingService.instance;
  final OsmMapService _osmService = OsmMapService.instance;
  final WeatherService _weatherService = WeatherService.instance;

  PassengerSearchState _state = const PassengerSearchState();
  PassengerSearchState get state => _state;

  final _stateController = StreamController<PassengerSearchState>.broadcast();
  Stream<PassengerSearchState> get stream => _stateController.stream;

  StreamSubscription<List<NearbyDriver>>? _driverSub;
  int _driverQueryGeneration = 0;
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<List<RideEntry>>? _historySub;
  String? _historyUserId;
  Timer? _searchDebounce;
  Timer? _periodicWeatherTimer;
  Geo? _lastWeatherLocation;
  bool _isDetectingLocation = false;

  PassengerSearchBloc({bool detectLocation = true}) {
    _init(detectLocation: detectLocation);
  }

  void _init({required bool detectLocation}) {
    AppState.instance.addListener(_syncHistoryUser);
    _syncHistoryUser();
    if (detectLocation) add(DetectLocationEvent());
    // Periodically refresh weather every 15 minutes
    _periodicWeatherTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      add(RefreshWeatherEvent());
    });
  }

  final Set<String> _dismissedDestinationKeys = {};

  bool _isPlaceDismissed(String name, Geo geo) {
    final normName = name.toLowerCase().trim();
    if (_dismissedDestinationKeys.contains(normName)) return true;
    final coordKey =
        '${geo.lat.toStringAsFixed(4)},${geo.lng.toStringAsFixed(4)}';
    if (_dismissedDestinationKeys.contains(coordKey)) return true;
    final combinedKey = '$normName|$coordKey';
    return _dismissedDestinationKeys.contains(combinedKey);
  }

  Future<void> _loadDismissedDestinations(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(
              'passenger_dismissed_recent_destinations_$userId') ??
          [];
      _dismissedDestinationKeys.addAll(list);
    } catch (e) {
      debugPrint('Error loading dismissed recent destinations: $e');
    }
  }

  void _saveDismissedDestinations(String userId) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList(
        'passenger_dismissed_recent_destinations_$userId',
        _dismissedDestinationKeys.toList(),
      );
    }).catchError((e) {
      debugPrint('Error saving dismissed recent destinations: $e');
    });
  }

  void _syncHistoryUser() async {
    final user = AppState.instance.currentUser;
    final userId = user?.isPassenger == true ? user!.id : null;
    if (userId == _historyUserId) return;
    _historyUserId = userId;
    _historySub?.cancel();
    _dismissedDestinationKeys.clear();
    _emit(_state.copyWith(recentDestinations: const []));
    if (userId == null) return;

    await _loadDismissedDestinations(userId);
    if (_historyUserId != userId) return;

    _historySub = AppState.instance.rideHistoryStream().listen((entries) {
      if (_historyUserId != userId) return;
      final sorted = entries
          .map((e) => e.trip)
          .where((t) =>
              t.passengerId == userId && t.status != RideStatus.cancelled)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final seen = <String>{};
      final places = <Place>[];
      for (final trip in sorted) {
        final name = trip.dropoffAddress.trim();
        if (name.isEmpty) continue;
        if (_isPlaceDismissed(name, trip.dropoff)) continue;
        final key =
            '${trip.dropoff.lat.toStringAsFixed(5)},${trip.dropoff.lng.toStringAsFixed(5)}';
        if (seen.add(key)) places.add(Place(name, trip.dropoff, name));
        if (places.length == 5) break;
      }
      _emit(_state.copyWith(recentDestinations: places));
    }, onError: (Object error) {
      debugPrint('Unable to load recent destinations: $error');
    });
  }

  void add(PassengerSearchEvent event) {
    if (event is DetectLocationEvent) {
      _handleDetectLocation(event.forceRecenter);
    } else if (event is LocationUpdatedEvent) {
      _handleLocationUpdated(event.location);
    } else if (event is RefreshWeatherEvent) {
      _fetchWeatherForLocation(_state.passengerLocation);
    } else if (event is SearchDestinationEvent) {
      _handleSearchDestination(event.query);
    } else if (event is SelectDestinationEvent) {
      _handleSelectDestination(event.destination);
    } else if (event is UpdatePickupLocationEvent) {
      _handleUpdatePickup(event.pickupLocation, event.pickupAddress);
    } else if (event is ClearDestinationEvent) {
      _handleClearDestination();
    } else if (event is UpdateSearchRadiusEvent) {
      _handleUpdateRadius(event.radiusKm);
    } else if (event is SelectVehicleTypeEvent) {
      _handleSelectVehicle(event.vehicleType);
    } else if (event is SelectDriverEvent) {
      _handleSelectDriver(event.driver);
    } else if (event is AutoMatchDriverEvent) {
      _handleAutoMatchDriver();
    } else if (event is ConfirmBookingEvent) {
      _handleConfirmBooking();
    } else if (event is ExportMapEvent) {
      _handleExportMap();
    } else if (event is ShareTripEvent) {
      _handleShareTrip();
    } else if (event is DismissRecentDestinationEvent) {
      _handleDismissRecentDestination(event.destination);
    }
  }

  void _emit(PassengerSearchState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  Future<void> _handleDetectLocation(bool forceRecenter) async {
    if (_isDetectingLocation) return;
    _isDetectingLocation = true;
    _emit(_state.copyWith(isLoadingLocation: true, clearError: true));

    Geo? detectedLoc;
    var isPermissionDenied = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        isPermissionDenied = true;
        debugPrint('SakayTa: Location permission denied.');
      } else {
        final position = await _currentPositionWithRetry();
        if (position != null) {
          detectedLoc = Geo(position.latitude, position.longitude);
          _startPositionStream();
        }
      }
    } catch (e) {
      debugPrint('SakayTa: GPS detection exception ($e)');
    }

    if (isPermissionDenied || detectedLoc == null) {
      _emit(_state.copyWith(
          isLoadingLocation: false,
          isLocationPermissionDenied: isPermissionDenied,
          errorMessage:
              'Location unavailable. Enable location permission and try again.'));
      _isDetectingLocation = false;
      return;
    }

    _startDriverSubscription(
        detectedLoc, _state.searchRadiusKm, _state.selectedVehicle);

    // Fetch real-time weather for the detected GPS coordinates
    _fetchWeatherForLocation(detectedLoc);

    _emit(_state.copyWith(
      isLoadingLocation: false,
      isLocationPermissionDenied: false,
      passengerLocation: detectedLoc,
      currentAddressLabel:
          '${detectedLoc.lat.toStringAsFixed(5)}, ${detectedLoc.lng.toStringAsFixed(5)}',
    ));
    _isDetectingLocation = false;
    unawaited(_resolvePickupAddress(detectedLoc)
        .catchError((Object e, StackTrace s) {
      AppLogger.debug('PassengerSearchBloc: _resolvePickupAddress note ($e)',
          error: e, stackTrace: s);
    }));
  }

  Future<Position?> _currentPositionWithRetry() async {
    Future<Position?> getPosition() async {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (error) {
        debugPrint('SakayTa: current GPS attempt failed: $error');
        return null;
      }
    }

    final first = await getPosition();
    if (first != null) return first;
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return getPosition();
  }

  Future<void> _resolvePickupAddress(Geo location) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final structured = await _osmService.reverseGeocodeStructured(location);
      final address = structured.address?.trim();
      final province = structured.province?.trim();
      if ((address?.isNotEmpty ?? false) || (province?.isNotEmpty ?? false)) {
        if (Geo.distanceKm(_state.passengerLocation, location) > 0.03) return;
        final provinceChanged = province != null &&
            province.isNotEmpty &&
            _state.currentProvince.isNotEmpty &&
            province.toLowerCase() != _state.currentProvince.toLowerCase();
        _emit(_state.copyWith(
          currentAddressLabel: address?.isNotEmpty == true
              ? address
              : _state.currentAddressLabel,
          currentProvince:
              province?.isNotEmpty == true ? province : _state.currentProvince,
          clearDestination: provinceChanged,
        ));
        return;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    debugPrint('SakayTa: pickup address unavailable; retaining coordinates.');
  }

  Future<void> _fetchWeatherForLocation(Geo location) async {
    final effectiveLocation = (location.lat == 0 && location.lng == 0)
        ? const Geo(10.3157, 123.8854)
        : location;
    _emit(_state.copyWith(isLoadingWeather: true));
    try {
      final weather = await _weatherService.getWeather(effectiveLocation);
      _lastWeatherLocation = effectiveLocation;
      _emit(_state.copyWith(
        isLoadingWeather: false,
        weatherTempC: weather.temperatureRounded,
        weatherCondition: weather.condition,
        weatherEmoji: weather.emoji,
        weatherLastUpdated: weather.lastUpdated,
      ));
    } catch (e) {
      debugPrint('SakayTa: weather fetch note ($e)');
      _emit(_state.copyWith(
        isLoadingWeather: false,
        weatherCondition: 'Fair',
        weatherEmoji: '🌤️',
        weatherTempC: 29,
        weatherLastUpdated: DateTime.now(),
      ));
    }
  }

  void _startPositionStream() {
    _positionStreamSub?.cancel();
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // update every 15 meters for optimal low-end battery & CPU
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final newLoc = Geo(position.latitude, position.longitude);
          add(LocationUpdatedEvent(newLoc));
        },
        onError: (error) {
          debugPrint('SakayTa: positionStream error: $error');
        },
      );
    } catch (e) {
      debugPrint('SakayTa: unable to start position stream ($e)');
    }
  }

  Future<void> _handleLocationUpdated(Geo newLocation) async {
    final diff = Geo.distanceKm(_state.passengerLocation, newLocation);
    if (diff < 0.015) return;
    _startDriverSubscription(
        newLocation, _state.searchRadiusKm, _state.selectedVehicle);

    _emit(_state.copyWith(
        passengerLocation: newLocation,
        currentAddressLabel:
            '${newLocation.lat.toStringAsFixed(5)}, ${newLocation.lng.toStringAsFixed(5)}'));

    // Reverse geocode occasionally in background
    _osmService.reverseGeocode(newLocation).then((addr) {
      if (addr != null && addr.isNotEmpty) {
        _emit(_state.copyWith(currentAddressLabel: addr));
      }
    });

    // Refresh weather if moved significantly (> 500 meters)
    if (_lastWeatherLocation == null ||
        Geo.distanceKm(_lastWeatherLocation!, newLocation) > 0.5) {
      _fetchWeatherForLocation(newLocation);
    }

    // Recalculate route if destination chosen
    if (_state.selectedDestination != null) {
      _recalculateActiveRoute(newLocation, _state.selectedDestination!.geo);
    }
  }

  Future<void> _handleUpdatePickup(Geo pickup, String? addressLabel) async {
    String address = addressLabel ??
        '${pickup.lat.toStringAsFixed(5)}, ${pickup.lng.toStringAsFixed(5)}';

    // Use reverseGeocodeStructured to get both the address and the province
    // in a single network call. Fall back to the provided addressLabel on error.
    var newProvince = _state.currentProvince;
    try {
      final structured = await _osmService.reverseGeocodeStructured(pickup);
      if (structured.address != null && structured.address!.isNotEmpty) {
        address = structured.address!;
      } else if (addressLabel == null) {
        final rev = await _osmService.reverseGeocode(pickup);
        if (rev != null) address = rev;
      }
      if (structured.province != null && structured.province!.isNotEmpty) {
        newProvince = structured.province!;
      }
    } catch (e) {
      debugPrint('SakayTa: updatePickup province detection error ($e)');
      if (addressLabel == null) {
        final rev = await _osmService.reverseGeocode(pickup);
        if (rev != null) address = rev;
      }
    }

    // If the province changed, clear the destination — it may now be invalid.
    final provinceChanged = newProvince.isNotEmpty &&
        _state.currentProvince.isNotEmpty &&
        newProvince.toLowerCase().trim() !=
            _state.currentProvince.toLowerCase().trim();

    if (provinceChanged) {
      debugPrint(
          'SakayTa: Pickup province changed to $newProvince — destination cleared.');
    }

    _emit(_state.copyWith(
      passengerLocation: pickup,
      currentAddressLabel: address,
      currentProvince: newProvince,
      clearDestination: provinceChanged,
    ));

    _startDriverSubscription(
        pickup, _state.searchRadiusKm, _state.selectedVehicle);
    _fetchWeatherForLocation(pickup);

    if (!provinceChanged && _state.selectedDestination != null) {
      _recalculateActiveRoute(pickup, _state.selectedDestination!.geo);
    }
  }

  void _startDriverSubscription(
      Geo location, double radiusKm, VehicleType? vehicleType) {
    final generation = ++_driverQueryGeneration;
    _driverSub?.cancel();
    debugPrint('[SakayTa][NearbyDrivers][subscribe] generation=$generation '
        'origin=${location.lat.toStringAsFixed(5)},${location.lng.toStringAsFixed(5)} '
        'radiusKm=${radiusKm.toStringAsFixed(1)} '
        'vehicle=${vehicleType?.key ?? 'any'}');
    _driverSub = AppState.instance
        .streamNearbyDrivers(
      lat: location.lat,
      lng: location.lng,
      radiusKm: radiusKm,
      vehicleType: vehicleType,
    )
        .listen((drivers) {
      if (generation != _driverQueryGeneration) return;
      NearbyDriver? updatedSelected = _state.selectedDriver;
      var selectedStillVisible = updatedSelected == null;
      if (updatedSelected != null) {
        try {
          updatedSelected =
              drivers.firstWhere((d) => d.id == updatedSelected!.id);
          selectedStillVisible = true;
        } catch (_) {
          updatedSelected = null;
        }
      }

      // Auto-select the first bookable driver if none is selected
      if (updatedSelected == null) {
        try {
          updatedSelected = drivers.firstWhere((d) => d.canSubmitRideRequest);
          selectedStillVisible = true;
        } catch (e, s) {
          AppLogger.debug('PassengerSearchBloc non-fatal note: $e',
              error: e, stackTrace: s);
        }
      }
      final bookableCount =
          drivers.where((driver) => driver.canSubmitRideRequest).length;
      debugPrint('[SakayTa][NearbyDrivers][state] generation=$generation '
          'visible=${drivers.length} bookable=$bookableCount');
      _emit(_state.copyWith(
        nearbyDrivers: drivers,
        availableDriverCount: bookableCount,
        selectedDriver: updatedSelected,
        clearSelectedDriver: !selectedStillVisible,
      ));
    }, onError: (Object error, StackTrace stackTrace) {
      if (generation != _driverQueryGeneration) return;
      debugPrint('[SakayTa][ERROR][NearbyDrivers] $error');
      debugPrintStack(stackTrace: stackTrace);
    });
  }

  void _handleSearchDestination(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _emit(_state.copyWith(
        searchQuery: '',
        isSearching: false,
        autocompleteSuggestions: [],
      ));
      return;
    }

    _emit(_state.copyWith(searchQuery: query, isSearching: true));
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _osmService.autocomplete(
          query,
          near: _state.passengerLocation,
          provinceHint:
              _state.currentProvince.isNotEmpty ? _state.currentProvince : null,
        );

        if (_state.searchQuery != query) return;

        _emit(_state.copyWith(
          isSearching: false,
          autocompleteSuggestions: suggestions,
        ));
      } catch (e) {
        debugPrint('SakayTa: OpenStreetMap search error ($e)');
        if (_state.searchQuery == query) {
          _emit(_state.copyWith(
            isSearching: false,
            autocompleteSuggestions: _localSuggestions(query),
          ));
        }
      }
    });
  }

  List<Place> _localSuggestions(String query) {
    final queryLower = query.toLowerCase();
    return _state.recentDestinations.where((place) {
      return place.name.toLowerCase().contains(queryLower) ||
          place.address.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<void> _handleSelectDestination(Place destination) async {
    // Show routing spinner immediately but do NOT commit the destination yet.
    // The destination is only accepted after province validation passes.
    _emit(_state.copyWith(
      isRouting: true,
      routePoints: const [],
      routeDistanceKm: 0,
      routeDurationMins: 0,
      searchQuery: destination.name,
      autocompleteSuggestions: [],
      clearError: true,
    ));

    // Resolve full place details (coordinates) for the selection.
    var resolved = destination;
    if (destination.placeId != null) {
      try {
        final fetched =
            await _osmService.fetchPlaceDetails(destination.placeId!);
        if (fetched != null) resolved = fetched;
      } catch (e) {
        debugPrint('SakayTa: place details error ($e)');
      }
    }

    // ── Province Validation ────────────────────────────────────────────────
    // The pickup province MUST be known before we can validate anything.
    final pickupProvince = _state.currentProvince.trim();
    if (pickupProvince.isEmpty) {
      _emit(_state.copyWith(
        isRouting: false,
        clearDestination: true,
        errorMessage: 'Unable to determine your pickup area. Please try again.',
      ));
      debugPrint(
          'SakayTa: province validation skipped — pickup province unknown.');
      return;
    }

    // Reverse-geocode the destination coordinates to get its province.
    String? destinationProvince;
    try {
      final structured =
          await _osmService.reverseGeocodeStructured(resolved.geo);
      destinationProvince = structured.province?.trim();
    } catch (e) {
      debugPrint('SakayTa: destination province lookup error ($e)');
    }

    if (destinationProvince == null || destinationProvince.isEmpty) {
      _emit(_state.copyWith(
        isRouting: false,
        clearDestination: true,
        errorMessage:
            'Unable to verify the destination area. Please select a different destination.',
      ));
      return;
    }

    // Case-insensitive province comparison.
    if (destinationProvince.toLowerCase() != pickupProvince.toLowerCase()) {
      debugPrint(
          'SakayTa: destination province "$destinationProvince" != pickup province "$pickupProvince" — rejected.');
      _emit(_state.copyWith(
        isRouting: false,
        clearDestination: true,
        errorMessage: 'Please select a destination within $pickupProvince.',
      ));
      return;
    }

    // Province matches — stamp the validated province onto the resolved place
    // so it travels through to confirmSelectedBooking.
    resolved = resolved.withProvince(destinationProvince);
    debugPrint(
        'SakayTa: destination "${resolved.name}" in "$destinationProvince" accepted.');

    // Now commit the validated destination and calculate the route.
    _emit(_state.copyWith(selectedDestination: resolved));
    await _recalculateActiveRoute(_state.passengerLocation, resolved.geo,
        resolvedPlace: resolved);
  }

  Future<void> _recalculateActiveRoute(Geo origin, Geo destGeo,
      {Place? resolvedPlace}) async {
    if (!_state.hasLocation) {
      _emit(_state.copyWith(
          isRouting: false,
          errorMessage:
              'Choose a real pickup location before requesting a route.'));
      return;
    }
    var dist = 0.0;
    var duration = 0;
    List<Geo> route = [];

    try {
      final routeDetails = await _osmService.computeRoute(
        origin: origin,
        destination: destGeo,
      );
      if (routeDetails != null) {
        dist = routeDetails.distanceKm;
        duration = routeDetails.durationMins;
        route = routeDetails.polylinePoints;
      }
    } catch (e) {
      debugPrint('SakayTa: OSRM route error ($e)');
    }

    if (route.length < 2 || dist <= 0) {
      // Weak signal / OSRM timeout: never block booking. Approximate the road
      // distance from the straight-line distance (rural road winding factor)
      // and draw a direct line so the passenger still gets a fare.
      final fallback = approximateRoute(origin, destGeo);
      if (fallback == null) {
        _emit(_state.copyWith(
            isRouting: false,
            routePoints: const [],
            routeDistanceKm: 0,
            routeDurationMins: 0,
            errorMessage:
                'Road route unavailable. Please try again when connected.'));
        return;
      }
      debugPrint('SakayTa: OSRM unavailable - using approximate route '
          '(${fallback.distanceKm.toStringAsFixed(2)} km)');
      dist = fallback.distanceKm;
      duration = fallback.durationMins;
      route = fallback.polylinePoints;
    }

    dist = double.parse(dist.toStringAsFixed(1));

    final trikFare = matchingService.calculateFare(
        vehicleType: VehicleType.tricycle, distanceKm: dist);
    final habalFare = matchingService.calculateFare(
        vehicleType: VehicleType.habal, distanceKm: dist);

    final topDrivers = _state.nearbyDrivers;
    final bestMatch = _state.selectedDriver ?? _firstBookable(topDrivers);

    _emit(_state.copyWith(
      isRouting: false,
      selectedDestination: resolvedPlace ?? _state.selectedDestination,
      routeDistanceKm: dist,
      routeDurationMins: duration,
      routePoints: route,
      tricycleFare: trikFare,
      habalFare: habalFare,
      selectedDriver: bestMatch,
    ));
  }

  /// Dynamically re-evaluates active route fares when admin rates update.
  void recomputeFares() {
    if (_state.routeDistanceKm > 0) {
      final dist = double.parse(_state.routeDistanceKm.toStringAsFixed(1));
      final trikFare = matchingService.calculateFare(
          vehicleType: VehicleType.tricycle, distanceKm: dist);
      final habalFare = matchingService.calculateFare(
          vehicleType: VehicleType.habal, distanceKm: dist);
      _emit(_state.copyWith(
        tricycleFare: trikFare,
        habalFare: habalFare,
      ));
    }
  }

  void _handleClearDestination() {
    _emit(_state.copyWith(
      clearDestination: true,
      searchQuery: '',
      autocompleteSuggestions: [],
      routeDistanceKm: 0,
      routeDurationMins: 0,
      routePoints: const [],
      clearSelectedDriver: true,
    ));
  }

  void _handleUpdateRadius(double radiusKm) {
    _startDriverSubscription(
        _state.passengerLocation, radiusKm, _state.selectedVehicle);
    _emit(_state.copyWith(searchRadiusKm: radiusKm));
  }

  void _handleSelectVehicle(VehicleType vehicleType) {
    _startDriverSubscription(
        _state.passengerLocation, _state.searchRadiusKm, vehicleType);

    _emit(_state.copyWith(
      selectedVehicle: vehicleType,
    ));
  }

  void _handleSelectDriver(NearbyDriver driver) {
    _emit(_state.copyWith(selectedDriver: driver));
  }

  void _handleAutoMatchDriver() {
    final match = _firstBookable(_state.nearbyDrivers);
    if (match != null) {
      _emit(_state.copyWith(selectedDriver: match));
    } else {
      _emit(_state.copyWith(
        errorMessage:
            'No drivers available nearby within ${_state.searchRadiusKm.toInt()} km. Please expand radius or try again.',
      ));
    }
  }

  NearbyDriver? _firstBookable(List<NearbyDriver> drivers) {
    for (final driver in drivers) {
      if (driver.canSubmitRideRequest) return driver;
    }
    return null;
  }

  void _handleConfirmBooking() {
    unawaited(confirmSelectedBooking().catchError((Object e, StackTrace s) {
      AppLogger.warn('PassengerSearchBloc: confirmSelectedBooking error ($e)',
          error: e, stackTrace: s);
      _emit(_state.copyWith(
        errorMessage: 'Unable to submit booking. Please try again.',
      ));
      return false;
    }));
  }

  Future<bool> confirmSelectedBooking(
      {String? paymentMethod, int passengerCount = 1}) async {
    if (!_state.hasLocation ||
        _state.isRouting ||
        _state.routeDistanceKm <= 0 ||
        _state.routePoints.isEmpty) {
      _emit(_state.copyWith(
          errorMessage:
              'A pickup location and road route are required to book a ride.'));
      return false;
    }

    // Removed strict province validation to prevent silent booking failures.
    final selected = _state.selectedDriver;
    final destination = _state.selectedDestination;
    if (selected == null) {
      _emit(_state.copyWith(errorMessage: 'Please select a driver first.'));
      return false;
    }
    if (!selected.canSubmitRideRequest) {
      _emit(_state.copyWith(
          errorMessage:
              'Driver is currently Offline, busy, or has no saved location.'));
      return false;
    }
    if (destination == null) {
      _emit(
          _state.copyWith(errorMessage: 'Please select a destination first.'));
      return false;
    }
    _emit(_state.copyWith(
      isBookingConfirmed: false,
      clearError: true,
    ));
    try {
      final actualPaymentMethod =
          paymentMethod ?? PaymentService.instance.defaultMethod.type;

      final trip = await AppState.instance.requestTrip(
        pickupAddress: _state.currentAddressLabel,
        dropoffAddress: destination.name,
        pickup: _state.passengerLocation,
        dropoff: destination.geo,
        vehicleType: _state.selectedVehicle,
        paymentMethod: actualPaymentMethod,
        driverId: selected.id,
        passengerCount: passengerCount,
        estimatedFare: _state.selectedVehicle == VehicleType.tricycle
            ? _state.tricycleFare
            : _state.habalFare,
        distanceKm: _state.routeDistanceKm > 0 ? _state.routeDistanceKm : null,
        durationMin:
            _state.routeDurationMins > 0 ? _state.routeDurationMins : null,
      );
      if (trip == null) {
        _emit(_state.copyWith(
            isBookingConfirmed: false,
            errorMessage:
                'Unable to book a ride. Please sign in and try again.'));
        return false;
      }
      _emit(_state.copyWith(
        isBookingConfirmed: true,
        clearError: true,
      ));
      return true;
    } on StateError catch (error) {
      _emit(_state.copyWith(
        isBookingConfirmed: false,
        errorMessage: error.message,
      ));
      return false;
    } catch (e) {
      // Check if it's a Supabase/Postgrest exception containing our backend error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('online') ||
          errorStr.contains('available') ||
          errorStr.contains('capacity') ||
          errorStr.contains('full') ||
          errorStr.contains('active ride or reservation')) {
        _emit(_state.copyWith(
            isBookingConfirmed: false,
            errorMessage:
                'Driver is currently unavailable or at full capacity. Please select another driver.'));
      } else {
        _emit(_state.copyWith(
          isBookingConfirmed: false,
          errorMessage: 'Error: ${e.toString().replaceFirst("Exception: ", "").replaceFirst("StateError: ", "")}',
        ));
      }
      return false;
    }
  }

  void _handleExportMap() {
    _emit(_state.copyWith(
        isExportingMap: false,
        errorMessage:
            'Image export is unavailable. You can copy your actual map location.'));
  }

  void _handleShareTrip() {
    if (!_state.hasLocation) return;
    final location = _state.passengerLocation;
    final link =
        'https://www.openstreetmap.org/?mlat=${location.lat}&mlon=${location.lng}#map=16/${location.lat}/${location.lng}';
    _emit(_state.copyWith(shareTripLink: link));
  }

  void _handleDismissRecentDestination(Place destination) {
    final normName = destination.name.toLowerCase().trim();
    final coordKey =
        '${destination.geo.lat.toStringAsFixed(4)},${destination.geo.lng.toStringAsFixed(4)}';
    final combinedKey = '$normName|$coordKey';

    _dismissedDestinationKeys.add(normName);
    _dismissedDestinationKeys.add(coordKey);
    _dismissedDestinationKeys.add(combinedKey);

    final updated = _state.recentDestinations
        .where((p) => !_isPlaceDismissed(p.name, p.geo))
        .toList();
    _emit(_state.copyWith(recentDestinations: updated));

    final userId = _historyUserId;
    if (userId != null) {
      _saveDismissedDestinations(userId);
    }
  }

  void dispose() {
    AppState.instance.removeListener(_syncHistoryUser);
    _historySub?.cancel();
    _searchDebounce?.cancel();
    _periodicWeatherTimer?.cancel();
    _driverSub?.cancel();
    _positionStreamSub?.cancel();
    _stateController.close();
  }
}
