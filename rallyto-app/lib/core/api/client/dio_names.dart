/// Instance names of the app's two Dio clients in get_it.
class DioNames {
  DioNames._();

  /// Sign-in endpoints, the token refresh and the retries after it. No auth interceptor.
  static const String auth = 'authDio';

  /// Every other API call. Carries the access token, and renews it on a 401.
  static const String api = 'apiDio';
}
