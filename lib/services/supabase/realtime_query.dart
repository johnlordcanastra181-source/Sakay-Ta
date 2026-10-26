import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int _nextRealtimeTopicId = 0;

/// Capped exponential backoff for realtime channel rejoin attempts:
/// 1s, 2s, 4s, 8s, 16s, then 20s forever. Never returns a "give up" value,
/// so channels always recover once mobile signal returns.
@visibleForTesting
int realtimeReconnectDelayMs(int consecutiveFailures) {
  final attempt = consecutiveFailures < 1 ? 1 : consecutiveFailures;
  final exponent = attempt - 1 > 5 ? 5 : attempt - 1;
  final delay = 1000 * (1 << exponent);
  return delay > 20000 ? 20000 : delay;
}

/// Builds one lifecycle-owned Postgres Changes stream.
///
/// Supabase's convenience `stream()` API is useful for simple lists, but it
/// hides the channel status callback and makes it easy for a screen rebuild to
/// create another channel. Critical ride/presence streams use this adapter so
/// the initial query and live events share one serialized refresh pipeline.
Stream<T> realtimeQueryStream<T>({
  required SupabaseClient client,
  required String feature,
  required String table,
  required String filterDescription,
  required Future<T> Function() fetch,
  List<PostgresChangeFilter> filters = const [],
  Duration? throttle,
  Duration? pollInterval,
}) {
  return Stream<T>.multi((controller) {
    final authUid = client.auth.currentUser?.id;
    if (authUid == null || authUid.isEmpty) {
      debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
          'filter=$filterDescription authenticatedUid=none '
          'status=AUTH_NOT_READY');
      controller.addError(
        StateError('Realtime requires an authenticated Supabase session.'),
      );
      controller.close();
      return;
    }

    var cancelled = false;
    var refreshRunning = false;
    var refreshQueued = false;
    var requestedRefreshVersion = 0;
    var hasSubscribed = false;
    var hasEmittedValue = false;
    var consecutiveChannelFailures = 0;
    var reconnectScheduled = false;
    RealtimeChannel? channel;
    Timer? reconnectTimer;
    DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
    Timer? throttleTimer;
    Timer? pollTimer;
    late void Function() attach;

    String statusName(RealtimeSubscribeStatus status) => switch (status) {
          RealtimeSubscribeStatus.subscribed => 'SUBSCRIBED',
          RealtimeSubscribeStatus.channelError => 'CHANNEL_ERROR',
          RealtimeSubscribeStatus.timedOut => 'TIMED_OUT',
          RealtimeSubscribeStatus.closed => 'CLOSED',
        };

    void logStatus(String status, [Object? error]) {
      debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
          'filter=$filterDescription authenticatedUid=$authUid '
          'status=$status${error == null ? '' : ' error=$error'}');
    }

    Future<void> refresh(String source) async {
      requestedRefreshVersion++;
      if (cancelled) return;

      if (throttle != null) {
        final now = DateTime.now();
        final timeSinceLastFetch = now.difference(lastFetchTime);
        if (timeSinceLastFetch < throttle) {
          if (throttleTimer?.isActive != true) {
            throttleTimer = Timer(throttle - timeSinceLastFetch, () {
              throttleTimer = null;
              if (!cancelled) refresh('throttled_retry:$source');
            });
          }
          return;
        }
      }

      if (refreshRunning) {
        refreshQueued = true;
        return;
      }

      refreshRunning = true;
      lastFetchTime = DateTime.now();
      do {
        refreshQueued = false;
        final fetchVersion = requestedRefreshVersion;
        final stopwatch = Stopwatch()..start();
        try {
          final value = await fetch();
          stopwatch.stop();
          if (!cancelled && fetchVersion == requestedRefreshVersion) {
            hasEmittedValue = true;
            debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
                'filter=$filterDescription source=$source '
                'durationMs=${stopwatch.elapsedMilliseconds} '
                'status=FETCH_SUCCESS');
            controller.add(value);
          } else if (!cancelled) {
            // A newer event or poll arrived during this query. Discard the
            // stale snapshot and emit only the authoritative refresh.
            refreshQueued = true;
          }
        } catch (error, stackTrace) {
          stopwatch.stop();
          if (!cancelled && fetchVersion == requestedRefreshVersion) {
            debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
                'filter=$filterDescription source=$source '
                'durationMs=${stopwatch.elapsedMilliseconds} '
                'status=FETCH_ERROR error=$error');
            if (!hasEmittedValue) {
              controller.addError(error, stackTrace);
            }
          } else if (!cancelled) {
            refreshQueued = true;
          }
        }
      } while (refreshQueued && !cancelled);
      refreshRunning = false;
    }

    void scheduleReconnect(RealtimeChannel failedChannel, Object? error) {
      if (cancelled || reconnectScheduled || channel != failedChannel) {
        return;
      }
      consecutiveChannelFailures++;
      // Never give up permanently: weak rural signal produces bursts of
      // channel errors. Back off (1s, 2s, 4s, 8s, 16s, then 20s cap) while the
      // poll timer keeps data fresh, and rejoin as soon as signal returns.
      reconnectScheduled = true;
      final delayMs = realtimeReconnectDelayMs(consecutiveChannelFailures);
      logStatus('RECONNECT_SCHEDULED delayMs=$delayMs', error);
      // Pull authoritative data right away so a missed event during the
      // drop is not lost while the channel is down.
      unawaited(refresh('channel_error'));
      reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
        reconnectScheduled = false;
        if (cancelled || channel != failedChannel) return;
        try {
          await failedChannel.unsubscribe();
        } catch (unsubscribeError) {
          debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
              'status=UNSUBSCRIBE_ERROR error=$unsubscribeError');
        }
        if (!cancelled && channel == failedChannel) {
          attach();
        }
      });
    }

    attach = () {
      if (cancelled) return;
      final topic = 'sakayta:$feature:${++_nextRealtimeTopicId}';
      final nextChannel = client.channel(topic);
      channel = nextChannel;
      logStatus('CONNECTING');

      nextChannel
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filters: filters,
        callback: (payload) {
          if (cancelled || channel != nextChannel) return;
          final event = payload.eventType.name.toUpperCase();
          logStatus('EVENT_$event');
          // Events are refresh triggers. The authoritative query supplies the
          // complete row/model shape and serializes with any fetch in flight.
          unawaited(refresh('realtime:$event'));
        },
      )
          .subscribe((status, [error]) {
        if (cancelled || channel != nextChannel) return;
        logStatus(statusName(status), error);
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            consecutiveChannelFailures = 0;
            if (hasSubscribed) unawaited(refresh('reconnected'));
            hasSubscribed = true;
            break;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            scheduleReconnect(nextChannel, error);
            break;
        }
      });
    };

    attach();
    // Always query independently of the channel join. A row created before a
    // screen subscribed must still be visible on first render.
    unawaited(refresh('initial'));
    if (pollInterval != null && pollInterval > Duration.zero) {
      pollTimer = Timer.periodic(
        pollInterval,
        (_) => unawaited(refresh('poll')),
      );
    }

    controller.onCancel = () async {
      cancelled = true;
      reconnectTimer?.cancel();
      pollTimer?.cancel();
      throttleTimer?.cancel();
      final activeChannel = channel;
      channel = null;
      if (activeChannel != null) {
        try {
          await activeChannel.unsubscribe();
          logStatus('CANCELLED');
        } catch (error) {
          debugPrint('[SakayTa][Realtime] feature=$feature table=$table '
              'status=UNSUBSCRIBE_ERROR error=$error');
        }
      }
    };
  });
}
