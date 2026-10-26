import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated startup splash screen matching the Sakay Ta HTML/CSS/SVG specification.
///
/// Displays for 3.5 seconds before smoothly fading and scaling out over 0.5 seconds
/// to transition into the main/home screen.
class SakayTaSplashScreen extends StatefulWidget {
  const SakayTaSplashScreen({
    super.key,
    required this.onFinished,
    this.displayDuration = const Duration(milliseconds: 1000),
    this.exitDuration = const Duration(milliseconds: 200),
  });

  final VoidCallback onFinished;
  final Duration displayDuration;
  final Duration exitDuration;

  @override
  State<SakayTaSplashScreen> createState() => _SakayTaSplashScreenState();
}

class _SakayTaSplashScreenState extends State<SakayTaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _totalSeconds;
  late final double _displaySeconds;
  late final double _exitSeconds;

  static const Color _navy = Color(0xFF172B53);
  static const Color _yellow = Color(0xFFF6C000);
  static const Color _cardBg = Color(0xFFF2F3F5);
  static const Color _smokeColor = Color(0xFFCBD5E1);

  static const Cubic _cardPopCubic = Cubic(0.34, 1.56, 0.64, 1.0);

  static const List<String> _titleChars = [
    'S',
    'a',
    'k',
    'a',
    'y',
    '\u00A0',
    'T',
    'a',
  ];

  @override
  void initState() {
    super.initState();
    _displaySeconds = widget.displayDuration.inMilliseconds / 1000.0;
    _exitSeconds = widget.exitDuration.inMilliseconds / 1000.0;
    _totalSeconds = _displaySeconds + _exitSeconds;

    _controller = AnimationController(
      vsync: this,
      duration: widget.displayDuration + widget.exitDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onFinished();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Symmetric 0 -> 1 -> 0 wave with CSS `ease-in-out` timing on each half-cycle.
  static double _easeInOutPingPong(double phase) {
    final normalized = phase - phase.floorToDouble();
    if (normalized <= 0.5) {
      return Curves.easeInOut.transform(normalized * 2.0);
    } else {
      return Curves.easeInOut.transform((1.0 - normalized) * 2.0);
    }
  }

  /// Asymmetric wave matching CSS `@keyframes waveText`:
  /// 0%, 100% -> 0.0; 40% -> 1.0 with `ease-in-out` per segment.
  static double _waveTextFactor(double elapsedSec, int charIndexOneBased) {
    final delay = charIndexOneBased * 0.1;
    if (elapsedSec < delay) return 0.0;
    final phase = ((elapsedSec - delay) % 1.8) / 1.8;
    if (phase <= 0.4) {
      return Curves.easeInOut.transform(phase / 0.4);
    } else {
      return Curves.easeInOut.transform((1.0 - phase) / 0.6);
    }
  }

  Widget _buildSmokePuff({
    required double elapsedSec,
    required double delaySec,
    required double size,
    required double left,
    required double top,
  }) {
    if (elapsedSec < delaySec) {
      return const SizedBox.shrink();
    }
    final phase = ((elapsedSec - delaySec) % 1.2) / 1.2;
    final curved = Curves.easeOut.transform(phase);
    final dx = -18.0 * curved;
    final dy = -12.0 * curved;
    final scale = 0.5 + (1.6 - 0.5) * curved;
    final opacity = (0.7 * (1.0 - curved)).clamp(0.0, 1.0);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: _smokeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onFinished,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * _totalSeconds;

            // 1. cardPop (0.0s .. 0.5s, cubic-bezier(0.34, 1.56, 0.64, 1))
            // Keep opacity at 1.0 from Frame #1 so the moving card appears
            // instantaneously on app launch without any blank white flash.
            double cardScale = 1.0;
            double cardOpacity = 1.0;
            if (t < 0.5) {
              final popProgress = (t / 0.5).clamp(0.0, 1.0);
              final popCurved = _cardPopCubic.transform(popProgress);
              cardScale = 0.82 + 0.18 * popCurved;
            }

            // 2. cardFloat (starts at 0.6s, 3.0s period, ease-in-out infinite)
            double cardFloatY = 0.0;
            if (t >= 0.6) {
              final floatWave = _easeInOutPingPong((t - 0.6) / 3.0);
              cardFloatY = -8.0 * floatWave;
            }

            // 3. Exit transition at 3.5s (0.5s ease: opacity -> 0, scale -> 0.9)
            if (t >= _displaySeconds && _exitSeconds > 0) {
              final exitProgress =
                  ((t - _displaySeconds) / _exitSeconds).clamp(0.0, 1.0);
              final exitCurved = Curves.ease.transform(exitProgress);
              cardOpacity *= (1.0 - exitCurved).clamp(0.0, 1.0);
              cardScale *= (1.0 - 0.1 * exitCurved);
            }

            // 4. pinBounce & shadowPulse (2.0s period, ease-in-out infinite)
            final pinWave = _easeInOutPingPong(t / 2.0);
            final pinBounceY = -6.0 * pinWave;
            final shadowScale = 1.0 - 0.25 * pinWave;
            final shadowOpacity = 0.20 - 0.10 * pinWave;

            // 5. engineVibrate (0.35s alternate -> 0.70s full cycle, ease-in-out)
            final engineWave = _easeInOutPingPong(t / 0.70);
            final trikeTranslateY = -1.8 * engineWave;
            final trikeRotateRad = (-0.8 * math.pi / 180.0) * engineWave;

            // 6. wheelSpin (1.2s linear infinite)
            final wheelAngleRad = ((t % 1.2) / 1.2) * 2.0 * math.pi;

            return Opacity(
              opacity: cardOpacity,
              child: Transform.translate(
                offset: Offset(0, cardFloatY),
                child: Transform.scale(
                  scale: cardScale,
                  child: Container(
                    key: const Key('sakay_ta_splash_card'),
                    width: 205,
                    height: 210,
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(23, 43, 83, 0.08),
                          offset: Offset(0, 12),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // .pin-container (112 x 112)
                        Transform.translate(
                          offset: Offset(0, pinBounceY),
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _SakayTaSplashLogoPainter(
                                      trikeTranslateY: trikeTranslateY,
                                      trikeRotateRad: trikeRotateRad,
                                      wheelAngleRad: wheelAngleRad,
                                    ),
                                  ),
                                ),
                                // .puff-1: width 10, height 10, left 18, top 62, 1.2s
                                _buildSmokePuff(
                                  elapsedSec: t,
                                  delaySec: 0.0,
                                  size: 10,
                                  left: 18,
                                  top: 62,
                                ),
                                // .puff-2: width 14, height 14, left 10, top 58, 1.2s, delay 0.4s
                                _buildSmokePuff(
                                  elapsedSec: t,
                                  delaySec: 0.4,
                                  size: 14,
                                  left: 10,
                                  top: 58,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // .pin-shadow (width 68, height 11, margin-top -6, margin-bottom 10)
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: Transform.scale(
                            scale: shadowScale,
                            child: Container(
                              width: 68,
                              height: 11,
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: shadowOpacity),
                                borderRadius: const BorderRadius.all(
                                  Radius.elliptical(34, 5.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // .app-title ("Sakay Ta" waving letters)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  List.generate(_titleChars.length, (index) {
                                final wave = _waveTextFactor(t, index + 1);
                                final charY = -6.0 * wave;
                                final charColor =
                                    Color.lerp(_navy, _yellow, wave) ?? _navy;
                                return Transform.translate(
                                  offset: Offset(0, charY),
                                  child: Text(
                                    _titleChars[index],
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 27,
                                      fontWeight: FontWeight.w700,
                                      color: charColor,
                                      letterSpacing: 0.3,
                                      height: 1.1,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}

class _SakayTaSplashLogoPainter extends CustomPainter {
  const _SakayTaSplashLogoPainter({
    required this.trikeTranslateY,
    required this.trikeRotateRad,
    required this.wheelAngleRad,
  });

  final double trikeTranslateY;
  final double trikeRotateRad;
  final double wheelAngleRad;

  static const Color _navy = Color(0xFF172B53);
  static const Color _yellow = Color(0xFFF6C000);

  @override
  void paint(Canvas canvas, Size size) {
    // Match <svg viewBox="0 0 120 120" width="100%" height="100%">
    final scaleX = size.width / 120.0;
    final scaleY = size.height / 120.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final navyFill = Paint()
      ..color = _navy
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final yellowFill = Paint()
      ..color = _yellow
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final yellowStroke = Paint()
      ..color = _yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..isAntiAlias = true;

    // 1. Dark Blue Map Pin
    // <circle cx="60" cy="56" r="46" fill="#172b53" />
    canvas.drawCircle(const Offset(60, 56), 46, navyFill);

    // <polygon points="44,96 76,96 60,111" fill="#172b53" />
    final pinTip = Path()
      ..moveTo(44, 96)
      ..lineTo(76, 96)
      ..lineTo(60, 111)
      ..close();
    canvas.drawPath(pinTip, navyFill);

    // 2. Yellow Tricycle (.trike-body)
    canvas.save();
    canvas.translate(0, trikeTranslateY);
    canvas.rotate(trikeRotateRad);

    // <path d="M32 52 C32 37, 42 35, 62 35 L78 35 C83 35, 86 39, 88 46 L93 62 L85 62 L81 44 L66 44 L66 64 L85 64 L85 71 L32 71 Z" fill="#f6c000"/>
    final trikeShell = Path()
      ..moveTo(32, 52)
      ..cubicTo(32, 37, 42, 35, 62, 35)
      ..lineTo(78, 35)
      ..cubicTo(83, 35, 86, 39, 88, 46)
      ..lineTo(93, 62)
      ..lineTo(85, 62)
      ..lineTo(81, 44)
      ..lineTo(66, 44)
      ..lineTo(66, 64)
      ..lineTo(85, 64)
      ..lineTo(85, 71)
      ..lineTo(32, 71)
      ..close();
    canvas.drawPath(trikeShell, yellowFill);

    // <path d="M40 42 L59 42 L59 56 L38 56 Z" fill="#172b53"/>
    final trikeWindow = Path()
      ..moveTo(40, 42)
      ..lineTo(59, 42)
      ..lineTo(59, 56)
      ..lineTo(38, 56)
      ..close();
    canvas.drawPath(trikeWindow, navyFill);

    // <path d="M72 48 L82 48 L88 68 L80 68 Z" fill="#f6c000"/>
    final trikeFork = Path()
      ..moveTo(72, 48)
      ..lineTo(82, 48)
      ..lineTo(88, 68)
      ..lineTo(80, 68)
      ..close();
    canvas.drawPath(trikeFork, yellowFill);

    // <path d="M82 62 Q92 60 95 68 L82 68 Z" fill="#f6c000"/>
    final trikeFender = Path()
      ..moveTo(82, 62)
      ..quadraticBezierTo(92, 60, 95, 68)
      ..lineTo(82, 68)
      ..close();
    canvas.drawPath(trikeFender, yellowFill);

    canvas.restore();

    // 3. Likod na Gulong (Rear Wheel at cx="44" cy="72")
    _drawWheel(
      canvas,
      center: const Offset(44, 72),
      navyFill: navyFill,
      yellowFill: yellowFill,
      yellowStroke: yellowStroke,
    );

    // 4. Harap na Gulong (Front Wheel at cx="84" cy="72")
    _drawWheel(
      canvas,
      center: const Offset(84, 72),
      navyFill: navyFill,
      yellowFill: yellowFill,
      yellowStroke: yellowStroke,
    );

    canvas.restore();
  }

  void _drawWheel(
    Canvas canvas, {
    required Offset center,
    required Paint navyFill,
    required Paint yellowFill,
    required Paint yellowStroke,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(wheelAngleRad);
    canvas.drawCircle(Offset.zero, 10, navyFill);
    canvas.drawCircle(Offset.zero, 10, yellowStroke);
    canvas.drawCircle(Offset.zero, 2.5, yellowFill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SakayTaSplashLogoPainter oldDelegate) {
    return oldDelegate.trikeTranslateY != trikeTranslateY ||
        oldDelegate.trikeRotateRad != trikeRotateRad ||
        oldDelegate.wheelAngleRad != wheelAngleRad;
  }
}

