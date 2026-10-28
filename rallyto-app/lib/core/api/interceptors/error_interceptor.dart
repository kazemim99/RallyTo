import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../constants/app_strings.dart';
import '../../errors/server_message.dart';

/// Gives every failed request a message the player can read: the server's own words when it sent any, otherwise a
/// Persian message for the kind of failure.
@injectable
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = messageFor(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: err.error ?? message,
        stackTrace: err.stackTrace,
        message: message,
      ),
    );
  }

  static String messageFor(DioException err) => switch (err.type) {
    DioExceptionType.connectionTimeout => AppStrings.connectionTimeoutError,
    DioExceptionType.sendTimeout => AppStrings.sendTimeoutError,
    DioExceptionType.receiveTimeout => AppStrings.receiveTimeoutError,
    DioExceptionType.cancel => AppStrings.requestCancelledError,
    DioExceptionType.connectionError => AppStrings.connectionError,
    DioExceptionType.badResponse => _httpMessage(err.response),
    _ => AppStrings.serverUnreachableError,
  };

  static String _httpMessage(Response<dynamic>? response) {
    if (response == null) return AppStrings.serverError;
    final message = serverMessage(response.data);
    if (message != null) return message;
    return switch (response.statusCode) {
      400 => AppStrings.badRequestError,
      401 => AppStrings.unauthorizedError,
      403 => AppStrings.forbiddenError,
      404 => AppStrings.notFoundError,
      409 => AppStrings.conflictError,
      422 => AppStrings.validationError,
      429 => AppStrings.tooManyRequestsError,
      503 => AppStrings.serviceUnavailableError,
      _ => AppStrings.serverError,
    };
  }
}
