import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/config/api_config.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';

void main() {
  test('targets the configured API with JSON and Persian headers', () {
    final dio = DioFactory.create(logging: false);

    expect(dio.options.baseUrl, ApiConfig.baseUrl);
    expect(dio.options.contentType, Headers.jsonContentType);
    expect(dio.options.headers['Accept'], Headers.jsonContentType);
    expect(dio.options.headers['Accept-Language'], 'fa-IR');
    expect(dio.options.connectTimeout, ApiConfig.connectTimeout);
    expect(dio.options.receiveTimeout, ApiConfig.receiveTimeout);
  });

  test('logs only when asked; the default is kDebugMode, so release builds never log', () {
    final silent = DioFactory.create(logging: false);
    final logging = DioFactory.create(logging: true);

    expect(silent.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(logging.interceptors.whereType<LogInterceptor>(), hasLength(1));
  });

  test('keeps the given interceptors in order, with the logger last and blind to headers', () {
    final errors = ErrorInterceptor();
    final dio = DioFactory.create(interceptors: [errors], logging: true);
    final added = dio.interceptors.where((i) => i is ErrorInterceptor || i is LogInterceptor).toList();

    expect(added.first, same(errors));
    final logger = added.last as LogInterceptor;
    expect(logger.requestHeader, isFalse, reason: 'the Authorization header carries the access token');
    expect(logger.responseHeader, isFalse);
  });
}
