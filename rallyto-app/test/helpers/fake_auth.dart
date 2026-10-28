import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/api/models/api_response.dart';
import 'package:rallyto_app/core/api/models/auth_models.dart';
import 'package:rallyto_app/core/auth/auth_session.dart';
import 'package:rallyto_app/core/utils/countdown.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/auth/domain/auth_repository.dart';
import 'package:rallyto_app/features/auth/domain/otp_challenge.dart';

/// A [Countdown] the test drives: each [start] opens a stream that ticks only on [tick].
class FakeCountdown implements Countdown {
  final List<int> started = [];
  StreamController<int>? _ticks;

  @override
  Duration get period => const Duration(seconds: 1);

  @override
  Stream<int> start(int seconds) {
    started.add(seconds);
    unawaited(_ticks?.close());
    final ticks = StreamController<int>();
    _ticks = ticks;
    return ticks.stream;
  }

  /// One second passed; [secondsLeft] remain.
  void tick(int secondsLeft) => _ticks?.add(secondsLeft);

  /// Ticks every remaining second down to 0.
  void runOut(int from) {
    for (var left = from - 1; left >= 0; left--) {
      tick(left);
    }
  }
}

/// An [AuthRepository] answering with whatever the test queued, recording what it was asked.
class FakeAuthRepository implements AuthRepository {
  final List<String> sentTo = [];
  final List<(String, String)> verified = [];

  /// Answers for [sendCode], in order; the last one repeats.
  List<Either<AuthFailure, OtpChallenge> Function(String phone)> sendAnswers = [(phone) => Right(challengeFor(phone))];

  /// Answers for [verifyCode], in order; the last one repeats.
  List<Either<AuthFailure, AuthSession>> verifyAnswers = [Right(sessionFromServer())];

  /// When set, every call waits on it, so a test can look at the in-between state.
  Completer<void>? gate;

  @override
  Future<Either<AuthFailure, OtpChallenge>> sendCode(String phoneNumber) async {
    sentTo.add(phoneNumber);
    await gate?.future;
    final answer = sendAnswers.length > 1 ? sendAnswers.removeAt(0) : sendAnswers.single;
    return answer(phoneNumber);
  }

  @override
  Future<Either<AuthFailure, AuthSession>> verifyCode({required String phoneNumber, required String code}) async {
    verified.add((phoneNumber, code));
    await gate?.future;
    return verifyAnswers.length > 1 ? verifyAnswers.removeAt(0) : verifyAnswers.single;
  }
}

OtpChallenge challengeFor(String phone, {int resendAfterSeconds = 60}) =>
    OtpChallenge(phoneNumber: phone, expiresInSeconds: 300, resendAfterSeconds: resendAfterSeconds);

AuthSession sessionFromServer({bool profileCompleted = false}) => AuthSession(
  accessToken: 'access-new',
  refreshToken: 'refresh-new',
  profileCompleted: profileCompleted,
  roles: const ['Player'],
);

/// An [AuthApi] for widget tests: answers sign-in calls as the test says, and records sign-outs.
class FakeAuthApi implements AuthApi {
  final List<String> sentTo = [];
  final List<OtpVerifyRequest> verified = [];
  final List<(String, String?)> signedOut = [];

  bool profileCompleted = false;

  /// When set, `sendOtp` / `verifyOtp` throw it instead of answering.
  DioException? sendError;
  DioException? verifyError;

  @override
  Future<ApiResponse<OtpSendResponse>> sendOtp(OtpSendRequest body) async {
    sentTo.add(body.phoneNumber);
    if (sendError != null) throw sendError!;
    return const ApiResponse(
      success: true,
      statusCode: 200,
      data: OtpSendResponse(expiresInSeconds: 300, resendAfterSeconds: 60),
    );
  }

  @override
  Future<ApiResponse<TokenResponse>> verifyOtp(OtpVerifyRequest body) async {
    verified.add(body);
    if (verifyError != null) throw verifyError!;
    return ApiResponse(
      success: true,
      statusCode: 200,
      data: TokenResponse(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        profileCompleted: profileCompleted,
        roles: const ['Player'],
      ),
    );
  }

  @override
  Future<ApiResponse<TokenResponse>> refresh(RefreshTokenRequest body) => throw UnimplementedError();

  @override
  Future<void> signOut(RefreshTokenRequest body, String? authorization) async {
    signedOut.add((body.refreshToken, authorization));
  }
}

/// A failed API call as Dio reports it: the error envelope, with a `Retry-After` header when [retryAfter] is set.
DioException apiError(int status, String code, String message, {int? retryAfter}) {
  final options = RequestOptions(path: '/api/v1/auth');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': ['$retryAfter'],
      }),
      data: {
        'success': false,
        'statusCode': status,
        'message': message,
        'data': null,
        'error': {'code': code, 'message': message},
      },
    ),
  );
}
