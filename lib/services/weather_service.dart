import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// Real-time weather data model.
class WeatherInfo {
  final double temperatureC;
  final int temperatureRounded;
  final String condition;
  final String emoji;
  final int weatherCode;
  final bool isDay;
  final DateTime lastUpdated;

  const WeatherInfo({
    required this.temperatureC,
    required this.temperatureRounded,
    required this.condition,
    required this.emoji,
    required this.weatherCode,
    required this.isDay,
    required this.lastUpdated,
  });

  /// Combined formatted string, e.g. "☀️ Clear / Fair"
  String get displayCondition => '$emoji $condition';
}

/// Service to fetch real-time weather information based on GPS location.
///
/// Uses Open-Meteo open weather forecasting service (free, reliable, global coverage, no API key required).
class WeatherService {
  WeatherService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  static final WeatherService instance = WeatherService();
  final http.Client _client;

  static const String _host = 'api.open-meteo.com';
  static const Duration _timeout = Duration(seconds: 8);

  // In-memory cache: key = rounded lat_lng, value = cached weather + timestamp
  final Map<String, _CachedWeather> _cache = {};

  /// Fetches real-time weather for the given [location].
  Future<WeatherInfo> getWeather(Geo location) async {
    final cacheKey =
        '${location.lat.toStringAsFixed(2)}_${location.lng.toStringAsFixed(2)}';
    final now = DateTime.now();

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      // Cache valid for 15 minutes
      if (now.difference(cached.timestamp).inMinutes < 15) {
        return cached.weather;
      }
    }

    try {
      final uri = Uri.https(_host, '/v1/forecast', {
        'latitude': location.lat.toString(),
        'longitude': location.lng.toString(),
        'current': 'temperature_2m,weather_code,is_day',
      });

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('WeatherService error: status ${response.statusCode}');
        return _fallbackFor(location);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) {
        return _fallbackFor(location);
      }

      final temp = (current['temperature_2m'] as num?)?.toDouble();
      if (temp == null ||
          current['weather_code'] == null ||
          current['is_day'] == null) {
        return _fallbackFor(location);
      }
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final isDay = (current['is_day'] as num?)?.toInt() != 0;

      final (condition, emoji) = _interpretWmoCode(code, isDay);

      final weather = WeatherInfo(
        temperatureC: temp,
        temperatureRounded: temp.round(),
        condition: condition,
        emoji: emoji,
        weatherCode: code,
        isDay: isDay,
        lastUpdated: now,
      );

      _cache[cacheKey] = _CachedWeather(weather: weather, timestamp: now);
      return weather;
    } catch (e) {
      debugPrint('WeatherService fetch exception: $e');
      return _fallbackFor(location);
    }
  }

  /// Map standard WMO weather codes to human-readable labels and emojis.
  (String, String) _interpretWmoCode(int code, bool isDay) {
    return switch (code) {
      0 => isDay ? ('Clear', '☀️') : ('Clear Night', '🌙'),
      1 => isDay ? ('Mainly Clear', '🌤️') : ('Mainly Clear', '🌙'),
      2 => ('Partly Cloudy', '⛅'),
      3 => ('Overcast', '☁️'),
      45 || 48 => ('Foggy', '🌫️'),
      51 || 53 || 55 => ('Drizzle', '🌦️'),
      56 || 57 => ('Freezing Drizzle', '🌧️'),
      61 => ('Light Rain', '🌦️'),
      63 => ('Moderate Rain', '🌧️'),
      65 => ('Heavy Rain', '🌧️'),
      66 || 67 => ('Freezing Rain', '🌧️'),
      71 || 73 || 75 => ('Snow', '🌨️'),
      77 => ('Snow Grains', '🌨️'),
      80 || 81 || 82 => ('Rain Showers', '🌦️'),
      85 || 86 => ('Snow Showers', '🌨️'),
      95 => ('Thunderstorm', '⛈️'),
      96 || 99 => ('Thunderstorm w/ Hail', '⛈️'),
      _ => ('Fair', isDay ? '☀️' : '🌙'),
    };
  }

  WeatherInfo _fallbackFor(Geo location) {
    final cacheKey =
        '${location.lat.toStringAsFixed(2)}_${location.lng.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.weather;
    }
    final now = DateTime.now();
    final hour = now.hour;
    final isDay = hour >= 6 && hour < 18;
    return WeatherInfo(
      temperatureC: 29.0,
      temperatureRounded: 29,
      condition: isDay ? 'Fair' : 'Clear Night',
      emoji: isDay ? '🌤️' : '🌙',
      weatherCode: 1,
      isDay: isDay,
      lastUpdated: now,
    );
  }
}

class _CachedWeather {
  final WeatherInfo weather;
  final DateTime timestamp;

  const _CachedWeather({required this.weather, required this.timestamp});
}
