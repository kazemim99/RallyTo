import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/safe_api_call.dart';
import 'package:rallyto_app/core/api/models/api_response.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';

void main() {
  final options = RequestOptions(path: '/api/v1/anything');

  test('a successful envelope is Right(data)', () async {
    final result = await safeApiCall(() async => const ApiResponse<int>(success: true, statusCode: 200, data: 7));

    expect(result, const Right<Failure, int>(7));
  });

  test('a success without data is Right(null) for a nullable type', () async {
    final result = await safeApiCall<String?>(() async => const ApiResponse<String?>(success: true));

    expect(result, const Right<Failure, String?>(null));
  });

  test('a failed envelope is Left(ServerFailure) with the server message and code', () async {
    final result = await safeApiCall(
      () async => const ApiResponse<int>(
        success: false,
        statusCode: 409,
        message: 'Already a member',
        error: ApiError(code: 'ALREADY_MEMBER', message: 'شما قبلاً عضو شده‌اید'),
      ),
    );

    expect(
      result,
      const Left<Failure, int>(ServerFailure('شما قبلاً عضو شده‌اید', code: 'ALREADY_MEMBER', statusCode: 409)),
    );
  });

  test('a Dio error is mapped to its failure', () async {
    final result = await safeApiCall<int>(
      () => throw DioException.connectionError(requestOptions: options, reason: 'offline'),
    );

    expect(result, const Left<Failure, int>(NetworkFailure(AppStrings.offlineActionError)));
  });

  test('an answer the app cannot read is a generic failure, not a crash', () async {
    final result = await safeApiCall<int>(() => throw const FormatException('not json'));

    expect(result, const Left<Failure, int>(ServerFailure(AppStrings.genericError)));
  });
}
