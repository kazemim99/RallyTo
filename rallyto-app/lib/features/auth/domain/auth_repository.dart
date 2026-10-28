import 'package:dartz/dartz.dart';

import '../../../core/auth/auth_session.dart';
import 'auth_failure.dart';
import 'otp_challenge.dart';

/// Phone sign-in: send a code by SMS, then trade it for a session.
abstract class AuthRepository {
  /// Sends a sign-in code to [phoneNumber] (canonical «09xxxxxxxxx»).
  Future<Either<AuthFailure, OtpChallenge>> sendCode(String phoneNumber);

  /// Trades [code] (ASCII digits) for a session. The session is not stored here: the caller signs in with it.
  Future<Either<AuthFailure, AuthSession>> verifyCode({required String phoneNumber, required String code});
}
