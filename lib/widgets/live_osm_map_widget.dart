import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../core/constants.dart';
import '../services/driver_matching_service.dart';
import 'connectivity_banner.dart';

/// Interactive OpenStreetMap widget powered by flutter_map.
///
/// Features:
/// - Real-time Leaflet-equivalent OpenStreetMap tile rendering
/// - Live pulsing GPS location marker with continuous updates
/// - Dynamic destination marker with address popup
/// - Real-time nearby driver markers with tap-to-select
/// - OSRM road route polyline rendering with glow effect
/// - Recenter, Zoom In/Out, and Compass map controls
/// - Responsive layout suitable for mobile and desktop
class LiveOsmMapWidget extends StatefulWidget {
  const LiveOsmMapWidget({
    super.key,
    required this.passengerLocation,
    required this.currentAddress,
    this.destination,
    this.routePoints = const [],
    this.nearbyDrivers = const [],
    this.selectedDriver,
    this.isLocating = false,
    this.routeDistanceKm,
    this.routeDurationMins,
    this.onRecenter,
    this.onDriverSelected,
    this.onMapTap,
    this.trackingDriverLocation,
    this.trackingDriverName,
    this.trackingDriverVehicle,
    this.trackingPickup,
  });

  final Geo passengerLocation;
  final String currentAddress;
  final Place? destination;
  final List<Geo> routePoints;
  final List<NearbyDriver> nearbyDrivers;
  final NearbyDriver? selectedDriver;
  final bool isLocating;
  final double? routeDistanceKm;
  final int? routeDurationMins;
  final VoidCallback? onRecenter;
  final ValueChanged<NearbyDriver>? onDriverSelected;
  final ValueChanged<Geo>? onMapTap;
  final Geo? trackingDriverLocation;
  final String? trackingDriverName;
  final VehicleType? trackingDriverVehicle;
  final Geo? trackingPickup;

  @override
  State<LiveOsmMapWidget> createState() => _LiveOsmMapWidgetState();
}

class _LiveOsmMapWidgetState extends State<LiveOsmMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;

  // Track map camera animation state
  AnimationController? _cameraAnimController;
  bool _showDestinationPopup = true;

  ll.LatLng get _passengerLatLng => ll.LatLng(
        widget.passengerLocation.lat,
        widget.passengerLocation.lng,
      );

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant LiveOsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If destination changes, fit map to route bounds
    if (oldWidget.destination?.geo != widget.destination?.geo &&
        widget.destination != null) {
      _showDestinationPopup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitRouteBounds();
      });
    } else if (oldWidget.passengerLocation.lat !=
            widget.passengerLocation.lat ||
        oldWidget.passengerLocation.lng != widget.passengerLocation.lng) {
      // If only passenger location updated and no destination selected, keep centered
      if (widget.destination == null) {
        _animateCameraTo(_passengerLatLng, zoom: _mapController.camera.zoom);
      }
    }
  }

  @override
  void dispose() {
    _cameraAnimController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _animateCameraTo(ll.LatLng target, {double? zoom}) {
    _cameraAnimController?.dispose();
    final targetZoom = zoom ?? _mapController.camera.zoom;
    final startLatLng = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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

  void _fitRouteBounds() {
    final dest = widget.destination;
    if (dest == null) return;

    final points = widget.routePoints.isNotEmpty
        ? widget.routePoints.map((p) => ll.LatLng(p.lat, p.lng)).toList()
        : [
            _passengerLatLng,
            ll.LatLng(dest.geo.lat, dest.geo.lng),
          ];

    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Calculate approximate zoom level for bounds
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    
    // Shift the camera target South so the route is framed above the bottom sheet
    final adjustedCenterLat = centerLat - (latDiff * 0.25) - 0.002;
    final maxDiff = math.max(latDiff, lngDiff);

    double targetZoom = 15.0;
    if (maxDiff > 0.3) {
      targetZoom = 10.5;
    } else if (maxDiff > 0.15) {
      targetZoom = 12.0;
    } else if (maxDiff > 0.08) {
      targetZoom = 13.0;
    } else if (maxDiff > 0.04) {
      targetZoom = 14.0;
    } else if (maxDiff > 0.015) {
      targetZoom = 15.0;
    } else {
      targetZoom = 16.0;
    }

    _animateCameraTo(ll.LatLng(adjustedCenterLat, centerLng), zoom: targetZoom);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _animateCameraTo(_mapController.camera.center,
        zoom: math.min(18.5, currentZoom + 1.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _animateCameraTo(_mapController.camera.center,
        zoom: math.max(6.0, currentZoom - 1.0));
  }

  void _recenterToPassenger() {
    _animateCameraTo(_passengerLatLng, zoom: 16.0);
    widget.onRecenter?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Stack(
      children: [
        // Real-Time OpenStreetMap Tile Map
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _passengerLatLng,
              initialZoom: 15.5,
              minZoom: 5.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) {
                widget.onMapTap?.call(Geo(point.latitude, point.longitude));
              },
            ),
            children: [
              // OpenStreetMap Standard Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                retinaMode: false,
                keepBuffer: 1,
                panBuffer: 0,
                tileUpdateTransformer:
                    TileUpdateTransformers.throttle(const Duration(milliseconds: 120)),
                evictErrorTileStrategy: EvictErrorTileStrategy.none,
                userAgentPackageName: 'ph.sakayta.passenger',
                maxZoom: 19,
                subdomains: const ['a', 'b', 'c'],
              ),

              // Route Polylines (single crisp layer to minimize GPU overdraw on low-end phones)
              if (widget.destination != null &&
                  widget.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints
                          .map((p) => ll.LatLng(p.lat, p.lng))
                          .toList(),
                      color: const Color(0xFF2563EB),
                      strokeWidth: 5.0,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              // Interactive Markers Layer
              MarkerLayer(
                markers: [
                  // 1. Live Passenger GPS Marker (Blue Pulsing Dot)
                  Marker(
                    point: _passengerLatLng,
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    child: _buildPulsingGpsMarker(),
                  ),

                  if (widget.trackingPickup != null)
                    Marker(
                      point: ll.LatLng(widget.trackingPickup!.lat,
                          widget.trackingPickup!.lng),
                      width: 42,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin,
                          color: Color(0xFF2563EB), size: 42),
                    ),

                  if (widget.trackingDriverLocation != null)
                    Marker(
                      point: ll.LatLng(widget.trackingDriverLocation!.lat,
                          widget.trackingDriverLocation!.lng),
                      width: 150,
                      height: 62,
                      alignment: Alignment.bottomCenter,
                      child: _buildTrackingDriverMarker(),
                    ),

                  // 2. Destination Marker (Red Pin + Optional Popup)
                  if (widget.destination != null)
                    Marker(
                      point: ll.LatLng(
                        widget.destination!.geo.lat,
                        widget.destination!.geo.lng,
                      ),
                      width: 140,
                      height: 80,
                      alignment: Alignment.topCenter,
                      child: _buildDestinationMarker(widget.destination!),
                    ),

                  // 3. Nearby Drivers Markers (Tricycle & Habal-habal)
                  for (final driver in widget.nearbyDrivers)
                    Marker(
                      point:
                          ll.LatLng(driver.location.lat, driver.location.lng),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: _buildDriverMarker(driver),
                    ),
                ],
              ),
            ],
          ),
        ),

        // OpenStreetMap Attribution Badge
        Positioned(
          left: 12,
          bottom: 248,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ),

        // Offline / Sync Status Floating Pill (Top-Right)
        const Positioned(
          top: 16,
          right: 16,
          child: OfflineSyncPill(),
        ),

        // Current Location Status Chip (Bottom-Left)
        Positioned(
          left: 16,
          right: isDesktop ? null : 80,
          bottom: 278,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: widget.isLocating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2563EB),
                              ),
                            )
                          : const Icon(
                              Icons.gps_fixed_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YOUR CURRENT LOCATION',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.currentAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Route Summary Floating Capsule (When Route is Active)
        if (widget.destination != null &&
            widget.routeDistanceKm != null &&
            widget.routeDistanceKm! > 0)
          Positioned(
            top: 240,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2B45),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alt_route_rounded,
                        color: Color(0xFFFFD600), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.routeDistanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Icon(Icons.schedule_rounded,
                        color: Colors.white.withValues(alpha: 0.8), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '~${widget.routeDurationMins ?? 5} mins travel time',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Floating Map Interaction Controls (Recenter + Zoom)
        Positioned(
          right: 16,
          bottom: 278,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom In
              _buildFloatingButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onPressed: _zoomIn,
              ),
              const SizedBox(height: 8),

              // Zoom Out
              _buildFloatingButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out',
                onPressed: _zoomOut,
              ),
              const SizedBox(height: 12),

              // Recenter Current GPS Position
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: 'osm_current_location_fab',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  tooltip: 'Center to my GPS location',
                  onPressed: _recenterToPassenger,
                  child: widget.isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingDriverMarker() {
    final vehicle = widget.trackingDriverVehicle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              vehicle == VehicleType.habal
                  ? Icons.two_wheeler
                  : Icons.electric_rickshaw,
              color: Colors.white,
              size: 18),
          const SizedBox(width: 5),
          Flexible(
            child: Text(widget.trackingDriverName ?? 'Driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Static high-contrast GPS halo marker (zero idle 60 FPS GPU tick overhead)
  Widget _buildPulsingGpsMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  /// Red Destination Pin Marker with Address Callout Card
  Widget _buildDestinationMarker(Place destination) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showDestinationPopup = !_showDestinationPopup;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showDestinationPopup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                destination.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 2),
          // Red Map Pin
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Interactive Nearby Driver Pin (Tricycle / Habal-habal)
  Widget _buildDriverMarker(NearbyDriver driver) {
    final isSelected = widget.selectedDriver?.id == driver.id;
    final isTricycle = driver.vehicleType == VehicleType.tricycle;
    final bg = driver.isBookable ? (isTricycle ? const Color(0xFF15803D) : const Color(0xFFD97706)) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => widget.onDriverSelected?.call(driver),
      child: Opacity(
        opacity: driver.isBookable ? 1.0 : 0.6,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection Highlight Glow
          if (isSelected)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD600).withValues(alpha: 0.5),
                border: Border.all(color: const Color(0xFFFFD600), width: 2),
              ),
            ),
          // Driver Avatar Bubble
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFD600) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isTricycle ? '🛺' : '🏍️',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
        ),
        ),
      );
    }

    Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, color: const Color(0xFF334155), size: 20),
          ),
        ),
      ),
    );
  }
}
