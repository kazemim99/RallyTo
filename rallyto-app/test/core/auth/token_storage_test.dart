import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_session.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';

import '../../helpers/memory_secure_storage.dart';

void main() {
  late MemorySecureStorage storage;
  late TokenStorage tokens;

  setUp(() {
    storage = MemorySecureStorage();
    tokens = TokenStorage(SecureStorageService(storage));
  });

  test('a saved session reads back whole, from a fresh instance too', () async {
    final session = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.utc(2026, 10, 23, 8, 45),
      refreshTokenExpiresAt: DateTime.utc(2026, 11, 22, 8, 30),
      profileCompleted: true,
      roles: const ['Player', 'Admin'],
    );

    await tokens.saveSession(session);

    expect(await tokens.readSession(), session);
    expect(await TokenStorage(SecureStorageService(storage)).readSession(), session);
    expect(await tokens.accessToken(), 'access');
    expect(await tokens.refreshToken(), 'refresh');
    expect(storage.values.keys, [TokenStorage.sessionKey], reason: 'one value, so it is written and cleared whole');
  });

  test('clear removes the session', () async {
    await tokens.saveSession(testSession());
    await tokens.clear();

    expect(await tokens.readSession(), isNull);
    expect(storage.values, isEmpty);
  });

  test('announces every save and clear', () async {
    final changes = <AuthSession?>[];
    final subscription = tokens.changes.listen(changes.add);

    await tokens.saveSession(testSession());
    await tokens.clear();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(changes, [testSession(), null]);
  });

  test('a damaged or unreadable value reads as signed out', () async {
    storage.values[TokenStorage.sessionKey] = '{not json';
    expect(await TokenStorage(SecureStorageService(storage)).readSession(), isNull);

    storage.values[TokenStorage.sessionKey] = '{"accessToken": "", "refreshToken": "r"}';
    expect(await TokenStorage(SecureStorageService(storage)).readSession(), isNull);

    storage
      ..values[TokenStorage.sessionKey] = testSession().encode()
      ..failReads = true;
    expect(await TokenStorage(SecureStorageService(storage)).readSession(), isNull);
  });

  test('a save made while the first read is out is not overwritten by what that read found', () async {
    await TokenStorage(SecureStorageService(storage)).saveSession(testSession(accessToken: 'old'));

    final read = tokens.readSession();
    await tokens.saveSession(testSession(accessToken: 'new'));

    expect((await read)?.accessToken, 'new');
    expect(await tokens.accessToken(), 'new');
  });

  test('a session whose refresh token has run out is expired', () {
    final at = DateTime.utc(2026, 10, 23);
    expect(testSession(refreshTokenExpiresAt: at).isExpiredAt(at), isTrue);
    expect(testSession(refreshTokenExpiresAt: at).isExpiredAt(at.subtract(const Duration(seconds: 1))), isFalse);
    expect(testSession().isExpiredAt(at), isFalse, reason: 'no expiry known: the server decides');
  });
}
