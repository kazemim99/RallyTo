import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../api/client/auth_api.dart';
import '../api/models/auth_models.dart';
import 'auth_session.dart';
import 'auth_state.dart';
import 'token_storage.dart';

/// The app-wide sign-in state the router redirects on. One per app.
///
/// It follows [TokenStorage]: a session saved or cleared anywhere (a refresh in the auth interceptor, a refused
/// refresh that ends the session, an account the server suspended) reaches the router without the caller knowing
/// about it.
@lazySingleton
class AuthSessionCubit extends Cubit<AuthState> {
  /// Without [api], signing out stays on this device (tests).
  AuthSessionCubit(this._tokens, {AuthApi? api, DateTime Function()? clock})
    // A named parameter cannot be a private initializing formal (`this._api`), whatever the lint suggests.
    // ignore: prefer_initializing_formals
    : _api = api,
      _clock = clock ?? DateTime.now,
      super(const Unauthenticated()) {
    _subscription = _tokens.changes.listen(_apply);
    _reasons = _tokens.signOutReasons.listen(_endedByServer);
  }

  /// The app's: sign-out also revokes the refresh token on the server.
  @factoryMethod
  factory AuthSessionCubit.withApi(TokenStorage tokens, AuthApi api) => AuthSessionCubit(tokens, api: api);

  final TokenStorage _tokens;
  final AuthApi? _api;
  final DateTime Function() _clock;
  late final StreamSubscription<AuthSession?> _subscription;
  late final StreamSubscription<String> _reasons;

  /// How long sign-out waits on the server before giving up. The player has already left by then.
  static const Duration signOutTimeout = Duration(seconds: 10);

  /// Reads the stored session once, at start-up, before the first frame. A session whose refresh token has run out
  /// cannot be renewed, so it is cleared rather than shown as signed in.
  Future<void> restore() async {
    final session = await _tokens.readSession();
    if (session != null && session.isExpiredAt(_clock())) {
      await _tokens.clear();
      _apply(null);
      return;
    }
    _apply(session);
  }

  /// Keeps the tokens of a completed sign-in.
  Future<void> signIn(AuthSession session) async {
    await _tokens.saveSession(session);
    _apply(session);
  }

  /// Records that the player now has a profile (onboarding's `POST /profile` answered 201), so the router lets them
  /// past `/onboarding`. The stored session is updated too: the next start opens on home. Signed out, it does nothing.
  Future<void> markProfileCompleted() async {
    final session = await _tokens.readSession();
    if (session == null || session.profileCompleted) return;
    await _tokens.saveSession(session.copyWith(profileCompleted: true));
    _apply(session.copyWith(profileCompleted: true));
  }

  /// Adds work that must run while the session is still valid, just before sign-out clears it (unregistering this
  /// device's push token). Each hook is best effort and waits at most [beforeSignOutTimeout].
  void addBeforeSignOut(Future<void> Function() hook) => _beforeSignOut.add(hook);

  final List<Future<void> Function()> _beforeSignOut = [];

  /// How long sign-out waits on each [addBeforeSignOut] hook.
  static const Duration beforeSignOutTimeout = Duration(seconds: 5);

  /// Runs the [addBeforeSignOut] hooks, signs out on this device, then asks the server to revoke the refresh token.
  /// Every call to the server is best effort: offline, or refused, the player is signed out all the same.
  Future<void> signOut() => _endSession(revoke: true);

  /// Ends the session of an account the player just deleted (`POST /account/deletion` answered 204), then shows
  /// [notice] on phone entry. It is [signOut]'s path: the [addBeforeSignOut] hooks run first (unregistering this
  /// device's push token), then the session is cleared on this device. The server already revoked every refresh
  /// token, so none is revoked again; and the `ACCOUNT_INACTIVE` 401 a hook may now meet does not replace [notice]
  /// with the server's "account ended" message (until the next sign-in).
  Future<void> signOutDeletedAccount(String notice) async {
    _accountDeleted = true;
    await _endSession(revoke: false);
    if (!isClosed) emit(Unauthenticated(notice: notice));
  }

  /// Set by [signOutDeletedAccount] until the next sign-in: the server's "account ended" reasons are expected then,
  /// and not shown.
  bool _accountDeleted = false;

  Future<void> _endSession({required bool revoke}) async {
    AuthSession? session;
    try {
      session = await _tokens.readSession();
    } catch (_) {
      // Unreadable storage: nothing to revoke, and clearing it is all that is left.
    }
    if (session != null) {
      for (final hook in [..._beforeSignOut]) {
        try {
          await hook().timeout(beforeSignOutTimeout);
        } catch (_) {
          // Best effort: the server revokes a token it can no longer reach anyway.
        }
      }
    }
    await _tokens.clear();
    _apply(null);
    if (revoke && session != null) await _revoke(session);
  }

  /// Hides the message of a session the server ended (or the deletion notice), once the player has read it.
  void dismissSignOutMessage() {
    final current = state;
    if (!isClosed && current is Unauthenticated && (current.message != null || current.notice != null)) {
      emit(const Unauthenticated());
    }
  }

  Future<void> _revoke(AuthSession session) async {
    final api = _api;
    if (api == null) return;
    try {
      await api
          .signOut(RefreshTokenRequest(refreshToken: session.refreshToken), 'Bearer ${session.accessToken}')
          .timeout(signOutTimeout);
    } catch (_) {
      // Best effort: the refresh token runs out on its own.
    }
  }

  void _endedByServer(String message) {
    if (isClosed || _accountDeleted) return;
    emit(Unauthenticated(message: message));
  }

  void _apply(AuthSession? session) {
    if (isClosed) return;
    if (session == null) {
      // The clear that came with a server's sign-out message (or a deletion notice) must not wipe it out.
      final current = state;
      if (current is Unauthenticated && (current.message != null || current.notice != null)) return;
      emit(const Unauthenticated());
      return;
    }
    _accountDeleted = false;
    emit(Authenticated.fromSession(session));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _reasons.cancel();
    return super.close();
  }
}
