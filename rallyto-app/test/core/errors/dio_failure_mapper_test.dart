import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/dio_failure_mapper.dart';
import 'package:rallyto_app/core/errors/failures.dart';

void main() {
  final options = RequestOptions(path: '/api/v1/anything');

  DioException badResponse(int status, [Object? data]) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(requestOptions: options, statusCode: status, data: data),
  );

  Map<String, Object?> envelope(int status, String code, String message, [Map<String, List<String>>? errors]) => {
    'success': false,
    'statusCode': '$status',
    'message': message,
    'data': null,
    'error': {'code': code, 'message': message, 'errors': errors},
  };

  test('no connection or a timeout is a network failure', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(
        mapDioFailure(DioException(requestOptions: options, type: type)),
        const NetworkFailure(AppStrings.offlineActionError),
        reason: '$type',
      );
    }
  });

  test('a 401 (after the refresh failed) means sign in again', () {
    expect(
      mapDioFailure(badResponse(401, envelope(401, 'UNAUTHORIZED', 'Unauthorized'))),
      const SessionExpiredFailure(AppStrings.sessionExpiredError, code: 'UNAUTHORIZED'),
    );
  });

  test('a 403 keeps the server message and code, so a feature can tell a suspension from a ban', () {
    final failure = mapDioFailure(badResponse(403, envelope(403, 'ACCOUNT_SUSPENDED', 'حساب شما تعلیق شده است')));

    expect(failure, isA<UnauthorizedFailure>().having((f) => f.code, 'code', 'ACCOUNT_SUSPENDED'));
    expect(failure.message, 'حساب شما تعلیق شده است');
    expect(failure, isNot(isA<SessionExpiredFailure>()));
  });

  test('a 400 is a validation failure with the per-field messages', () {
    final failure = mapDioFailure(
      badResponse(
        400,
        envelope(400, 'VALIDATION_ERROR', 'Validation failed for property PhoneNumber', {
          'PhoneNumber': ['شماره موبایل معتبر نیست'],
        }),
      ),
    );

    expect(
      failure,
      const ValidationFailure(
        'شماره موبایل معتبر نیست',
        code: 'VALIDATION_ERROR',
        fieldErrors: {
          'PhoneNumber': ['شماره موبایل معتبر نیست'],
        },
      ),
    );
  });

  test('a 404 is not found; anything else is a server failure with its status', () {
    expect(mapDioFailure(badResponse(404)), const NotFoundFailure(AppStrings.notFoundError));
    expect(
      mapDioFailure(badResponse(429, envelope(429, 'TOO_MANY_REQUESTS', 'لطفاً کمی صبر کنید'))),
      const ServerFailure('لطفاً کمی صبر کنید', code: 'TOO_MANY_REQUESTS', statusCode: 429),
    );
    expect(mapDioFailure(badResponse(500)), const ServerFailure(AppStrings.genericError, statusCode: 500));
  });
}
