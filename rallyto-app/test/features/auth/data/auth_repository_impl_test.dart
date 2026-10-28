import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/config/api_config.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';
import 'package:rallyto_app/core/auth/auth_error_codes.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/auth/data/auth_repository_impl.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/auth/domain/otp_challenge.dart';

/// The sign-in calls over the real client stack (`authDio`: error interceptor, retrofit, envelope), against the
/// backend's contract: success data, error envelopes with Persian messages, and `Retry-After` on 429.
void main() {
  late _FakeServer server;
  late AuthRepositoryImpl repository;

  setUp(() {
    server = _FakeServer();
    final dio = DioFactory.create(baseUrl: 'https://api.test', interceptors: [ErrorInterceptor()], logging: false)
      ..httpClientAdapter = server;
    repository = AuthRepositoryImpl(AuthApi(dio));
  });

  AuthFailure failureOf<T>(Either<AuthFailure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  group('send code', () {
    test('sends the canonical number and reads the timings', () async {
      server.answer = (_) => _ok({'expiresInSeconds': 300, 'resendAfterSeconds': 60});

      final result = await repository.sendCode('09121234567');

      expect(server.requests.single.path, ApiPaths.otpSend);
      expect(server.requests.single.data, {'phoneNumber': '09121234567'});
      expect(
        result.getOrElse(() => fail('expected a challenge')),
        const OtpChallenge(phoneNumber: '09121234567', expiresInSeconds: 300, resendAfterSeconds: 60),
      );
    });

    test("a 429 carries the server's message, code and Retry-After seconds", () async {
      const message = 'لطفاً ۴۲ ثانیه دیگر دوباره تلاش کنید';
      server.answer = (_) => _error(429, AuthErrorCodes.otpResendTooSoon, message, headers: {'Retry-After': '42'});

      final failure = failureOf(await repository.sendCode('09121234567'));

      expect(failure.message, message);
      expect(failure.code, AuthErrorCodes.otpResendTooSoon);
      expect(failure.statusCode, 429);
      expect(failure.retryAfterSeconds, 42);
    });

    test('a 400 INVALID_PHONE_NUMBER carries its message, and no wait', () async {
      const message = 'شماره موبایل معتبر نیست';
      server.answer = (_) => _error(400, AuthErrorCodes.invalidPhoneNumber, message);

      final failure = failureOf(await repository.sendCode('0912'));

      expect(failure.message, message);
      expect(failure.code, AuthErrorCodes.invalidPhoneNumber);
      expect(failure.retryAfterSeconds, isNull);
    });

    test('a 503 SMS_SEND_FAILED carries its message', () async {
      const message = 'ارسال پیامک ممکن نشد';
      server.answer = (_) => _error(503, AuthErrorCodes.smsSendFailed, message);

      final failure = failureOf(await repository.sendCode('09121234567'));

      expect(failure.message, message);
      expect(failure.statusCode, 503);
    });

    test('no connection is said as such', () async {
      server.answer = (options) => throw DioException.connectionError(requestOptions: options, reason: 'offline');

      final failure = failureOf(await repository.sendCode('09121234567'));

      expect(failure.message, AppStrings.offlineActionError);
    });
  });

  group('verify code', () {
    test('trades the code for a session, with the onboarding state and roles', () async {
      server.answer = (_) => _ok({
        'accessToken': 'access-1',
        'accessTokenExpiresAt': '2026-10-23T12:15:00+00:00',
        'refreshToken': 'refresh-1',
        'refreshTokenExpiresAt': '2026-11-22T12:00:00+00:00',
        'profileCompleted': true,
        'roles': ['Player'],
      });

      final result = await repository.verifyCode(phoneNumber: '09121234567', code: '4821');

      expect(server.requests.single.path, ApiPaths.otpVerify);
      expect(server.requests.single.data, {'phoneNumber': '09121234567', 'code': '4821'});
      final session = result.getOrElse(() => fail('expected a session'));
      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.profileCompleted, isTrue);
      expect(session.roles, ['Player']);
      expect(session.refreshTokenExpiresAt, DateTime.utc(2026, 11, 22, 12));
    });

    test('a wrong code is a 400 CODE_INVALID with its message', () async {
      const message = 'کد واردشده اشتباه است';
      server.answer = (_) => _error(400, AuthErrorCodes.codeInvalid, message);

      final failure = failureOf(await repository.verifyCode(phoneNumber: '09121234567', code: '1111'));

      expect(failure.message, message);
      expect(failure.code, AuthErrorCodes.codeInvalid);
      expect(failure.isAccountBlocked, isFalse);
    });

    test(
      'a suspended account is a 403 whose message (with the Jalali end date) is kept, and counts as blocked',
      () async {
        const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';
        server.answer = (_) => _error(403, AuthErrorCodes.accountSuspended, message);

        final failure = failureOf(await repository.verifyCode(phoneNumber: '09121234567', code: '4821'));

        expect(failure.message, message);
        expect(failure.isAccountBlocked, isTrue);
      },
    );
  });

  test('Retry-After: whole seconds only', () {
    expect(AuthRepositoryImpl.retryAfterSeconds('60'), 60);
    expect(AuthRepositoryImpl.retryAfterSeconds(' 5 '), 5);
    expect(AuthRepositoryImpl.retryAfterSeconds(null), isNull);
    expect(AuthRepositoryImpl.retryAfterSeconds('0'), isNull);
    expect(AuthRepositoryImpl.retryAfterSeconds('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
  });
}

class _FakeServer implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options) answer = (_) => _ok(null);
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(Object? data) => _json(200, {
  'success': true,
  'statusCode': 200,
  'message': 'Request completed successfully',
  'data': data,
  'metadata': {'traceId': 'trace-1'},
});

ResponseBody _error(int status, String code, String message, {Map<String, String> headers = const {}}) =>
    _json(status, {
      'success': false,
      'statusCode': status,
      'message': message,
      'data': null,
      'error': {'code': code, 'message': message},
      'metadata': {'traceId': 'trace-1'},
    }, headers: headers);

ResponseBody _json(int status, Object body, {Map<String, String> headers = const {}}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    for (final entry in headers.entries) entry.key.toLowerCase(): [entry.value],
  },
);
