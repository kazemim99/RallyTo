import 'dart:async';

import 'package:injectable/injectable.dart';

import '../storage/secure_storage_service.dart';
import 'auth_session.dart';

/// The player's [AuthSession], kept in secure storage under one key and cached in memory after the first read.
///
/// It is the single source of truth for "signed in or not": the auth interceptor saves a refreshed session and
/// clears a session the server refused, and [changes] tells `AuthSessionCubit` (and through it the router) either
/// way.
@lazySingleton
class TokenStorage {
  TokenStorage(this._storage);

  static const String sessionKey = 'auth_session';

  final SecureStorageService _storage;
  final StreamController<AuthSession?> _changes = StreamController<AuthSession?>.broadcast();
  final StreamController<String> _signOutReasons = StreamController<String>.broadcast();
  AuthSession? _cached;
  bool _loaded = false;

  /// Every saved session, and null whenever the session is cleared.
  Stream<AuthSession?> get changes => _changes.stream;

  /// The message of every session the server ended (a suspended, banned or inactive account), for the player to
  /// read on the sign-in screen. Each one also clears the session, which [changes] reports as usual.
  Stream<String> get signOutReasons => _signOutReasons.stream;

  /// The stored session, or null when the player is signed out.
  Future<AuthSession?> readSession() async {
    if (_loaded) return _cached;
    final raw = await _storage.read(sessionKey);
    // A save or a clear that finished while this read was out is newer than what the read found.
    if (!_loaded) {
      _cached = AuthSession.tryDecode(raw);
      _loaded = true;
    }
    return _cached;
  }

  Future<String?> accessToken() async => (await readSession())?.accessToken;

  Future<String?> refreshToken() async => (await readSession())?.refreshToken;

  Future<void> saveSession(AuthSession session) async {
    _cached = session;
    _loaded = true;
    await _storage.write(sessionKey, session.encode());
    if (!_changes.isClosed) _changes.add(session);
  }

  /// Signs the player out on this device. [reason] is the server's message when it ended the session itself.
  Future<void> clear({String? reason}) async {
    _cached = null;
    _loaded = true;
    await _storage.delete(sessionKey);
    if (reason != null && !_signOutReasons.isClosed) _signOutReasons.add(reason);
    if (!_changes.isClosed) _changes.add(null);
  }

  @disposeMethod
  Future<void> dispose() async {
    await _changes.close();
    await _signOutReasons.close();
  }
}
