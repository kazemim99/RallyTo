import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/account/data/account_api.dart';
import 'package:rallyto_app/features/account/data/account_repository_impl.dart';
import 'package:rallyto_app/features/account/domain/account_repository.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';

import '../../../helpers/fake_server.dart';

/// Account deletion over the real client stack, against the backend's contract (AccountController, SessionTests ›
/// deletion): the code request answers its timings, the deletion takes `{code}` and answers 204, and refusals carry
/// the server's code, its Persian message and the `Retry-After` wait.
void main() {
  late FakeServer server;
  late AccountRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = AccountRepositoryImpl(AccountApi(server.dio()));
  });

  T valueOf<T>(Either<AuthFailure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  AuthFailure failureOf<T>(Either<AuthFailure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  group('asking for a deletion code', () {
    test('POSTs with no body and reads how long the code lasts and when another may be asked for', () async {
      server.routes['POST /api/v1/account/deletion/code'] = (_) =>
          okBody({'expiresInSeconds': 120, 'resendAfterSeconds': 60});

      final code = valueOf(await repository.requestDeletionCode());

      expect(code, const DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 60));
      expect(server.calls, ['POST /api/v1/account/deletion/code']);
    });

    test('too soon after the last code: 429 OTP_RESEND_TOO_SOON with the wait from Retry-After', () async {
      server.routes['POST /api/v1/account/deletion/code'] = (_) =>
          _withRetryAfter(429, 'OTP_RESEND_TOO_SOON', 'کمی صبر کنید و دوباره درخواست کد بدهید.', 42);

      final failure = failureOf(await repository.requestDeletionCode());

      expect(failure.code, 'OTP_RESEND_TOO_SOON');
      expect(failure.message, 'کمی صبر کنید و دوباره درخواست کد بدهید.');
      expect(failure.statusCode, 429);
      expect(failure.retryAfterSeconds, 42);
    });

    test('the rate limiter: 429 TOO_MANY_REQUESTS', () async {
      server.routes['POST /api/v1/account/deletion/code'] = (_) =>
          _withRetryAfter(429, 'TOO_MANY_REQUESTS', 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.', 30);

      final failure = failureOf(await repository.requestDeletionCode());

      expect(failure.code, 'TOO_MANY_REQUESTS');
      expect(failure.retryAfterSeconds, 30);
    });
  });

  group('deleting the account', () {
    test('POSTs {code} and takes the 204 with no body', () async {
      server.routes['POST /api/v1/account/deletion'] = (_) => noContentBody();

      final result = await repository.deleteAccount('2222');

      expect(result, const Right<AuthFailure, Unit>(unit));
      expect(server.calls, ['POST /api/v1/account/deletion']);
      expect(server.lastJson, {'code': '2222'});
    });

    test("a wrong code is 400 CODE_INVALID, with the server's Persian message", () async {
      server.routes['POST /api/v1/account/deletion'] = (_) => errorBody(400, 'CODE_INVALID', 'کد واردشده درست نیست.');

      final failure = failureOf(await repository.deleteAccount('0000'));

      expect(failure.code, 'CODE_INVALID');
      expect(failure.message, 'کد واردشده درست نیست.');
      expect(failure.statusCode, 400);
      expect(failure.retryAfterSeconds, isNull);
    });

    test('an old code is 400 CODE_EXPIRED', () async {
      server.routes['POST /api/v1/account/deletion'] = (_) =>
          errorBody(400, 'CODE_EXPIRED', 'کد منقضی شده است. کد جدید بگیرید.');

      expect(failureOf(await repository.deleteAccount('2222')).code, 'CODE_EXPIRED');
    });

    test('offline is the offline message, not a crash', () async {
      server.routes['POST /api/v1/account/deletion'] = (options) =>
          throw DioException.connectionError(requestOptions: options, reason: 'offline');

      expect(failureOf(await repository.deleteAccount('2222')).message, AppStrings.offlineActionError);
    });
  });
}

/// The error envelope with a `Retry-After` header.
ResponseBody _withRetryAfter(int status, String code, String message, int seconds) => ResponseBody.fromString(
  jsonEncode({
    'success': false,
    'statusCode': status,
    'message': message,
    'data': null,
    'error': {'code': code, 'message': message},
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    'retry-after': ['$seconds'],
  },
);
