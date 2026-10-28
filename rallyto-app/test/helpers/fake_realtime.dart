import 'dart:async';

import 'package:rallyto_app/core/realtime/realtime_client.dart';

/// A [RealtimeClient] the test drives: [setStatus] moves the connection, [emit] delivers a server event.
class FakeRealtimeClient implements RealtimeClient {
  FakeRealtimeClient({RealtimeStatus status = RealtimeStatus.connected})
    // A named parameter cannot be a private initializing formal.
    // ignore: prefer_initializing_formals
    : _status = status;

  final StreamController<RealtimeStatus> _statusChanges = StreamController<RealtimeStatus>.broadcast(sync: true);
  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast(sync: true);
  RealtimeStatus _status;

  int starts = 0;
  int stops = 0;

  /// Whether [start] was called more recently than [stop].
  bool running = false;

  @override
  RealtimeStatus get status => _status;

  @override
  Stream<RealtimeStatus> get statusChanges => _statusChanges.stream;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  void setStatus(RealtimeStatus status) {
    _status = status;
    _statusChanges.add(status);
  }

  void emit(String name, Map<String, dynamic> payload) => _events.add(RealtimeEvent(name, payload));

  @override
  Future<void> start() async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}
