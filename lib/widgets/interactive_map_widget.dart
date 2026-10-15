import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/driver_matching_service.dart';

class InteractiveMapWidget extends StatefulWidget {
  const InteractiveMapWidget({
    super.key,
    required this.passengerLocation,
    required this.currentAddress,
    this.destination,
    this.nearbyDrivers = const [],
    this.selectedDriver,
    this.routePolyline = true,
    this.zoomLevel = 14.0,
    this.showWatermark = false,
    this.onRecenter,
    this.onDriverSelected,
  });

  final Geo passengerLocation;
  final String currentAddress;
  final Place? destination;
  final List<NearbyDriver> nearbyDrivers;
  final NearbyDriver? selectedDriver;
  final bool routePolyline;
  final double zoomLevel;
  final bool showWatermark;
  final VoidCallback? onRecenter;
  final Function(NearbyDriver)? onDriverSelected;

  @override
  State<InteractiveMapWidget> createState() => _InteractiveMapWidgetState();
}

class _InteractiveMapWidgetState extends State<InteractiveMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  double _zoomLevel = 14.0;
  Offset _mapOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoomLevel = widget.zoomLevel;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = math.min(18.0, _zoomLevel + 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = math.max(8.0, _zoomLevel - 1.0);
    });
  }

  void _recenterMap() {
    setState(() {
      _zoomLevel = widget.zoomLevel;
      _mapOffset = Offset.zero;
    });
    if (widget.onRecenter != null) widget.onRecenter!();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      width: double.infinity,
      child: Stack(
        children: [
          // Gesture Detector for Panning
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _mapOffset += details.delta;
              });
            },
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: CustomInteractiveMapPainter(
                    passengerLocation: widget.passengerLocation,
                    destination: widget.destination,
                    nearbyDrivers: widget.nearbyDrivers,
                    selectedDriver: widget.selectedDriver,
                    pulseValue: _pulseAnimation.value,
                    zoomLevel: _zoomLevel,
                    mapOffset: _mapOffset,
                    showWatermark: widget.showWatermark,
                  ),
                );
              },
            ),
          ),

          // Top Header Bar: Reverse Geocoding Address & Driver Count Badge
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Reverse Geocoded Address Label
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Color(0xFF6E5600), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.currentAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Real-time Available Driver Counter Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2B45),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.nearbyDrivers.length} Drivers',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Zoom Controls & Re-Center Button on Right Side
          Positioned(
            right: 16,
            top: 70,
            child: Column(
              children: [
                _buildMapControlButton(
                  icon: Icons.add_rounded,
                  onTap: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.remove_rounded,
                  onTap: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 12),
                _buildMapControlButton(
                  icon: Icons.my_location_rounded,
                  iconColor: const Color(0xFF6E5600),
                  onTap: _recenterMap,
                  tooltip: 'Re-center Location',
                ),
              ],
            ),
          ),

          // Watermark Banner when Map Exporting is Active
          if (widget.showWatermark)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sakay Ta Ride Hailing Super App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Exported: ${DateTime.now().toString().split('.').first}',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF404040),
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class CustomInteractiveMapPainter extends CustomPainter {
  final Geo passengerLocation;
  final Place? destination;
  final List<NearbyDriver> nearbyDrivers;
  final NearbyDriver? selectedDriver;
  final double pulseValue;
  final double zoomLevel;
  final Offset mapOffset;
  final bool showWatermark;

  CustomInteractiveMapPainter({
    required this.passengerLocation,
    this.destination,
    required this.nearbyDrivers,
    this.selectedDriver,
    required this.pulseValue,
    required this.zoomLevel,
    required this.mapOffset,
    required this.showWatermark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackgroundTiles(canvas, size);
    _drawRoadNetwork(canvas, size);

    if (destination != null) {
      _drawRoutePolyline(canvas, size);
    }

    _drawPassengerPulsingLocation(canvas, size);
    _drawNearbyDriverMarkers(canvas, size);

    if (destination != null) {
      _drawDestinationMarker(canvas, size);
    }
  }

  void _drawBackgroundTiles(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Clean realistic map tile background gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: zoomLevel < 11
          ? [
              const Color(0xFFC7E2E4),
              const Color(0xFFD6E8D5),
              const Color(0xFFE8E5D8)
            ]
          : [
              const Color(0xFFE4F1F2),
              const Color(0xFFEDF5EC),
              const Color(0xFFF7F5EC)
            ],
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Draw grid block pattern for urban layout
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const gridSize = 60.0;
    for (double x = (mapOffset.dx % gridSize); x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = (mapOffset.dy % gridSize); y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawRoadNetwork(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = math.max(4.0, zoomLevel * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final highwayPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85)
      ..strokeWidth = math.max(6.0, zoomLevel * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2) + mapOffset;

    // Primary Highway curve
    final mainHighway = Path()
      ..moveTo(c.dx - size.width * 0.6, c.dy - size.height * 0.3)
      ..quadraticBezierTo(
          c.dx, c.dy - 40, c.dx + size.width * 0.6, c.dy + size.height * 0.4);

    canvas.drawPath(mainHighway, highwayPaint);

    // Connecting roads
    final road1 = Path()
      ..moveTo(c.dx - size.width * 0.4, c.dy + size.height * 0.5)
      ..lineTo(c.dx + size.width * 0.5, c.dy - size.height * 0.5);

    final road2 = Path()
      ..moveTo(c.dx - size.width * 0.5, c.dy - 60)
      ..lineTo(c.dx + size.width * 0.5, c.dy + 80);

    canvas.drawPath(road1, roadPaint);
    canvas.drawPath(road2, roadPaint);
  }

  Offset _projectGeoToOffset(Geo geo, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + mapOffset;
    final deltaLat = (geo.lat - passengerLocation.lat);
    final deltaLng = (geo.lng - passengerLocation.lng);

    final scale = math.pow(1.8, zoomLevel - 10) * 120.0;
    final x = center.dx + deltaLng * scale;
    final y = center.dy - deltaLat * scale;
    return Offset(x, y);
  }

  void _drawRoutePolyline(Canvas canvas, Size size) {
    final start = _projectGeoToOffset(passengerLocation, size);
    final end = _projectGeoToOffset(destination!.geo, size);

    final mid =
        Offset((start.dx + end.dx) / 2, math.min(start.dy, end.dy) - 30);

    final routePath = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);

    // Route Outer Glow
    final glowPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.3)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Route Core Line
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(routePath, glowPaint);
    canvas.drawPath(routePath, linePaint);
  }

  void _drawPassengerPulsingLocation(Canvas canvas, Size size) {
    final center = _projectGeoToOffset(passengerLocation, size);

    // Outer Pulsing Circle
    final pulseRadius = 18.0 * pulseValue;
    final pulsePaint = Paint()
      ..color = const Color(0xFF2563EB)
          .withValues(alpha: math.max(0.05, 0.4 - (pulseValue - 0.8) * 0.5))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // White Ring
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Blue Core Dot
    canvas.drawCircle(
      center,
      6.5,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawNearbyDriverMarkers(Canvas canvas, Size size) {
    for (final driver in nearbyDrivers) {
      final pos = _projectGeoToOffset(driver.location, size);
      final isTricycle = driver.vehicleType == VehicleType.tricycle;
      final isSelected = selectedDriver?.id == driver.id;

      final markerColor =
          isTricycle ? const Color(0xFF2D6A4F) : const Color(0xFFD97706);

      // Selected Driver Glow Ring
      if (isSelected) {
        canvas.drawCircle(
          pos,
          22,
          Paint()..color = const Color(0xFFFFD600).withValues(alpha: 0.5),
        );
      }

      // Rounded Marker Box
      final markerRect = Rect.fromCenter(center: pos, width: 34, height: 34);
      final rrect =
          RRect.fromRectAndRadius(markerRect, const Radius.circular(10));

      // Shadow
      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.15),
      );

      // Marker Background
      canvas.drawRRect(rrect, Paint()..color = markerColor);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      // Vehicle Emoji Icon inside
      final iconText = isTricycle ? '🛺' : '🏍️';
      final textPainter = TextPainter(
        text: TextSpan(text: iconText, style: const TextStyle(fontSize: 16)),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawDestinationMarker(Canvas canvas, Size size) {
    final pos = _projectGeoToOffset(destination!.geo, size);

    // Destination Pin (Red)
    canvas.drawCircle(
      pos.translate(0, 20),
      16,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    final path = Path()
      ..addOval(Rect.fromCircle(center: pos, radius: 14))
      ..moveTo(pos.dx, pos.dy + 12)
      ..lineTo(pos.dx - 6, pos.dy + 24)
      ..lineTo(pos.dx + 6, pos.dy + 24)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFDC2626));
    canvas.drawCircle(pos, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomInteractiveMapPainter oldDelegate) => true;
}
