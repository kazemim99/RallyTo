import '../../../core/auth/auth_error_codes.dart';
import '../../../core/errors/failures.dart';

/// Why a sign-in call failed: the server's Persian message, its `error.code`, and how long it asked the app to wait
/// (`Retry-After`, on a 429) when it said.
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code, this.statusCode, this.retryAfterSeconds});

  final int? statusCode;

  /// Seconds before asking again, from the `Retry-After` header. Null when the server set no wait.
  final int? retryAfterSeconds;

  /// Suspended or banned: retrying the code will not help, so the player is told why in a dialog.
  bool get isAccountBlocked => AuthErrorCodes.accountBlocked.contains(code);

  @override
  List<Object?> get props => [...super.props, statusCode, retryAfterSeconds];
}
