import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../api/config/api_config.dart';
import '../auth/token_storage.dart';
import 'realtime_client.dart';

/// [RealtimeClient] over `signalr_netcore`, on the single hub `/hubs/realtime`.
///
/// The access token goes through `accessTokenFactory`: SignalR sends it as a header on negotiate and as the
/// `access_token` query parameter on the WebSocket, which is where the server reads it for `/hubs`. A dropped
/// connection reconnects with [RealtimeBackoff] forever (SignalR's automatic reconnect); a connection that never came
/// up retries on the same schedule.
@LazySingleton(as: RealtimeClient)
class SignalRRealtimeClient implements RealtimeClient {
  SignalRRealtimeClient(this._tokens);

  static const String hubPath = '/hubs/realtime';

  final TokenStorage _tokens;
  final StreamController<RealtimeStatus> _statusChanges = StreamController<RealtimeStatus>.broadcast();
  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast();

  HubConnection? _connection;
  RealtimeStatus _status = RealtimeStatus.disconnected;
  bool _wanted = false;
  int _attempt = 0;
  Timer? _retry;

  @override
  RealtimeStatus get status => _status;

  @override
  Stream<RealtimeStatus> get statusChanges => _statusChanges.stream;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;
    _attempt = 0;
    await _connect();
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    _retry = null;
    final connection = _connection;
    _connection = null;
    _setStatus(RealtimeStatus.disconnected);
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (_) {
      // Already down.
    }
  }

  Future<void> _connect() async {
    if (!_wanted) return;
    final connection = _connection ??= _build();
    _setStatus(RealtimeStatus.connecting);
    try {
      await connection.start();
      if (!_wanted || !identical(connection, _connection)) return;
      _attempt = 0;
      _setStatus(RealtimeStatus.connected);
    } catch (_) {
      if (!_wanted || !identical(connection, _connection)) return;
      _setStatus(RealtimeStatus.disconnected);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    // The first attempt already ran; the schedule starts at its second step.
    _retry = Timer(RealtimeBackoff.delayFor(++_attempt), () {
      _retry = null;
      unawaited(_connect());
    });
  }

  HubConnection _build() {
    final connection = HubConnectionBuilder()
        .withUrl(
          '${ApiConfig.baseUrl}$hubPath',
          options: HttpConnectionOptions(accessTokenFactory: () async => await _tokens.accessToken() ?? ''),
        )
        .withAutomaticReconnect(reconnectPolicy: _BackoffPolicy())
        .build();
    for (final name in RealtimeEvents.all) {
      connection.on(name, (arguments) => _received(name, arguments));
    }
    connection.onreconnecting(({error}) => _setStatus(RealtimeStatus.connecting));
    connection.onreconnected(({connectionId}) => _setStatus(RealtimeStatus.connected));
    connection.onclose(({error}) {
      if (!identical(connection, _connection) || !_wanted) return;
      // Closed for good (the server ended it, or reconnecting gave up): start over on the backoff schedule.
      _connection = null;
      _setStatus(RealtimeStatus.disconnected);
      _scheduleRetry();
    });
    return connection;
  }

  void _received(String name, List<Object?>? arguments) {
    final payload = arguments == null || arguments.isEmpty ? null : arguments.first;
    if (payload is! Map || _events.isClosed) return;
    _events.add(RealtimeEvent(name, payload.map((key, value) => MapEntry('$key', value))));
  }

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusChanges.isClosed) _statusChanges.add(status);
  }

  /// Stops and closes the streams. Not wired to get_it (it is registered by its interface); for tests.
  Future<void> dispose() async {
    await stop();
    await _statusChanges.close();
    await _events.close();
  }
}

/// SignalR's reconnect schedule: [RealtimeBackoff], never giving up.
class _BackoffPolicy implements IRetryPolicy {
  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) =>
      RealtimeBackoff.delayFor(retryContext.previousRetryCount).inMilliseconds;
}
