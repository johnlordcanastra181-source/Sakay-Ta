import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../state/app_state.dart';
import 'connectivity_banner.dart';

/// Real-Time OpenStreetMap Card for the Driver Dashboard.
///
/// Features:
/// - Real-time Leaflet-equivalent OpenStreetMap tile rendering via flutter_map
/// - Continuous GPS tracking with live moving driver marker
/// - Top-left location chip with real reverse-geocoded address
/// - Bottom-right Recenter FAB
/// - OpenStreetMap attribution badge
/// - Complete permission, disabled GPS, loading, and error handling
class DriverOsmCard extends StatefulWidget {
  const DriverOsmCard({
    super.key,
    this.height = 190,
    this.isOnline = true,
  });

  final double height;
  final bool isOnline;

  @override
  State<DriverOsmCard> createState() => _DriverOsmCardState();
}

class _DriverOsmCardState extends State<DriverOsmCard>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  StreamSubscription<Position>? _positionSub;

  ll.LatLng _currentLatLng = const ll.LatLng(0, 0);
  String _currentAddress = 'Location unavailable';
  bool _isLocating = true;
  String? _locationError;
  bool _permissionDenied = false;
  bool _serviceDisabled = false;

  AnimationController? _cameraAnimController;
  late final AnimationController _pulseAnimController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseAnimController,
      curve: Curves.easeOut,
    );

    _initLocation();
  }

  @override
  void didUpdateWidget(covariant DriverOsmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline) {
        _startLiveTracking();
      } else {
        _stopLiveTracking();
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cameraAnimController?.dispose();
    _pulseAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
      _permissionDenied = false;
      _serviceDisabled = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _serviceDisabled = true;
            _isLocating = false;
            _locationError = 'GPS is disabled';
          });
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
          setState(() {
            _permissionDenied = true;
            _isLocating = false;
            _locationError = 'Location permission denied';
          });
        }
        return;
      }

      // Initial fix
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        _updatePosition(position, isInitial: true);
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _updatePosition(lastKnown, isInitial: true);
        } else {
          // A stored real position can be shown while waiting for GPS.
          final app = context.read<AppState>();
          final user = app.currentUser;
          if (user?.latitude != null && user?.longitude != null) {
            _currentLatLng = ll.LatLng(user!.latitude!, user.longitude!);
          }
          if (_currentLatLng.latitude != 0 || _currentLatLng.longitude != 0) {
            _resolveAddress(_currentLatLng);
          }
          if (mounted) {
            setState(() {
              _isLocating = false;
            });
          }
        }
      }

      if (widget.isOnline) {
        _startLiveTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationError = 'Unable to access GPS';
        });
      }
    }
  }

  void _startLiveTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      _updatePosition(position);
    }, onError: (Object e) {
      debugPrint('DriverOsmCard GPS stream error: $e');
    });
  }

  void _stopLiveTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _updatePosition(Position pos, {bool isInitial = false}) {
    final newLatLng = ll.LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _currentLatLng = newLatLng;
      _isLocating = false;
      _locationError = null;
      _permissionDenied = false;
      _serviceDisabled = false;
    });

    if (isInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(newLatLng, 15.5);
      });
    }

    _resolveAddress(newLatLng);

    // Broadcast update to backend
    context.read<AppState>().updateDriverLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
  }

  Future<void> _resolveAddress(ll.LatLng latLng) async {
    try {
      final app = context.read<AppState>();
      final address = await app.getAddressForLocation(
        Geo(latLng.latitude, latLng.longitude),
      );
      if (mounted && address.isNotEmpty) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (_) {}
  }

  void _recenterMap() {
    _animateCameraTo(_currentLatLng, zoom: 16.0);
  }

  void _animateCameraTo(ll.LatLng target, {double? zoom}) {
    _cameraAnimController?.dispose();
    final targetZoom = zoom ?? _mapController.camera.zoom;
    final startLatLng = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    final animation = CurvedAnimation(
      parent: _cameraAnimController!,
      curve: Curves.easeInOutCubic,
    );

    _cameraAnimController!.addListener(() {
      final t = animation.value;
      final lat =
          startLatLng.latitude + (target.latitude - startLatLng.latitude) * t;
      final lng = startLatLng.longitude +
          (target.longitude - startLatLng.longitude) * t;
      final z = startZoom + (targetZoom - startZoom) * t;
      _mapController.move(ll.LatLng(lat, lng), z);
    });

    _cameraAnimController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLatLng.latitude == 0 && _currentLatLng.longitude == 0) {
      return SizedBox(
          height: widget.height,
          child: Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isLocating
                  ? 'Detecting your location...'
                  : 'Location unavailable'),
              TextButton(
                  onPressed: _initLocation,
                  child: const Text('Detect location')),
            ],
          )));
    }
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // OpenStreetMap Real-Time Tile Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLatLng,
                initialZoom: 15.5,
                minZoom: 6.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ph.sakayta.driver',
                  maxZoom: 19,
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng,
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: _buildDriverMarker(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // OpenStreetMap Attribution (Required by OSM Terms)
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ),
          ),

          // Top-Left Location Chip (e.g. • Cebu IT Park)
          Positioned(
            top: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A), // Vibrant Green dot
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      _currentAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Offline / Low Connectivity status pill
          const Positioned(
            top: 10,
            right: 12,
            child: OfflineSyncPill(),
          ),

          // Bottom-Right Recenter FAB (Crosshair Icon)
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _recenterMap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 20,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ),
          ),

          // Handling permission denied / GPS disabled / error overlay
          if (_permissionDenied || _serviceDisabled)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _serviceDisabled
                          ? Icons.location_off_rounded
                          : Icons.location_disabled_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _locationError ??
                          (_serviceDisabled
                              ? 'Device GPS is disabled'
                              : 'Location permission needed'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E5600),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        if (_serviceDisabled) {
                          await Geolocator.openLocationSettings();
                        } else {
                          await Geolocator.openAppSettings();
                        }
                        _initLocation();
                      },
                      child: Text(
                        _serviceDisabled
                            ? 'Open GPS Settings'
                            : 'Grant Permission',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLocating)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Locating...',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse circle
            Container(
              width: 32 + (16 * _pulseAnimation.value),
              height: 32 + (16 * _pulseAnimation.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB)
                    .withValues(alpha: (1.0 - _pulseAnimation.value) * 0.4),
              ),
            ),
            // Solid center pin
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFFFFD600),
                  size: 15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
