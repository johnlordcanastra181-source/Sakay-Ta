import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/firestore_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../main.dart';
import '../models/app_user.dart';
import '../models/driver_profile.dart';
import '../models/trip.dart';
import '../services/fare_calculator.dart';
import '../services/supabase_service.dart';
import '../services/osm_map_service.dart';
import '../state/app_state.dart';
import '../widgets/live_osm_map_widget.dart';
import '../widgets/rate_driver_modal.dart';
import '../widgets/user_avatar.dart';

enum RideTrackingViewStatus {
  loading,
  noActiveRide,
  waitingForDriver,
  activeTracking,
  completed,
  cancelled,
  error,
}

class RideTracking extends StatefulWidget {
  const RideTracking({super.key, required this.onNavigate, this.rideId});
  final Function(AppScreen) onNavigate;
  final String? rideId;

  @override
  State<RideTracking> createState() => _RideTrackingState();
}

class _RideTrackingState extends State<RideTracking> {
  StreamSubscription<Position>? _passengerLocationSub;
  Geo? _passengerLocation;
  Geo? _lastDriverLocation;
  List<Geo> _route = const [];
  String? _routeKey;
  Geo? _lastRoutedDriver;
  String? _lastRoutedStatus;
  String? _locationMessage;
  bool _cancelling = false;
  bool _isProcessingComplete = false;
  int _retryKey = 0;
  Stream<Trip?>? _rideStream;
  String? _rideStreamKey;
  String? _trackedRideId;
  Trip? _lastTrackedTrip;
  String? _autoPromptedModalRideId;
  Stream<DriverLiveLocation?>? _driverLocationStream;
  String? _driverLocationStreamKey;

  @override
  void initState() {
    super.initState();
    unawaited(_startPassengerLocation());
  }

  @override
  void dispose() {
    _passengerLocationSub?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _retryKey++;
      _locationMessage = null;
      _rideStream = null;
      _rideStreamKey = null;
      _driverLocationStream = null;
      _driverLocationStreamKey = null;
    });
    unawaited(_startPassengerLocation());
  }

  Stream<Trip?> _stableRideStream(
      AppState app, AppUser user, String? targetRideId) {
    final normalizedRideId = targetRideId?.trim();
    if (normalizedRideId != null && normalizedRideId.isNotEmpty) {
      _trackedRideId = normalizedRideId;
    }
    final lockedId = _trackedRideId ?? normalizedRideId;
    final hasLockedId = lockedId != null && lockedId.isNotEmpty;
    final key = '${user.id}|${user.isDriver}|${lockedId ?? 'active'}';
    if (_rideStream == null || _rideStreamKey != key) {
      _rideStreamKey = key;
      _rideStream = hasLockedId
          ? app.streamTrip(lockedId)
          : (user.isDriver
              ? app.streamActiveTripForDriver(user.id)
              : app.streamActiveTripForPassenger(user.id));
    }
    return _rideStream!;
  }

  Stream<DriverLiveLocation?> _stableDriverLocationStream(
      AppState app, String driverId) {
    if (_driverLocationStream == null || _driverLocationStreamKey != driverId) {
      _driverLocationStreamKey = driverId;
      _driverLocationStream = app.streamDriverLocation(driverId);
    }
    return _driverLocationStream!;
  }

  Future<void> _startPassengerLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationMessage =
              'Please enable location services for live GPS tracking.');
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationMessage =
              'Location permission is required for live GPS tracking.');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _passengerLocation = Geo(position.latitude, position.longitude);
        _locationMessage = null;
      });
      _passengerLocationSub?.cancel();
      _passengerLocationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen(
        (pos) {
          if (mounted) {
            setState(
                () => _passengerLocation = Geo(pos.latitude, pos.longitude));
          }
        },
        onError: (err) {
          debugPrint('[SakayTa][RideTracking] GPS stream note: $err');
        },
      );
    } catch (error) {
      debugPrint('[SakayTa][RideTracking] passenger location error: $error');
      if (mounted) {
        setState(
            () => _locationMessage = 'Passenger GPS temporarily unavailable.');
      }
    }
  }

  Future<void> _loadRoute(Trip trip, Geo? driver) async {
    final origin = driver ?? trip.pickup;
    final destination =
        trip.status == RideStatus.started ? trip.dropoff : trip.pickup;
    if (_lastRoutedDriver != null &&
        _lastRoutedStatus == trip.status &&
        Geo.distanceKm(_lastRoutedDriver!, origin) < 0.08) {
      return;
    }
    final key = '${trip.id}:${trip.status}:${origin.lat}:${origin.lng}';
    if (_routeKey == key) return;
    _routeKey = key;
    _lastRoutedDriver = origin;
    _lastRoutedStatus = trip.status;
    try {
      final result = await OsmMapService.instance
          .computeRoute(origin: origin, destination: destination);
      if (mounted && _routeKey == key) {
        setState(() => _route = result?.polylinePoints ?? const []);
      }
    } catch (error) {
      debugPrint('[SakayTa][RideTracking] route error: $error');
      if (mounted && _routeKey == key) setState(() => _route = const []);
    }
  }

  Future<void> _cancelRide(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content:
            const Text('Are you sure you want to cancel this ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep Ride'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Ride'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final app = context.read<AppState>();
      final success = await app.cancelRide(trip.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled successfully.')),
        );
        widget.onNavigate(AppScreen.passengerHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to cancel ride. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('[SakayTa][ERROR][RideTracking] cancel ride error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _smsPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('sms:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    final dark =
        app.darkMode || Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return _unauthenticatedScreen(dark);
    }

    // Direct ride ID lookup with active-ride and pending-rating fallback
    final targetRideId = widget.rideId?.trim().isNotEmpty == true
        ? widget.rideId!.trim()
        : (app.activeTrip?.id ?? app.pendingRatingTrip?.id ?? _trackedRideId);

    final stream = _stableRideStream(app, user, targetRideId);
    final initialTrip =
        (widget.rideId == null || widget.rideId == app.activeTrip?.id)
            ? (app.activeTrip ?? app.pendingRatingTrip ?? _lastTrackedTrip)
            : (app.pendingRatingTrip?.id == widget.rideId
                ? app.pendingRatingTrip
                : _lastTrackedTrip);

    return KeyedSubtree(
      key: ValueKey('tracking_stream_$_retryKey'),
      child: StreamBuilder<Trip?>(
        stream: stream,
        initialData: initialTrip,
        builder: (context, snapshot) {
          // Check for stream error and classify
          if (snapshot.hasError) {
            final error = snapshot.error;
            debugPrint('[SakayTa][ERROR][RideTracking] error: $error');
            if (error is AuthException) {
              debugPrint(
                  '[SakayTa][ERROR][RideTracking] code=${error.code} message=${error.message}');
            }

            // If we have an active trip cached in memory/local DB, use it seamlessly!
            if (app.activeTrip != null) {
              return _routeTripScreen(context, app.activeTrip!, dark,
                  isFallback: true);
            }

            return _errorScreen(context, error, dark);
          }

          // Initial loading state
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _loadingScreen(dark);
          }

          final trip = snapshot.data;
          if (trip == null) {
            if (app.pendingRatingTrip != null) {
              return _routeTripScreen(context, app.pendingRatingTrip!, dark);
            }
            if (_lastTrackedTrip != null &&
                RideStatus.normalize(_lastTrackedTrip!.status) ==
                    RideStatus.completed) {
              return _routeTripScreen(context, _lastTrackedTrip!, dark);
            }
            if (app.activeTrip != null && app.activeTrip!.isActive) {
              return _routeTripScreen(context, app.activeTrip!, dark);
            }
            return _noActiveRideScreen(context, user, dark);
          }

          _trackedRideId = trip.id;
          _lastTrackedTrip = trip;

          debugPrint(
              '[SakayTa][RideTracking] uid=${user.id} rideId=${trip.id} status=${trip.status} driverId=${trip.driverId}');

          return _routeTripScreen(context, trip, dark);
        },
      ),
    );
  }

  Widget _routeTripScreen(BuildContext context, Trip trip, bool dark,
      {bool isFallback = false}) {
    final status = RideStatus.normalize(trip.status);

    if (status == RideStatus.completed) {
      return _completedScreen(context, trip, dark);
    }
    if (status == RideStatus.cancelled) {
      return _cancelledScreen(context, trip, dark);
    }

    final driverId = trip.driverId?.trim();
    if (driverId == null ||
        driverId.isEmpty ||
        status == RideStatus.searching) {
      return _waitingForDriverScreen(context, trip, dark,
          isFallback: isFallback);
    }

    return _activeTrackingWithDriver(context, trip, driverId, dark,
        isFallback: isFallback);
  }

  // ─── WAITING FOR DRIVER SCREEN ──────────────────────────────────────────────
  Widget _waitingForDriverScreen(BuildContext context, Trip trip, bool dark,
      {bool isFallback = false}) {
    unawaited(_loadRoute(trip, null));
    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      appBar: AppBar(
        title: const Text('Ride Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate(AppScreen.passengerHome),
        ),
      ),
      body: Column(
        children: [
          if (isFallback)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text(
                'Offline / Local Mode — Cloud sync temporarily reconnecting.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            height: math.min(280.0, MediaQuery.sizeOf(context).height * 0.36),
            child: LiveOsmMapWidget(
              passengerLocation: _passengerLocation ?? trip.pickup,
              currentAddress: trip.pickupAddress,
              destination:
                  Place('Destination', trip.dropoff, trip.dropoffAddress),
              routePoints: _route,
              trackingPickup: trip.pickup,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finding Nearby Drivers...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor(dark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Waiting for your driver to accept the ride.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.subtextColor(dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor(dark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.borderColor(dark),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.terracotta.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (trip.vehicleType.key == 'habal'
                                      ? 'Habal-Habal'
                                      : 'Tricycle')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.terracotta,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            FareCalculator.formatFare(trip.fare),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor(dark),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _place('Pickup', trip.pickupAddress, dark),
                      const SizedBox(height: 8),
                      _place('Destination', trip.dropoffAddress, dark),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!context.read<AppState>().currentUser!.isDriver)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _cancelling ? null : () => _cancelRide(context, trip),
                    icon: _cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.close_rounded),
                    label: Text(
                        _cancelling ? 'Cancelling...' : 'Cancel Ride Request'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTIVE TRACKING WITH DRIVER ────────────────────────────────────────────
  Widget _activeTrackingWithDriver(
      BuildContext context, Trip trip, String driverId, bool dark,
      {bool isFallback = false}) {
    final app = context.read<AppState>();
    return StreamBuilder<DriverLiveLocation?>(
      stream: _stableDriverLocationStream(app, driverId),
      builder: (context, locationSnapshot) {
        final live = locationSnapshot.data;
        if (live != null) {
          _lastDriverLocation = live.position;
        }
        final driverLocation = live?.position ?? _lastDriverLocation;
        unawaited(_loadRoute(trip, driverLocation));

        final userFuture = SupabaseService.isConfigured
            ? SupabaseService.instance.getUser(driverId)
            : app.auth.getUser(driverId);
        final profileFuture = SupabaseService.isConfigured
            ? SupabaseService.instance.getDriverProfile(driverId)
            : app.auth.getDriverProfile(driverId);

        return FutureBuilder<List<Object?>>(
          future: Future.wait<Object?>([userFuture, profileFuture]),
          builder: (context, profileSnapshot) {
            final driver = profileSnapshot.data?.isNotEmpty == true
                ? profileSnapshot.data![0] as AppUser?
                : null;
            final profile = profileSnapshot.data?.length == 2
                ? profileSnapshot.data![1] as DriverProfile?
                : null;

            return _page(context, trip, driver, profile, driverLocation,
                live != null && !live.fromCache, dark,
                isFallback: isFallback);
          },
        );
      },
    );
  }

  Widget _page(BuildContext context, Trip trip, AppUser? driver,
      DriverProfile? profile, Geo? driverLocation, bool live, bool dark,
      {bool isFallback = false}) {
    final distance = driverLocation == null
        ? null
        : Geo.distanceKm(driverLocation,
            trip.status == RideStatus.started ? trip.dropoff : trip.pickup);

    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      appBar: AppBar(
        title: const Text('Ride Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate(AppScreen.rides),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: live ? Colors.green.shade600 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  live ? 'LIVE' : 'SYNCING',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isFallback)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text(
                'Showing offline/cached ride details.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            height: 350,
            child: LiveOsmMapWidget(
              passengerLocation: _passengerLocation ?? trip.pickup,
              currentAddress: trip.pickupAddress,
              destination:
                  Place('Destination', trip.dropoff, trip.dropoffAddress),
              routePoints: _route,
              trackingPickup: trip.pickup,
              trackingDriverLocation: driverLocation,
              trackingDriverName: driver?.fullName,
              trackingDriverVehicle: profile?.vehicleType ?? trip.vehicleType,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  _status(trip.status),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  live && distance != null
                      ? '${distance.toStringAsFixed(1)} km away'
                      : driverLocation != null
                          ? 'Live driver location updating. Showing last known coordinates.'
                          : 'Driver GPS updating shortly.',
                  style: TextStyle(color: AppColors.subtextColor(dark)),
                ),
                if (_locationMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _locationMessage!,
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 18),
                _driverCard(driver, profile, trip, dark),
                const SizedBox(height: 14),
                _place('Pickup', trip.pickupAddress, dark),
                _place('Destination', trip.dropoffAddress, dark),
                const SizedBox(height: 16),

                // --- PASSENGER UI ---
                if (!context.read<AppState>().currentUser!.isDriver) ...[
                  if (trip.status == RideStatus.accepted ||
                      trip.status == RideStatus.arrived)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          _cancelling ? null : () => _cancelRide(context, trip),
                      icon: _cancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label:
                          Text(_cancelling ? 'Cancelling...' : 'Cancel Ride'),
                    ),
                ],

                // --- DRIVER UI ---
                if (context.read<AppState>().currentUser!.isDriver) ...[
                  if (trip.status == RideStatus.accepted ||
                      trip.status == RideStatus.arrived)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await context.read<AppState>().startActiveTrip();
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start Trip',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  if (trip.status == RideStatus.started)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isProcessingComplete
                          ? null
                          : () async {
                              setState(() => _isProcessingComplete = true);
                              try {
                                final result = await context
                                    .read<AppState>()
                                    .completeTrip(onTime: true);
                                if (context.mounted) {
                                  final confirmed =
                                      result == TripCompletionResult.confirmed;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(confirmed
                                          ? 'Trip completed. Earnings recorded!'
                                          : 'Trip completed offline. Earnings will sync when you reconnect.'),
                                      backgroundColor: confirmed
                                          ? const Color(0xFF16A34A)
                                          : Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  widget.onNavigate(AppScreen.driverHome);
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  final message = error
                                      .toString()
                                      .replaceFirst('Bad state: ', '');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Unable to complete trip: $message'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessingComplete = false);
                                }
                              }
                            },
                      icon: _isProcessingComplete
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                          _isProcessingComplete
                              ? 'Completing...'
                              : 'Complete Trip',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── DRIVER CARD ────────────────────────────────────────────────────────────
  Widget _driverCard(
      AppUser? driver, DriverProfile? profile, Trip trip, bool dark) {
    final photo = driver?.profilePhotoUrl ?? profile?.docProfile;
    final driverName = driver?.fullName ??
        (trip.passengerName.isNotEmpty ? 'Assigned Driver' : 'Driver');
    final vehicle = ((profile?.vehicleType ?? trip.vehicleType).key == 'habal'
            ? 'Habal-Habal'
            : 'Tricycle')
        .toUpperCase();
    final plateNumber = profile?.plateNumber;
    final plate = plateNumber != null && plateNumber.isNotEmpty
        ? plateNumber
        : 'Plate available upon arrival';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(dark)),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: photo,
            name: driverName,
            avatarColorIndex: driver?.avatarColor ?? 0,
            radius: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$vehicle • $plate',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subtextColor(dark),
                  ),
                ),
              ],
            ),
          ),
          if (driver?.mobile != null && driver!.mobile.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.terracotta),
              tooltip: 'Call Driver',
              onPressed: () => _callPhone(driver.mobile),
            ),
            IconButton(
              icon: const Icon(Icons.sms, color: AppColors.terracotta),
              tooltip: 'Message Driver',
              onPressed: () => _smsPhone(driver.mobile),
            ),
          ],
        ],
      ),
    );
  }

  Widget _place(String title, String value, bool dark) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          title == 'Pickup' ? Icons.location_on : Icons.flag_rounded,
          color: title == 'Pickup' ? Colors.green : AppColors.terracotta,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textColor(dark),
          ),
        ),
        subtitle: Text(
          value.isEmpty ? 'Address unavailable' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.subtextColor(dark),
          ),
        ),
      );

  String _status(String value) => switch (RideStatus.normalize(value)) {
        RideStatus.searching => 'Waiting for driver response',
        RideStatus.accepted => 'Driver is on the way',
        RideStatus.arrived => 'Your driver has arrived',
        RideStatus.started => 'Trip in progress',
        RideStatus.completed => 'Ride completed',
        RideStatus.cancelled => 'Ride cancelled',
        _ => 'Ride status updating',
      };

  // ─── STATE SCREENS ──────────────────────────────────────────────────────────

  Widget _loadingScreen(bool dark) => Scaffold(
        backgroundColor: AppColors.canvasColor(dark),
        appBar: AppBar(
          title: const Text('Ride Tracking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.onNavigate(AppScreen.rides),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.terracotta,
              ),
              const SizedBox(height: 18),
              Text(
                'Loading your ride details...',
                style: TextStyle(
                  color: AppColors.textColor(dark),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _noActiveRideScreen(BuildContext context, AppUser user, bool dark) =>
      Scaffold(
        backgroundColor: AppColors.canvasColor(dark),
        appBar: AppBar(
          title: const Text('Ride Tracking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.onNavigate(
              user.isDriver ? AppScreen.driverHome : AppScreen.passengerHome,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    size: 44,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No active ride to track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have any ongoing or requested rides at the moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.subtextColor(dark),
                  ),
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => widget.onNavigate(
                    user.isDriver
                        ? AppScreen.driverHome
                        : AppScreen.passengerHome,
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label:
                      Text(user.isDriver ? 'Go to Dashboard' : 'Book a Ride'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _completedScreen(BuildContext context, Trip trip, bool dark) {
    final currentUser = AppState.instance.currentUser;
    final isPassenger = currentUser?.isDriver != true ||
        (trip.passengerId.isNotEmpty && currentUser?.id == trip.passengerId);
    if (isPassenger &&
        trip.rating == null &&
        _autoPromptedModalRideId != trip.id &&
        AppState.instance.shouldPromptRatingFor(trip.id)) {
      _autoPromptedModalRideId = trip.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(RateDriverModal.show(context, trip: trip));
      });
    }

    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      appBar: AppBar(
        title: const Text('Ride Completed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate(AppScreen.rides),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 46,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Ride Completed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have arrived at your destination.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.subtextColor(dark),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor(dark),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Fare Paid',
                                style: TextStyle(
                                    color: AppColors.subtextColor(dark),
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(FareCalculator.formatFare(trip.fare),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textColor(dark))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Distance',
                                style: TextStyle(
                                    color: AppColors.subtextColor(dark),
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                  '${trip.distanceKm.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textColor(dark))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (isPassenger && trip.rating == null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        RateDriverModal.show(context, trip: trip, force: true),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Rate Your Driver'),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => widget.onNavigate(AppScreen.rides),
                  icon: const Icon(Icons.history),
                  label: const Text('View Ride Activity'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cancelledScreen(BuildContext context, Trip trip, bool dark) =>
      Scaffold(
        backgroundColor: AppColors.canvasColor(dark),
        appBar: AppBar(
          title: const Text('Ride Cancelled'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.onNavigate(AppScreen.passengerHome),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ride Cancelled',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This ride request has been cancelled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.subtextColor(dark),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => widget.onNavigate(AppScreen.passengerHome),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Book Another Ride'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _unauthenticatedScreen(bool dark) => Scaffold(
        backgroundColor: AppColors.canvasColor(dark),
        appBar: AppBar(title: const Text('Ride Tracking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 48, color: AppColors.terracotta),
                const SizedBox(height: 16),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(dark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please sign in to track and view your rides.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtextColor(dark)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => widget.onNavigate(AppScreen.login),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _errorScreen(BuildContext context, Object? error, bool dark) {
    String title = 'Unable to Load Ride';
    String message =
        'We encountered an issue syncing your ride. Please try again.';
    IconData icon = Icons.cloud_off_rounded;

    if (error is AuthException) {
      if (error.code == 'permission-denied') {
        title = 'Access Verification';
        message =
            'Verifying permissions for this ride. Please ensure you are signed in to the account that booked the ride.';
        icon = Icons.security_rounded;
      } else if (error.code == 'failed-precondition') {
        title = 'Configuration Sync';
        message =
            'The ride database index is syncing. Please tap Retry in a few seconds.';
        icon = Icons.sync_problem_rounded;
      } else if (error.code == 'unavailable') {
        title = 'Connecting to Service';
        message =
            'Connecting to Sakay Ta live servers. Please check your signal and retry.';
        icon = Icons.wifi_off_rounded;
      } else if (error.code == 'unauthenticated') {
        title = 'Session Refresh';
        message = 'Please refresh your session to continue live tracking.';
        icon = Icons.person_off_rounded;
      }
    } else if (error is SocketException) {
      title = 'Network Offline';
      message = 'Check your connection. You can retry once connected.';
      icon = Icons.signal_cellular_connected_no_internet_4_bar_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.canvasColor(dark),
      appBar: AppBar(
        title: const Text('Ride Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate(AppScreen.rides),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: AppColors.terracotta),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(dark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.subtextColor(dark),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => widget.onNavigate(AppScreen.rides),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('My Rides'),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
