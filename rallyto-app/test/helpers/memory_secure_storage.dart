import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_session.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';

/// `FlutterSecureStorage` in memory, for tests. It records the most operations that ever ran at once
/// ([maxInFlight]); each operation yields to the event loop first, as the platform call does, so overlapping callers
/// really overlap. Set [failReads] to make every read throw, as an undecryptable value does.
///
/// In a widget test, pass `timers: false`: operations then yield with a microtask instead of a timer, so they finish
/// inside the test's fake-async zone without pumping.
class MemorySecureStorage extends Fake implements FlutterSecureStorage {
  MemorySecureStorage({this.timers = true});

  final bool timers;
  final Map<String, String> values = {};
  int maxInFlight = 0;
  bool failReads = false;
  int _inFlight = 0;

  Future<T> _op<T>(T Function() body) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await (timers ? Future<void>.delayed(Duration.zero) : Future<void>.microtask(() {}));
      return body();
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _op(() => value == null ? values.remove(key) : values[key] = value);

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _op(() => failReads ? throw Exception('OperationError') : values[key]);

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _op(() => values.remove(key));

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _op(values.clear);
}

/// A [TokenStorage] over [MemorySecureStorage].
TokenStorage memoryTokenStorage([MemorySecureStorage? storage]) =>
    TokenStorage(SecureStorageService(storage ?? MemorySecureStorage()));

/// A session for tests.
AuthSession testSession({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  bool profileCompleted = true,
  DateTime? refreshTokenExpiresAt,
  List<String> roles = const ['Player'],
}) => AuthSession(
  accessToken: accessToken,
  refreshToken: refreshToken,
  profileCompleted: profileCompleted,
  refreshTokenExpiresAt: refreshTokenExpiresAt,
  roles: roles,
);
