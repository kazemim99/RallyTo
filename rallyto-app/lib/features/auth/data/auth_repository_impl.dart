import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/auth_api.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/api/models/auth_models.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/dio_failure_mapper.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/otp_challenge.dart';

/// [AuthRepository] over the API's sign-in endpoints (`AuthApi`, on the client without the auth interceptor).
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Future<Either<AuthFailure, OtpChallenge>> sendCode(String phoneNumber) async {
    final result = await _call(() => _api.sendOtp(OtpSendRequest(phoneNumber: phoneNumber)));
    return result.map(
      (data) => OtpChallenge(
        phoneNumber: phoneNumber,
        expiresInSeconds: data.expiresInSeconds,
        resendAfterSeconds: data.resendAfterSeconds,
      ),
    );
  }

  @override
  Future<Either<AuthFailure, AuthSession>> verifyCode({required String phoneNumber, required String code}) async {
    final result = await _call(() => _api.verifyOtp(OtpVerifyRequest(phoneNumber: phoneNumber, code: code)));
    return result.map(AuthSession.fromTokens);
  }

  /// Unwraps the envelope; every failure becomes an [AuthFailure] with the server's message, code and wait.
  Future<Either<AuthFailure, T>> _call<T>(Future<ApiResponse<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (response.isSuccess && data != null) return Right(data);
      return Left(
        AuthFailure(
          response.error?.message ?? response.message ?? AppStrings.genericError,
          code: response.error?.code,
          statusCode: response.statusCode,
        ),
      );
    } on DioException catch (e) {
      final failure = mapDioFailure(e);
      return Left(
        AuthFailure(
          failure.message,
          code: failure.code,
          statusCode: e.response?.statusCode,
          retryAfterSeconds: retryAfterSeconds(e.response?.headers.value('retry-after')),
        ),
      );
    } catch (_) {
      // An answer the app could not read (a contract mismatch): a generic error, not a crash.
      return const Left(AuthFailure(AppStrings.genericError));
    }
  }

  /// The `Retry-After` header in whole seconds (the API sends delta-seconds), or null when absent or not positive.
  static int? retryAfterSeconds(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds != null && seconds > 0 ? seconds : null;
  }
}
