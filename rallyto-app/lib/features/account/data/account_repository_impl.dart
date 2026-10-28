import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/dio_failure_mapper.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../auth/domain/auth_failure.dart';
import '../domain/account_repository.dart';
import 'account_api.dart';
import 'models/account_models.dart';

/// [AccountRepository] over [AccountApi].
@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._api);

  final AccountApi _api;

  @override
  Future<Either<AuthFailure, DeletionCode>> requestDeletionCode() => _call(() async {
    final response = await _api.requestDeletionCode();
    final data = response.data;
    if (response.isSuccess && data != null) {
      return Right(DeletionCode(expiresInSeconds: data.expiresInSeconds, resendAfterSeconds: data.resendAfterSeconds));
    }
    return Left(
      AuthFailure(
        response.error?.message ?? response.message ?? AppStrings.genericError,
        code: response.error?.code,
        statusCode: response.statusCode,
      ),
    );
  });

  @override
  Future<Either<AuthFailure, Unit>> deleteAccount(String code) => _call(() async {
    await _api.deleteAccount(AccountDeletionRequest(code: code));
    return const Right(unit);
  });

  /// Runs [request]; a Dio error becomes an [AuthFailure] with the server's message, code and `Retry-After` wait.
  Future<Either<AuthFailure, T>> _call<T>(Future<Either<AuthFailure, T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final failure = mapDioFailure(e);
      return Left(
        AuthFailure(
          failure.message,
          code: failure.code,
          statusCode: e.response?.statusCode,
          retryAfterSeconds: AuthRepositoryImpl.retryAfterSeconds(e.response?.headers.value('retry-after')),
        ),
      );
    } catch (_) {
      // An answer the app could not read (a contract mismatch): a generic error, not a crash.
      return const Left(AuthFailure(AppStrings.genericError));
    }
  }
}
