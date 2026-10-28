import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../config/api_config.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/error_interceptor.dart';
import 'auth_api.dart';
import 'dio_names.dart';

/// Builds a Dio for the API: base URL, timeouts, JSON and Persian headers, the given interceptors, and request
/// logging in debug builds only.
class DioFactory {
  DioFactory._();

  static Dio create({List<Interceptor> interceptors = const [], bool logging = kDebugMode, String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        contentType: Headers.jsonContentType,
        headers: {'Accept': Headers.jsonContentType, 'Accept-Language': ApiConfig.acceptLanguage},
      ),
    );
    dio.interceptors.addAll(interceptors);
    if (logging) {
      // Last, so it logs what was really sent and the final outcome. Headers are left out: they carry the token.
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          responseHeader: false,
          requestBody: true,
          responseBody: true,
          logPrint: _log,
        ),
      );
    }
    return dio;
  }

  static void _log(Object line) => debugPrint('$line');
}

/// Registers the HTTP clients and secure storage with get_it.
@module
abstract class NetworkModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  @Named(DioNames.auth)
  @lazySingleton
  Dio authDio(ErrorInterceptor errors) => DioFactory.create(interceptors: [errors]);

  /// Interceptor order matters: [AuthInterceptor] sees a 401 first and may resolve it with a retry; only what it
  /// passes on reaches [ErrorInterceptor].
  @Named(DioNames.api)
  @lazySingleton
  Dio apiDio(AuthInterceptor auth, ErrorInterceptor errors) => DioFactory.create(interceptors: [auth, errors]);

  @lazySingleton
  AuthApi authApi(@Named(DioNames.auth) Dio dio) => AuthApi(dio);
}
