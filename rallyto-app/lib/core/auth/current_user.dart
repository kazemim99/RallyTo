import 'dart:convert';

import 'package:injectable/injectable.dart';

import 'token_storage.dart';

/// The signed-in player's user id, read from the access token's `sub` claim, so a screen can tell its own messages
/// from others' without asking the server.
@lazySingleton
class CurrentUser {
  CurrentUser(this._tokens);

  final TokenStorage _tokens;

  /// Null when signed out or when the token cannot be read.
  Future<String?> id() async {
    try {
      return jwtSubject(await _tokens.accessToken());
    } catch (_) {
      return null;
    }
  }
}

/// The `sub` claim of [token], a JWT, or null when it has none or is not a JWT. The signature is not checked: the
/// value only labels what the server already sent this player.
String? jwtSubject(String? token) {
  final parts = token?.split('.') ?? const <String>[];
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final sub = payload is Map ? payload['sub'] : null;
    return sub is String && sub.isNotEmpty ? sub : null;
  } on FormatException {
    return null;
  }
}
