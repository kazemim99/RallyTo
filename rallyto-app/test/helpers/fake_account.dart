import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rallyto_app/features/account/domain/account_repository.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';

/// An [AccountRepository] answering as the test says, recording what it was asked. Like the local sandbox, the code
/// is «2222» unless [deleteAnswers] says otherwise.
class FakeAccountRepository implements AccountRepository {
  int codeRequests = 0;
  final List<String> deletions = [];

  /// Answers for [requestDeletionCode], in order; the last one repeats.
  List<Either<AuthFailure, DeletionCode>> codeAnswers = [
    const Right(DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 60)),
  ];

  /// The answer for [deleteAccount] with [code]; null: «2222» deletes, anything else is CODE_INVALID.
  Either<AuthFailure, Unit> Function(String code)? deleteAnswers;

  /// When set, every call waits on it, so a test can look at the in-between state.
  Completer<void>? gate;

  @override
  Future<Either<AuthFailure, DeletionCode>> requestDeletionCode() async {
    codeRequests++;
    await gate?.future;
    return codeAnswers.length > 1 ? codeAnswers.removeAt(0) : codeAnswers.single;
  }

  @override
  Future<Either<AuthFailure, Unit>> deleteAccount(String code) async {
    deletions.add(code);
    await gate?.future;
    final answer = deleteAnswers;
    if (answer != null) return answer(code);
    return code == sandboxCode ? const Right(unit) : const Left(codeInvalid);
  }

  static const String sandboxCode = '2222';

  static const AuthFailure codeInvalid = AuthFailure('کد واردشده درست نیست.', code: 'CODE_INVALID', statusCode: 400);
}
