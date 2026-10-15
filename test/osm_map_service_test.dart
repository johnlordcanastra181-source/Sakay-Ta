import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/osm_map_service.dart';
import 'package:sakay_ta/state/passenger_search_bloc.dart';
import 'support/isolated_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useIsolatedDatabase);

  test('Unavailable search returns no fabricated landmark suggestions',
      () async {
    final osm = OsmMapService(
        httpClient: MockClient((_) async => http.Response('{}', 503)));
    expect(await osm.autocomplete('Unknown location'), isEmpty);
  });

  test('Unavailable routing returns no invented road geometry', () async {
    final osm = OsmMapService(
        httpClient: MockClient((_) async => http.Response('{}', 503)));
    expect(
        await osm.computeRoute(
            origin: const Geo(14.6, 121),
            destination: const Geo(14.61, 121.01)),
        isNull);
  });

  test('Search and routes use actual provider responses', () async {
    final osm = OsmMapService(httpClient: MockClient((request) async {
      if (request.url.path == '/search') {
        return http.Response(
            jsonEncode([
              {
                'lat': '14.61',
                'lon': '121.01',
                'place_id': 123,
                'name': 'Returned location',
                'display_name': 'Returned location, Manila',
                'address': {'city': 'Manila'}
              }
            ]),
            200);
      }
      return http.Response(
          jsonEncode({
            'routes': [
              {
                'distance': 2300,
                'duration': 480,
                'geometry': {
                  'coordinates': [
                    [121, 14.6],
                    [121.005, 14.605],
                    [121.01, 14.61]
                  ]
                }
              }
            ]
          }),
          200);
    }));
    final places = await osm.autocomplete('Returned location');
    expect(places.single.name, 'Returned location');
    expect(places.single.geo.lat, 14.61);
    final route = await osm.computeRoute(
        origin: const Geo(14.6, 121), destination: places.single.geo);
    expect(route!.distanceKm, 2.3);
    expect(route.durationMins, 8);
    expect(route.polylinePoints.length, 3);
  });

  test('Selecting a destination without GPS cannot create a route or booking',
      () async {
    final bloc = PassengerSearchBloc(detectLocation: false);
    addTearDown(bloc.dispose);
    bloc.add(SelectDestinationEvent(
        const Place('Actual destination', Geo(14.61, 121.01))));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.routePoints, isEmpty);
    expect(bloc.state.routeDistanceKm, 0);
    expect(await bloc.confirmSelectedBooking(), isFalse);
    bloc.add(ClearDestinationEvent());
    expect(bloc.state.selectedDestination, isNull);
  });
}
