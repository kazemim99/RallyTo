import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/current_user.dart';

import '../../helpers/memory_secure_storage.dart';

/// The player's own id comes from the access token's `sub` claim.
void main() {
  String jwt(Map<String, Object?> claims) {
    String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
  }

  test('reads sub from a JWT, padding or not', () {
    expect(
      jwtSubject(jwt({'sub': '3fa85f64-5717-4562-b3fc-2c963f66afa6', 'role': 'Player'})),
      '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    );
    expect(jwtSubject(jwt({'sub': 'ab'})), 'ab');
  });

  test('anything that is not a JWT with a sub is null', () {
    expect(jwtSubject(null), isNull);
    expect(jwtSubject('access-1'), isNull);
    expect(jwtSubject('a.b'), isNull);
    expect(jwtSubject('a.!!!.c'), isNull);
    expect(jwtSubject(jwt({'role': 'Player'})), isNull);
    expect(jwtSubject(jwt({'sub': ''})), isNull);
  });

  test('the current user follows the stored session', () async {
    final tokens = memoryTokenStorage(MemorySecureStorage(timers: false));
    final user = CurrentUser(tokens);
    expect(await user.id(), isNull);

    await tokens.saveSession(testSession(accessToken: jwt({'sub': 'u-me'})));
    expect(await user.id(), 'u-me');
  });
}
