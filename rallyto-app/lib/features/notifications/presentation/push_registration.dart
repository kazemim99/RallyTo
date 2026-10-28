import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/auth/auth_session_cubit.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/push/push_service.dart';
import '../domain/notification_repository.dart';
import 'deep_links.dart';

/// This device's push, for the signed-in account (spec notifications › Device token registration):
///
/// * registers the FCM token after sign-in and whenever FCM rotates it (`POST /device-tokens`);
/// * unregisters it before sign-out, while the session is still valid (`DELETE /device-tokens`);
/// * turns a tapped push into an app location on [deepLinks], for the router to open.
///
/// Push that cannot start (no `google-services.json`, no Play services, tests) leaves the app as it is.
@lazySingleton
class PushRegistration {
  PushRegistration(this._push, this._tokens, this._notifications, this._session);

  final PushService _push;
  final DeviceTokenRepository _tokens;
  final NotificationRepository _notifications;
  final AuthSessionCubit _session;

  /// Single-subscription, so a push tapped to launch the app waits until the app listens.
  final StreamController<String> _deepLinks = StreamController<String>();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<bool>? _initializing;
  bool _started = false;

  /// The token the server has for this account now, or null.
  String? _registered;

  /// App locations to open, one per tapped push.
  Stream<String> get deepLinks => _deepLinks.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _session.addBeforeSignOut(unregister);
    _subscriptions.add(_session.stream.listen((state) => unawaited(_follow(state))));
    await _follow(_session.state);
  }

  Future<void> _follow(AuthState state) async {
    if (state is! Authenticated) {
      _registered = null;
      return;
    }
    if (!await _ready()) return;
    final token = await _push.getToken();
    if (token != null) await _register(token);
  }

  /// Sets push up once; on success, follows token rotation and taps.
  Future<bool> _ready() => _initializing ??= () async {
    final ready = await _push.initialize();
    if (!ready) return false;
    _subscriptions
      ..add(
        _push.tokenRefreshes.listen((token) {
          if (_session.state is Authenticated) unawaited(_register(token));
        }),
      )
      ..add(_push.openedNotifications.listen(_opened));
    final initial = await _push.takeInitialNotification();
    if (initial != null) _opened(initial);
    return true;
  }();

  Future<void> _register(String token) async {
    if (token == _registered) return;
    final result = await _tokens.register(token, platform: _push.platform);
    if (result.isRight()) _registered = token;
  }

  /// Takes this device's token off the account. Run by sign-out before the session is cleared.
  Future<void> unregister() async {
    final token = _registered ?? (await _ready() ? await _push.getToken() : null);
    _registered = null;
    if (token == null) return;
    await _tokens.unregister(token);
  }

  /// A tapped push: its entry is marked read (chat pushes have none) and its link opened.
  void _opened(Map<String, String> data) {
    final link = data['deepLink'];
    final id = data['notificationId'] ?? '';
    if (id.isNotEmpty && !(link?.startsWith('/chat/') ?? false)) unawaited(_notifications.markRead(id));
    if (!_deepLinks.isClosed) _deepLinks.add(DeepLinks.targetFor(link));
  }

  @disposeMethod
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    // Not awaited: with nobody listening, a single-subscription controller's close never completes.
    unawaited(_deepLinks.close());
  }
}
