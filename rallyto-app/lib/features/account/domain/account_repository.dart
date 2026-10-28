import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../auth/domain/auth_failure.dart';

/// A deletion code on its way: how long it stays valid and how long before another may be asked for.
class DeletionCode extends Equatable {
  const DeletionCode({required this.expiresInSeconds, required this.resendAfterSeconds});

  final int expiresInSeconds;
  final int resendAfterSeconds;

  @override
  List<Object?> get props => [expiresInSeconds, resendAfterSeconds];
}

/// The player's own account (spec identity-access › Account deletion). Failures are [AuthFailure]s: the server's
/// Persian message and code, and the `Retry-After` wait of a refused code request.
abstract class AccountRepository {
  /// Sends a fresh SMS code to the account's phone number. `OTP_RESEND_TOO_SOON`, `OTP_SEND_LIMIT`,
  /// `TOO_MANY_REQUESTS` and `VERIFICATION_BLOCKED` carry the wait in [AuthFailure.retryAfterSeconds].
  Future<Either<AuthFailure, DeletionCode>> requestDeletionCode();

  /// Deletes the account for good with [code]. `CODE_INVALID` or `CODE_EXPIRED` leave it as it is.
  Future<Either<AuthFailure, Unit>> deleteAccount(String code);
}
