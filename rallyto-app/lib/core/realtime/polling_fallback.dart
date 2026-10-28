import 'dart:async';

import 'realtime_client.dart';

/// Keeps a screen's data fresh when the realtime hub cannot: while [RealtimeClient.status] is anything but connected it
/// calls [onPoll] every [interval]; when the hub comes back it stops, and calls [onPoll] once to catch up on what was
/// missed.
class PollingFallback {
  PollingFallback(this._realtime, {required this.interval, required this.onPoll});

  /// While a chat screen is open.
  static const Duration chatInterval = Duration(seconds: 15);

  /// Everywhere else (the badges on the home screen).
  static const Duration backgroundInterval = Duration(seconds: 60);

  final RealtimeClient _realtime;
  final Duration interval;
  final FutureOr<void> Function() onPoll;

  StreamSubscription<RealtimeStatus>? _subscription;
  Timer? _timer;
  RealtimeStatus? _last;

  /// Whether it is polling now.
  bool get isPolling => _timer != null;

  void start() {
    if (_subscription != null) return;
    _apply(_realtime.status);
    _subscription = _realtime.statusChanges.listen(_apply);
  }

  void _apply(RealtimeStatus status) {
    final previous = _last;
    _last = status;
    if (status == RealtimeStatus.connected) {
      _timer?.cancel();
      _timer = null;
      if (previous != null && previous != RealtimeStatus.connected) _poll();
    } else {
      _timer ??= Timer.periodic(interval, (_) => _poll());
    }
  }

  void _poll() {
    try {
      final result = onPoll();
      if (result is Future<void>) unawaited(result.catchError((Object _) {}));
    } catch (_) {
      // A failed poll is retried on the next tick.
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
