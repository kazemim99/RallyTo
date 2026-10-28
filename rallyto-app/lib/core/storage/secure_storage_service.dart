import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Encrypted key-value storage (Android Keystore, iOS Keychain) for secrets such as tokens.
///
/// Two rules carried over from AsanRezerve:
/// * a value that cannot be read (a stale value that no longer decrypts) is treated as absent and deleted, never
///   thrown to the caller ([readSafely]);
/// * operations never overlap: each waits for the one before it. Writes that ran at once lost values on the web,
///   where the plugin makes its key on the first write; serialising them costs nothing on a phone.
@lazySingleton
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;
  Future<void> _tail = Future<void>.value();

  /// The value under [key], or null when there is none or it cannot be read.
  Future<String?> read(String key) => _serial(
    () => readSafely(
      read: () => _storage.read(key: key),
      delete: () => _storage.delete(key: key),
    ),
  );

  /// Stores [value] under [key]; a null value deletes it.
  Future<void> write(String key, String? value) =>
      _serial(() => value == null ? _storage.delete(key: key) : _storage.write(key: key, value: value));

  Future<void> delete(String key) => _serial(() => _storage.delete(key: key));

  Future<void> deleteAll() => _serial(() => _storage.deleteAll());

  /// Runs [operation] after every operation queued before it, whatever their outcome.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// The catch-and-recover logic, factored out so it can be exercised without the platform plugin.
  @visibleForTesting
  static Future<String?> readSafely({
    required Future<String?> Function() read,
    required Future<void> Function() delete,
  }) async {
    try {
      return await read();
    } catch (_) {
      try {
        await delete();
      } catch (_) {
        // Best-effort cleanup: the read has already resolved to "absent".
      }
      return null;
    }
  }
}
