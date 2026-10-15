import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

class MapView {
  final double latMin, latMax, lngMin, lngMax;

  const MapView(this.latMin, this.latMax, this.lngMin, this.lngMax);

  const MapView.forRoutes()
      : latMin = 10.28,
        latMax = 10.36,
        lngMin = 123.87,
        lngMax = 124.00;

  Offset project(Geo g, Size size, {double inset = 0}) {
    final x = (g.lng - lngMin) / (lngMax - lngMin) * size.width;
    final y = (latMax - g.lat) / (latMax - latMin) * size.height;
    return Offset(x, y);
  }
}

class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.driverProgress = 0,
    this.approaching = true,
    this.vehicleType = VehicleType.tricycle,
    this.myLocation,
    this.height = 280,
    this.showLabels = true,
  });

  final Geo pickup;
  final Geo dropoff;
  final double driverProgress;
  final bool approaching;
  final VehicleType vehicleType;
  final Geo? myLocation;
  final double height;
  final bool showLabels;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverProgress != widget.driverProgress ||
        oldWidget.approaching != widget.approaching) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = const MapView.forRoutes();
    final start = widget.approaching ? widget.pickup : widget.dropoff;
    final end = widget.approaching ? widget.pickup : widget.dropoff;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: MapEnginePainter(
            view: view,
            pickup: widget.pickup,
            dropoff: widget.dropoff,
            driverStart: start,
            driverEnd: end,
            approaching: widget.approaching,
            progress: _animation,
            vehicleType: widget.vehicleType,
            myLocation: widget.myLocation,
            showLabels: widget.showLabels,
          ),
        ),
      ),
    );
  }
}

class MapEnginePainter extends CustomPainter {
  MapEnginePainter({
    required this.view,
    required this.pickup,
    required this.dropoff,
    required this.driverStart,
    required this.driverEnd,
    required this.approaching,
    required this.progress,
    required this.vehicleType,
    this.myLocation,
    required this.showLabels,
  });

  final MapView view;
  final Geo pickup;
  final Geo dropoff;
  final Geo driverStart;
  final Geo driverEnd;
  final bool approaching;
  final Animation<double> progress;
  final VehicleType vehicleType;
  final Geo? myLocation;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBase(canvas, size);
    _drawRoads(canvas, size);
    _drawRoute(canvas, size);
    _drawDriver(canvas, size);
    _drawMarkers(canvas, size);
  }

  void _drawBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD8EEF0), Color(0xFFDCE8D8), Color(0xFFE8E2D2)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final block = Paint()
      ..color = Colors.white.withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 6; j++) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * j / 5 + 8,
            size.height * i / 4 + 8,
            size.width / 5 - 16,
            size.height / 4 - 16,
          ),
          block,
        );
      }
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final main = Paint()
      ..color = Colors.white.withValues(alpha: .95)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mainEdge = Paint()
      ..color = const Color(0xFFC7D9D4).withValues(alpha: .6)
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * .2)
      ..cubicTo(
        size.width * .25,
        size.height * .3,
        size.width * .22,
        size.height * .62,
        size.width * .52,
        size.height * .55,
      )
      ..cubicTo(
        size.width * .72,
        size.height * .5,
        size.width * .78,
        size.height * .3,
        size.width,
        size.height * .38,
      );
    canvas.drawPath(path, mainEdge);
    canvas.drawPath(path, main);

    final minor = Paint()
      ..color = Colors.white.withValues(alpha: .75)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final cross = [
      Path()
        ..moveTo(size.width * .3, 0)
        ..lineTo(size.width * .25, size.height),
      Path()
        ..moveTo(size.width * .62, 0)
        ..lineTo(size.width * .68, size.height),
      Path()
        ..moveTo(size.width * .9, 0)
        ..lineTo(size.width * .82, size.height),
      Path()
        ..moveTo(0, size.height * .7)
        ..lineTo(size.width, size.height * .75),
      Path()
        ..moveTo(0, size.height * .1)
        ..lineTo(size.width, size.height * .05),
    ];
    for (final p in cross) {
      canvas.drawPath(p, minor);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    final a = view.project(pickup, size);
    final b = view.project(dropoff, size);
    final mid = Offset(
      a.dx + (b.dx - a.dx) / 2,
      math.min(a.dy, b.dy) - 22,
    );
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);

    final glow = Paint()
      ..color = AppColors.terracotta.withValues(alpha: .28)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glow);

    final line = Paint()
      ..color = AppColors.terracotta
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
  }

  void _drawDriver(Canvas canvas, Size size) {
    final startPoint = view.project(driverStart, size);
    final endPoint = view.project(driverEnd, size);
    final dx = startPoint.dx + (endPoint.dx - startPoint.dx) * progress.value;
    final dy = startPoint.dy + (endPoint.dy - startPoint.dy) * progress.value;
    final center = Offset(dx, dy);

    final halo = Paint()..color = AppColors.green.withValues(alpha: .2);
    canvas.drawCircle(center, 20, halo);

    final markerRect = Rect.fromCenter(center: center, width: 34, height: 34);
    final rrect =
        RRect.fromRectAndRadius(markerRect, const Radius.circular(10));

    final shadow = Paint()..color = Colors.black.withValues(alpha: .15);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      shadow,
    );

    final fill = Paint()
      ..color = vehicleType == VehicleType.habal
          ? AppColors.terracotta
          : AppColors.green;
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: vehicleType == VehicleType.habal ? '🏍' : '🛺',
        style: const TextStyle(fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
        canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawMarkers(Canvas canvas, Size size) {
    if (myLocation != null) {
      final c = view.project(myLocation!, size);
      canvas.drawCircle(
        c,
        14,
        Paint()..color = Colors.blue.withValues(alpha: .25),
      );
      canvas.drawCircle(
        c,
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        c,
        8,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    _drawPin(
      canvas,
      size,
      view.project(pickup, size),
      AppColors.green,
      Icons.trip_origin_rounded,
    );
    _drawPin(
      canvas,
      size,
      view.project(dropoff, size),
      const Color(0xFFC2362B),
      Icons.location_on_rounded,
    );

    if (showLabels) {
      _drawLabel(canvas, size, 'Lahug, Cebu',
          Offset(size.width * .08, size.height * .12));
      _drawLabel(
          canvas, size, 'Mandaue', Offset(size.width * .66, size.height * .78));
    }
  }

  void _drawPin(
      Canvas canvas, Size size, Offset c, Color color, IconData icon) {
    canvas.drawCircle(
      c.translate(0, 26),
      20,
      Paint()..color = Colors.black.withValues(alpha: .12),
    );
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: 15))
      ..moveTo(c.dx, c.dy + 13)
      ..lineTo(c.dx - 7, c.dy + 26)
      ..lineTo(c.dx + 7, c.dy + 26)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawCircle(c, 6, Paint()..color = Colors.white);
    canvas.drawCircle(c, 3.4, Paint()..color = color);
  }

  void _drawLabel(Canvas canvas, Size size, String text, Offset c) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c);
  }

  @override
  bool shouldRepaint(covariant MapEnginePainter oldDelegate) => true;
}
