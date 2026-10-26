import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/core/constants.dart';
import 'package:sakay_ta/services/supabase/realtime_query.dart';
import 'package:sakay_ta/state/app_state.dart';
import 'package:sakay_ta/state/passenger_search_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Low connectivity resilience helpers', () {
    test(
      'approximateRoute computes deterministic road-adjusted distance and ETA when OSRM is unreachable',
      () {
        const origin = Geo(10.3157, 123.8854);
        const destination = Geo(10.3290, 123.9050);

        final straightKm = Geo.distanceKm(origin, destination);
        final route = approximateRoute(origin, destination);

        expect(route, isNotNull);
        expect(
          route!.distanceKm,
          closeTo(
            double.parse((straightKm * kApproximateRoadFactor).toStringAsFixed(2)),
            1e-6,
          ),
        );
        expect(route.distanceKm, greaterThan(straightKm));
        expect(route.durationMins, greaterThan(0));
        expect(route.polylinePoints.length, 2);
        expect(route.polylinePoints.first.lat, origin.lat);
        expect(route.polylinePoints.first.lng, origin.lng);
        expect(route.polylinePoints.last.lat, destination.lat);
        expect(route.polylinePoints.last.lng, destination.lng);
        expect(route.source, 'Approximate (offline)');
      },
    );

    test(
      'realtimeReconnectDelayMs uses exponential backoff capped at 20s and never stops reconnecting',
      () {
        expect(realtimeReconnectDelayMs(1), 1000);
        expect(realtimeReconnectDelayMs(2), 2000);
        expect(realtimeReconnectDelayMs(3), 4000);
        expect(realtimeReconnectDelayMs(4), 8000);
        expect(realtimeReconnectDelayMs(5), 16000);
        expect(realtimeReconnectDelayMs(6), 20000);
        expect(realtimeReconnectDelayMs(25), 20000);
      },
    );

    test(
      'isTransientNetworkError distinguishes weak-network drops from auth and business-rule errors',
      () {
        expect(
          isTransientNetworkError(
            Exception('SocketException: Failed host lookup: xyz.supabase.co'),
          ),
          isTrue,
        );
        expect(
          isTransientNetworkError(
            Exception('TimeoutException after 0:00:05.000000: Future not completed'),
          ),
          isTrue,
        );
        expect(
          isTransientNetworkError(
            Exception('ClientException with SocketException: Connection reset by peer'),
          ),
          isTrue,
        );
        expect(
          isTransientNetworkError(
            StateError('The active trip is no longer in progress.'),
          ),
          isFalse,
        );
        expect(
          isTransientNetworkError(
            const AuthException('Invalid JWT'),
          ),
          isFalse,
        );
        expect(
          isTransientNetworkError(
            Exception('PostgrestException: DRIVER_NOT_APPROVED'),
          ),
          isFalse,
        );
      },
    );
  });
}

