import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../api/models/auth_models.dart';

/// The signed-in player's tokens and what the router needs to know about them. Stored as one encrypted value, so
/// a session is always written and cleared whole.
class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
    this.profileCompleted = false,
    this.roles = const [],
  });

  factory AuthSession.fromTokens(TokenResponse tokens) => AuthSession(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    accessTokenExpiresAt: tokens.accessTokenExpiresAt,
    refreshTokenExpiresAt: tokens.refreshTokenExpiresAt,
    profileCompleted: tokens.profileCompleted,
    roles: tokens.roles,
  );

  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;
  final bool profileCompleted;
  final List<String> roles;

  /// This session with [profileCompleted] changed: the tokens stay as they are.
  AuthSession copyWith({bool? profileCompleted}) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt,
    refreshTokenExpiresAt: refreshTokenExpiresAt,
    profileCompleted: profileCompleted ?? this.profileCompleted,
    roles: roles,
  );

  /// Whether the refresh token has run out at [now]: the session cannot be renewed and is over.
  bool isExpiredAt(DateTime now) => refreshTokenExpiresAt != null && !refreshTokenExpiresAt!.isAfter(now);

  String encode() => jsonEncode({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toUtc().toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt?.toUtc().toIso8601String(),
    'profileCompleted': profileCompleted,
    'roles': roles,
  });

  /// The session in [raw], or null when it is not one (an older format, or damaged).
  static AuthSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final access = json['accessToken'];
      final refresh = json['refreshToken'];
      if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) return null;
      final roles = json['roles'];
      return AuthSession(
        accessToken: access,
        refreshToken: refresh,
        accessTokenExpiresAt: DateTime.tryParse('${json['accessTokenExpiresAt']}'),
        refreshTokenExpiresAt: DateTime.tryParse('${json['refreshTokenExpiresAt']}'),
        profileCompleted: json['profileCompleted'] == true,
        roles: roles is List ? [for (final r in roles) '$r'] : const [],
      );
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    refreshTokenExpiresAt,
    profileCompleted,
    roles,
  ];
}
