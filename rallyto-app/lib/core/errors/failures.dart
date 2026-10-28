import 'package:equatable/equatable.dart';

/// What a repository returns on the left of `Either<Failure, T>`: a message the player can read, and the server's
/// machine-readable error code when it sent one (the envelope's `error.code`), so a feature can react to a specific
/// error without parsing text.
abstract class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [runtimeType, message, code];
}

/// The server answered with an error, or with something the app could not read.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// The server could not be reached: no connection, or a timeout.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Local storage could not be read or written.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// The request was refused as invalid (400 or 422). [fieldErrors] are the server's per-field messages, keyed by
/// field name, when it sent them.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// What was asked for does not exist (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

/// The player is signed in but not allowed to do this (403). Signing in again would not help.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message, {super.code});
}

/// A 401 after the refresh token could not renew the session: the player has to sign in again.
class SessionExpiredFailure extends UnauthorizedFailure {
  const SessionExpiredFailure(super.message, {super.code});
}
