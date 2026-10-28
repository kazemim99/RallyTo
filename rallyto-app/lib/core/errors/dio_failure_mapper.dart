import 'package:dio/dio.dart';

import '../auth/auth_error_codes.dart';
import '../constants/app_strings.dart';
import 'failures.dart';
import 'server_message.dart';

/// Maps a Dio error to the failure a repository returns.
///
/// Connectivity problems fail fast with an explicit offline message. A 401 here means the session is gone for good:
/// `AuthInterceptor` already tried the refresh token and cleared the session before passing the error on. A 401 for a
/// suspended, banned or inactive account carries the server's message instead.
Failure mapDioFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure(AppStrings.offlineActionError);
    default:
      final data = e.response?.data;
      final status = e.response?.statusCode;
      final code = serverErrorCode(data);
      final message = serverMessage(data);
      switch (status) {
        case 401:
          // An account the server ended says why; any other 401 is a session that could not be renewed.
          final ended = accountEndedMessage(e.response);
          return SessionExpiredFailure(ended ?? AppStrings.sessionExpiredError, code: code);
        case 403:
          return UnauthorizedFailure(message ?? AppStrings.forbiddenError, code: code);
        case 404:
          return NotFoundFailure(message ?? AppStrings.notFoundError, code: code);
        case 400:
        case 422:
          return ValidationFailure(
            message ?? AppStrings.validationError,
            code: code,
            fieldErrors: serverFieldErrors(data),
          );
      }
      return ServerFailure(message ?? e.message ?? AppStrings.genericError, code: code, statusCode: status);
  }
}
