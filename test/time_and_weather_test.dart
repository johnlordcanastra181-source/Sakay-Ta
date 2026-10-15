import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/core/time_utils.dart';
import 'package:sakay_ta/services/database_service.dart';
import 'package:sakay_ta/services/weather_service.dart';
import 'package:sakay_ta/state/passenger_search_bloc.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.database;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimeGreeting Dynamic Time Detection Tests', () {
    test('5:00 AM returns Good Morning / Maayong Buntag', () {
      final morningTime = DateTime(2026, 8, 17, 5, 0);
      expect(TimeGreeting.getGreeting(time: morningTime), 'Good Morning');
      expect(
          TimeGreeting.getCebuanoGreeting(time: morningTime), 'Maayong Buntag');
      expect(TimeGreeting.getTagalogGreeting(time: morningTime),
          'Magandang Umaga');
    });

    test('11:59 AM returns Good Morning / Maayong Buntag', () {
      final lateMorningTime = DateTime(2026, 8, 17, 11, 59);
      expect(TimeGreeting.getGreeting(time: lateMorningTime), 'Good Morning');
      expect(TimeGreeting.getCebuanoGreeting(time: lateMorningTime),
          'Maayong Buntag');
      expect(TimeGreeting.getTagalogGreeting(time: lateMorningTime),
          'Magandang Umaga');
    });

    test('12:00 PM returns Good Afternoon / Maayong Hapon', () {
      final noonTime = DateTime(2026, 8, 17, 12, 0);
      expect(TimeGreeting.getGreeting(time: noonTime), 'Good Afternoon');
      expect(TimeGreeting.getCebuanoGreeting(time: noonTime), 'Maayong Hapon');
      expect(
          TimeGreeting.getTagalogGreeting(time: noonTime), 'Magandang Hapon');
    });

    test('5:59 PM (17:59) returns Good Afternoon / Maayong Hapon', () {
      final lateAfternoon = DateTime(2026, 8, 17, 17, 59);
      expect(TimeGreeting.getGreeting(time: lateAfternoon), 'Good Afternoon');
      expect(TimeGreeting.getCebuanoGreeting(time: lateAfternoon),
          'Maayong Hapon');
      expect(TimeGreeting.getTagalogGreeting(time: lateAfternoon),
          'Magandang Hapon');
    });

    test('6:00 PM (18:00) returns Good Evening / Maayong Gabi', () {
      final eveningTime = DateTime(2026, 8, 17, 18, 0);
      expect(TimeGreeting.getGreeting(time: eveningTime), 'Good Evening');
      expect(
          TimeGreeting.getCebuanoGreeting(time: eveningTime), 'Maayong Gabi');
      expect(
          TimeGreeting.getTagalogGreeting(time: eveningTime), 'Magandang Gabi');
    });

    test('11:30 PM (23:30) returns Good Evening / Maayong Gabi', () {
      final nightTime = DateTime(2026, 8, 17, 23, 30);
      expect(TimeGreeting.getGreeting(time: nightTime), 'Good Evening');
      expect(TimeGreeting.getCebuanoGreeting(time: nightTime), 'Maayong Gabi');
      expect(
          TimeGreeting.getTagalogGreeting(time: nightTime), 'Magandang Gabi');
    });

    test('4:59 AM (04:59) returns Good Evening / Maayong Gabi', () {
      final earlyMorningTime = DateTime(2026, 8, 17, 4, 59);
      expect(TimeGreeting.getGreeting(time: earlyMorningTime), 'Good Evening');
      expect(TimeGreeting.getCebuanoGreeting(time: earlyMorningTime),
          'Maayong Gabi');
      expect(TimeGreeting.getTagalogGreeting(time: earlyMorningTime),
          'Magandang Gabi');
    });

    test('getLocalizedGreeting selects correct language variant', () {
      final morning = DateTime(2026, 8, 17, 8, 0);
      expect(TimeGreeting.getLocalizedGreeting(localeCode: 'en', time: morning),
          'Good Morning');
      expect(
          TimeGreeting.getLocalizedGreeting(localeCode: 'ceb', time: morning),
          'Maayong Buntag');
      expect(TimeGreeting.getLocalizedGreeting(localeCode: 'tl', time: morning),
          'Magandang Umaga');
    });
  });

  group('WeatherService Real-Time Weather Tests', () {
    test('Weather values come from the provider response', () async {
      final service = WeatherService(
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'current': {
                  'temperature_2m': 30.2,
                  'weather_code': 0,
                  'is_day': 1
                }
              }),
              200)));
      final weather = await service.getWeather(const Geo(14.6, 121));
      expect(weather.temperatureC, 30.2);
      expect(weather.temperatureRounded, 30);
      expect(weather.condition, 'Clear');
    });

    test('Unavailable or incomplete weather cannot generate a default reading',
        () async {
      final unavailable = WeatherService(
          httpClient: MockClient((_) async => http.Response('{}', 503)));
      final incomplete = WeatherService(
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'current': {'weather_code': 0}
              }),
              200)));
      await expectLater(
          unavailable.getWeather(const Geo(14.6, 121)), throwsStateError);
      await expectLater(
          incomplete.getWeather(const Geo(14.6, 121)), throwsStateError);
    });
  });

  test('Weather remains unavailable before a real location is known', () async {
    final bloc = PassengerSearchBloc(detectLocation: false);
    addTearDown(bloc.dispose);
    bloc.add(RefreshWeatherEvent());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.weatherTemperatureLabel, 'Unavailable');
    expect(bloc.state.weatherLastUpdated, isNull);
    expect(bloc.state.cebuanoGreeting, isNotEmpty);
  });
}
