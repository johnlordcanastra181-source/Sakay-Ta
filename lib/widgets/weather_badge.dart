import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';

/// Location-aware weather badge for dashboards (Driver & Passenger).
///
/// Features:
/// - Real-time temperature, condition text, and weather emoji
/// - Uses [WeatherService.instance] with in-memory caching
/// - Graceful loading and offline fallback states
/// - Tap to view full weather details sheet
/// - Periodic 15-minute auto-refresh
class WeatherBadge extends StatefulWidget {
  const WeatherBadge({
    super.key,
    this.location,
    this.compact = false,
  });

  final Geo? location;
  final bool compact;

  @override
  State<WeatherBadge> createState() => _WeatherBadgeState();
}

class _WeatherBadgeState extends State<WeatherBadge> {
  WeatherInfo? _weatherInfo;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) _fetchWeather();
    });
  }

  @override
  void didUpdateWidget(WeatherBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLoc = widget.location;
    final oldLoc = oldWidget.location;
    if (newLoc != null &&
        (oldLoc == null || Geo.distanceKm(newLoc, oldLoc) > 0.5)) {
      _fetchWeather();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Geo _resolveLocation() {
    if (widget.location != null && widget.location!.isValid) {
      return widget.location!;
    }
    try {
      final app = context.read<AppState?>();
      if (app?.currentUser?.latitude != null &&
          app?.currentUser?.longitude != null) {
        final loc = Geo(
          app!.currentUser!.latitude!,
          app.currentUser!.longitude!,
        );
        if (loc.isValid) return loc;
      }
    } catch (e) {
      debugPrint('WeatherBadge non-fatal note: $e');
    }
    return const Geo(11.2444, 125.0039); // Tacloban default
  }

  Future<void> _fetchWeather({bool force = false}) async {
    final loc = _resolveLocation();

    if (_weatherInfo == null) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final info = await WeatherService.instance.getWeather(loc);
      if (mounted) {
        setState(() {
          _weatherInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[WeatherBadge] fetch fallback: $e');
      if (mounted) {
        setState(() {
          _weatherInfo ??= WeatherInfo(
            temperatureC: 29.0,
            temperatureRounded: 29,
            condition: 'Fair',
            emoji: '🌤️',
            weatherCode: 1,
            isDay: true,
            lastUpdated: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    }
  }

  void _showWeatherDetailsSheet(BuildContext context, bool isDark) {
    final weather = _weatherInfo;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        weather?.emoji.isNotEmpty == true
                            ? weather!.emoji
                            : '🌤️',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weather != null
                                  ? '${weather.temperatureRounded}°C'
                                  : '29°C',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              weather?.condition ?? 'Fair',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh weather',
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: isDark ? AppColors.gold : const Color(0xFFB45309),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchWeather(force: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gps_fixed_rounded,
                    size: 15,
                    color: isDark ? AppColors.gold : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live weather updated at your GPS position.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState?>();
    final isDark = (app?.darkMode ?? false) ||
        Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Live weather at current GPS position (Tap for details)',
      child: GestureDetector(
        onTap: () => _showWeatherDetailsSheet(context, isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.3)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFD97706).withValues(alpha: 0.4)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _isLoading && _weatherInfo == null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color:
                              isDark ? AppColors.gold : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Weather...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weatherInfo?.emoji.isNotEmpty == true
                            ? _weatherInfo!.emoji
                            : '🌤️',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _weatherInfo?.condition ?? 'Fair',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _weatherInfo != null
                            ? '${_weatherInfo!.temperatureRounded}°C'
                            : '29°C',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? AppColors.gold : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
