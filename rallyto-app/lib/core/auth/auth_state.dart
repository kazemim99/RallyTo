import 'package:equatable/equatable.dart';

import 'auth_session.dart';

/// Whether the player is signed in, as the router sees it.
sealed class AuthState extends Equatable {
  const AuthState();
}

/// No session on this device: the player signs in at `/auth/phone`.
final class Unauthenticated extends AuthState {
  const Unauthenticated({this.message, this.notice});

  /// Why the server ended the session (a suspended, banned or inactive account), in its own Persian words, shown on
  /// phone entry until the player dismisses it or signs in. Null after an ordinary sign-out.
  final String? message;

  /// A short, non-alarming word for phone entry after the player ended the session themselves in a way worth
  /// confirming (their account was deleted), until dismissed or the next sign-in. Null otherwise.
  final String? notice;

  @override
  List<Object?> get props => [message, notice];
}

/// Signed in. Until [profileCompleted], the player is held on `/onboarding`.
final class Authenticated extends AuthState {
  const Authenticated({required this.profileCompleted, this.roles = const []});

  factory Authenticated.fromSession(AuthSession session) =>
      Authenticated(profileCompleted: session.profileCompleted, roles: session.roles);

  final bool profileCompleted;
  final List<String> roles;

  @override
  List<Object?> get props => [profileCompleted, roles];
}
