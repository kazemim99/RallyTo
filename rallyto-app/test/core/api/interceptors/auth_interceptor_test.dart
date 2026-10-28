import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/config/api_config.dart';
import 'package:rallyto_app/core/api/interceptors/auth_interceptor.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/dio_failure_mapper.dart';
import 'package:rallyto_app/core/errors/failures.dart';

import '../../../helpers/memory_secure_storage.dart';

/// Refresh tokens are single-use: refreshing rotates them, and the old one is refused from then on. When the access
/// token expires, every request in flight fails with 401 together. Each must not refresh on its own — all but the
/// first would send a used token, be refused, and end the session — so they share ONE refresh and all retry with it.
void main() {
  const baseUrl = 'https://api.test';
  const me = '/api/v1/players/me';
  const matches = '/api/v1/matches';

  late TokenStorage tokens;
  late _FakeApi server;
  late Dio dio;

  setUp(() async {
    tokens = memoryTokenStorage();
    await tokens.saveSession(testSession(accessToken: 'access-1', refreshToken: 'refresh-1'));
    server = _FakeApi();
    final authDio = DioFactory.create(baseUrl: baseUrl, interceptors: [ErrorInterceptor()], logging: false)
      ..httpClientAdapter = server;
    dio = DioFactory.create(
      baseUrl: baseUrl,
      interceptors: [AuthInterceptor(tokens, authDio), ErrorInterceptor()],
      logging: false,
    )..httpClientAdapter = server;
  });

  test('two concurrent 401s trigger exactly one refresh, and both requests retry with the new token', () async {
    final answers = await Future.wait([dio.get<dynamic>(me), dio.get<dynamic>(matches)]);

    expect(answers.map((r) => r.statusCode), [200, 200]);
    expect(server.refreshes, 1, reason: 'a second refresh with the same single-use token would be refused');
    expect(server.refreshBodies.single, {'refreshToken': 'refresh-1'});
    expect(server.calls[me], ['Bearer access-1', 'Bearer access-2'], reason: 'sent, refused, retried once');
    expect(server.calls[matches], ['Bearer access-1', 'Bearer access-2'], reason: 'sent, refused, retried once');
    expect(AuthInterceptor.isRefreshing, isFalse);

    final session = await tokens.readSession();
    expect(session?.accessToken, 'access-2');
    expect(session?.refreshToken, 'refresh-2', reason: 'the rotated refresh token replaces the used one');
    expect(session?.profileCompleted, isTrue);
  });

  test('a refused refresh ends the session once, and both requests fail as "sign in again"', () async {
    server.refreshStatus = 401;

    final errors = await Future.wait([_errorOf(dio.get<dynamic>(me)), _errorOf(dio.get<dynamic>(matches))]);

    expect(errors.map((e) => e.response?.statusCode), [401, 401]);
    expect(server.refreshes, 1);
    expect(server.calls[me], ['Bearer access-1'], reason: 'nothing to retry with');
    expect(await tokens.readSession(), isNull, reason: 'the server refused the refresh token: the session is over');
    expect(errors.map(mapDioFailure), everyElement(isA<SessionExpiredFailure>()));
  });

  test('a refresh that gets no answer keeps the session and fails the requests as offline', () async {
    server.refreshUnreachable = true;

    final errors = await Future.wait([_errorOf(dio.get<dynamic>(me)), _errorOf(dio.get<dynamic>(matches))]);

    expect(errors.map((e) => e.type), everyElement(DioExceptionType.connectionError));
    expect(errors.map((e) => e.message), everyElement(AppStrings.connectionError));
    expect(server.refreshes, 1);
    expect((await tokens.readSession())?.refreshToken, 'refresh-1', reason: 'an offline blip must not sign out');
    expect(errors.map(mapDioFailure), everyElement(isA<NetworkFailure>()));
  });

  test('a 401 for a token another request already renewed retries without refreshing again', () async {
    // While the request is out with access-1, another request's refresh lands access-2.
    server.beforeAnswer = () => tokens.saveSession(testSession(accessToken: 'access-2', refreshToken: 'refresh-2'));

    final answer = await dio.get<dynamic>(me);

    expect(answer.statusCode, 200);
    expect(server.refreshes, 0);
    expect(server.calls[me], ['Bearer access-1', 'Bearer access-2']);
  });

  group('a 401 for an account the server ended', () {
    const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';

    for (final code in ['ACCOUNT_SUSPENDED', 'ACCOUNT_BANNED', 'ACCOUNT_INACTIVE']) {
      test('$code: no refresh; the session is cleared with the server message', () async {
        server.accountEnded = (code, message);
        final reasons = <String>[];
        final subscription = tokens.signOutReasons.listen(reasons.add);

        final error = await _errorOf(dio.get<dynamic>(me));
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(server.refreshes, 0, reason: 'renewing the token cannot lift a suspension');
        expect(server.calls[me], ['Bearer access-1'], reason: 'not retried');
        expect(await tokens.readSession(), isNull);
        expect(reasons, [message]);
        expect(error.response?.statusCode, 401);
        final failure = mapDioFailure(error);
        expect(failure, isA<SessionExpiredFailure>());
        expect(failure.message, message, reason: "the player reads the server's words, not «sign in again»");
      });
    }

    test('after a refresh, the retry being refused ends the session the same way', () async {
      server.accountEndedAfterRefresh = ('ACCOUNT_BANNED', message);
      final reasons = <String>[];
      final subscription = tokens.signOutReasons.listen(reasons.add);

      await _errorOf(dio.get<dynamic>(me));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(server.refreshes, 1);
      expect(await tokens.readSession(), isNull);
      expect(reasons, [message]);
    });

    test('a plain 401 still refreshes, with no message', () async {
      final reasons = <String>[];
      final subscription = tokens.signOutReasons.listen(reasons.add);

      await dio.get<dynamic>(me);
      await subscription.cancel();

      expect(server.refreshes, 1);
      expect(reasons, isEmpty);
    });
  });

  test('without a session, a request goes out with no token and a 401 is final', () async {
    await tokens.clear();

    final error = await _errorOf(dio.get<dynamic>(me));

    expect(server.calls[me], [null]);
    expect(server.refreshes, 0, reason: 'there is no refresh token to send');
    expect(error.response?.statusCode, 401);
  });
}

Future<DioException> _errorOf(Future<Object?> request) async {
  try {
    await request;
  } on DioException catch (e) {
    return e;
  }
  fail('expected the request to fail');
}

/// The API: 401 for any request without the current token (access-2), 200 with it. The first refresh with
/// refresh-1 rotates it to refresh-2; any later refresh with refresh-1 is refused, as the real server does.
class _FakeApi implements HttpClientAdapter {
  int refreshStatus = 200;
  bool refreshUnreachable = false;

  /// When set, every request answers 401 with this (code, message).
  (String, String)? accountEnded;

  /// When set, requests with the renewed token answer 401 with this (code, message).
  (String, String)? accountEndedAfterRefresh;
  FutureOr<void> Function()? beforeAnswer;

  int refreshes = 0;
  final List<Object?> refreshBodies = [];
  final Map<String, List<Object?>> calls = {};
  bool _rotated = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));

    if (options.path == ApiPaths.refresh) {
      refreshes++;
      refreshBodies.add(options.data);
      if (refreshUnreachable) throw DioException.connectionError(requestOptions: options, reason: 'offline');
      if (refreshStatus != 200 || _rotated) return _error(401, 'INVALID_REFRESH_TOKEN', 'Invalid refresh token');
      _rotated = true;
      return _json(200, {
        'success': true,
        'statusCode': 200,
        'message': 'Request completed successfully',
        'data': {
          'accessToken': 'access-2',
          'accessTokenExpiresAt': '2026-10-23T12:15:00+00:00',
          'refreshToken': 'refresh-2',
          'refreshTokenExpiresAt': '2026-11-22T12:00:00+00:00',
          'profileCompleted': true,
          'roles': ['Player'],
        },
      });
    }

    calls.putIfAbsent(options.path, () => []).add(options.headers['Authorization']);
    final hook = beforeAnswer;
    beforeAnswer = null;
    await hook?.call();
    final ended =
        accountEnded ?? (options.headers['Authorization'] == 'Bearer access-2' ? accountEndedAfterRefresh : null);
    if (ended != null) return _error(401, ended.$1, ended.$2);
    return options.headers['Authorization'] == 'Bearer access-2'
        ? _json(200, {
            'success': true,
            'statusCode': 200,
            'data': {'path': options.path},
          })
        : _error(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  ResponseBody _error(int status, String code, String message) => _json(status, {
    'success': false,
    'statusCode': '$status',
    'message': message,
    'data': null,
    'error': {'code': code, 'message': message, 'errors': null},
  });

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
