import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../auth/auth_session_cubit.dart';
import '../auth/auth_state.dart';
import 'realtime_client.dart';

/// Keeps the realtime hub up exactly while the player is signed in and the app is in the foreground: it connects on
/// sign-in and on resume, and tears down on sign-out and when the app goes to the background (push takes over there).
@lazySingleton
class RealtimeLifecycle with WidgetsBindingObserver {
  RealtimeLifecycle(this._session, this._realtime);

  final AuthSessionCubit _session;
  final RealtimeClient _realtime;
  StreamSubscription<AuthState>? _subscription;
  bool _foreground = true;
  bool _started = false;
  bool _observing = false;

  /// Starts following the session and, when [observeApp], the app's lifecycle (tests drive [appLifecycleChanged]).
  void start({bool observeApp = true}) {
    if (_started) return;
    _started = true;
    if (observeApp) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _subscription = _session.stream.listen((_) => _apply());
    _apply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => appLifecycleChanged(state);

  /// The app moved to [state]: resumed is the foreground; hidden, paused and detached are not. Inactive (a dialog
  /// over the app, the app switcher) changes nothing.
  void appLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
      case AppLifecycleState.inactive:
        return;
    }
    _apply();
  }

  void _apply() {
    final signedIn = _session.state is Authenticated;
    unawaited(signedIn && _foreground ? _realtime.start() : _realtime.stop());
  }

  Future<void> dispose() async {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    await _realtime.stop();
  }
}
