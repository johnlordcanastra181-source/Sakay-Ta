import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum ConnectionQuality {
  online,
  intermittent,
  offline,
}

class ConnectivityService {
  ConnectivityService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final Connectivity _connectivity = Connectivity();
  final http.Client _client;
  final StreamController<ConnectionQuality> _qualityController =
      StreamController<ConnectionQuality>.broadcast();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  ConnectionQuality _quality = ConnectionQuality.online;
  bool _isOnline = true;
  Timer? _heartbeatTimer;
  DateTime? _lastChecked;
  int _consecutiveFailures = 0;

  Stream<bool> get onChanged => _controller.stream;
  Stream<ConnectionQuality> get onQualityChanged => _qualityController.stream;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isIntermittent => _quality == ConnectionQuality.intermittent;
  ConnectionQuality get quality => _quality;
  DateTime? get lastChecked => _lastChecked;

  static const List<String> _healthCheckUrls = [
    'https://www.google.com/generate_204',
    'https://1.1.1.1',
    'https://httpbin.org/status/204',
  ];

  Future<void> init() async {
    _connectivity.onConnectivityChanged.listen((results) async {
      final hasAdapter = results.any((r) => r != ConnectivityResult.none);
      if (!hasAdapter) {
        _updateState(ConnectionQuality.offline);
      } else {
        await checkRealConnectivity();
      }
    });

    try {
      final results = await _connectivity.checkConnectivity();
      final hasAdapter = results.any((r) => r != ConnectivityResult.none);
      if (!hasAdapter) {
        _updateState(ConnectionQuality.offline);
      } else {
        await checkRealConnectivity();
      }
    } catch (_) {
      _updateState(ConnectionQuality.online);
    }

    // Periodic heartbeat every 20s to detect silent dropouts / recovery in low signal areas
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await checkRealConnectivity();
    });
  }

  /// Performs an active probe with short timeout to detect real internet throughput
  Future<ConnectionQuality> checkRealConnectivity() async {
    _lastChecked = DateTime.now();
    try {
      final adapterResults = await _connectivity.checkConnectivity();
      final hasAdapter =
          adapterResults.any((r) => r != ConnectivityResult.none);
      if (!hasAdapter) {
        _consecutiveFailures = 2;
        _updateState(ConnectionQuality.offline);
        return ConnectionQuality.offline;
      }

      final stopwatch = Stopwatch()..start();
      bool reached = false;

      // Try fast ping endpoints with 2.5 second timeout
      for (final url in _healthCheckUrls) {
        try {
          final res = await _client
              .get(Uri.parse(url))
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode >= 200 && res.statusCode < 400) {
            reached = true;
            break;
          }
        } catch (_) {
          continue;
        }
      }
      stopwatch.stop();

      if (reached) {
        _consecutiveFailures = 0;
        final elapsedMs = stopwatch.elapsedMilliseconds;
        // If ping latency > 1800ms, mark as intermittent (slow/unstable network)
        final quality = elapsedMs > 1800
            ? ConnectionQuality.intermittent
            : ConnectionQuality.online;
        _updateState(quality);
        return quality;
      } else {
        _consecutiveFailures++;
        // If 1 failure: intermittent; 2+ failures: offline
        final quality = _consecutiveFailures >= 2
            ? ConnectionQuality.offline
            : ConnectionQuality.intermittent;
        _updateState(quality);
        return quality;
      }
    } catch (e) {
      _consecutiveFailures++;
      final quality = _consecutiveFailures >= 2
          ? ConnectionQuality.offline
          : ConnectionQuality.intermittent;
      _updateState(quality);
      return quality;
    }
  }

  void _updateState(ConnectionQuality newQuality) {
    final newOnline = newQuality != ConnectionQuality.offline;
    final qualityChanged = newQuality != _quality;
    final onlineChanged = newOnline != _isOnline;

    _quality = newQuality;
    _isOnline = newOnline;

    if (qualityChanged) {
      _qualityController.add(newQuality);
    }
    if (onlineChanged) {
      _controller.add(newOnline);
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _controller.close();
    _qualityController.close();
  }
}
