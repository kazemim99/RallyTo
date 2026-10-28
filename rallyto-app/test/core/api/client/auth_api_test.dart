import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/models/auth_models.dart';

/// The sign-in contract the backend implements: paths, request bodies and the shapes of `data`.
void main() {
  late _RecordingApi server;
  late AuthApi api;

  setUp(() {
    server = _RecordingApi();
    api = AuthApi(DioFactory.create(baseUrl: 'https://api.test', logging: false)..httpClientAdapter = server);
  });

  test('POST /api/v1/auth/otp/send with the phone number; answers expiry and resend wait', () async {
    server.answer = {'expiresInSeconds': 300, 'resendAfterSeconds': 60};

    final response = await api.sendOtp(const OtpSendRequest(phoneNumber: '09121234567'));

    expect(server.method, 'POST');
    expect(server.uri, Uri.parse('https://api.test/api/v1/auth/otp/send'));
    expect(server.body, {'phoneNumber': '09121234567'});
    expect(response.data?.expiresInSeconds, 300);
    expect(response.data?.resendAfterSeconds, 60);
  });

  test('POST /api/v1/auth/otp/verify with phone number and code; answers a token pair', () async {
    server.answer = _tokens(profileCompleted: false);

    final response = await api.verifyOtp(const OtpVerifyRequest(phoneNumber: '09121234567', code: '12345'));

    expect(server.uri.path, '/api/v1/auth/otp/verify');
    expect(server.body, {'phoneNumber': '09121234567', 'code': '12345'});
    final tokens = response.data!;
    expect(tokens.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(tokens.accessTokenExpiresAt, DateTime.utc(2026, 10, 23, 8, 45));
    expect(tokens.refreshTokenExpiresAt, DateTime.utc(2026, 11, 22, 8, 30));
    expect(tokens.profileCompleted, isFalse);
    expect(tokens.roles, ['Player']);
  });

  test('POST /api/v1/auth/refresh with the refresh token; answers the same token shape', () async {
    server.answer = _tokens(profileCompleted: true);

    final response = await api.refresh(const RefreshTokenRequest(refreshToken: 'refresh'));

    expect(server.uri.path, '/api/v1/auth/refresh');
    expect(server.body, {'refreshToken': 'refresh'});
    expect(response.data?.profileCompleted, isTrue);
  });

  test('a token pair without profileCompleted or roles reads as not onboarded, with no roles', () {
    final tokens = TokenResponse.fromJson({'accessToken': 'a', 'refreshToken': 'r'});

    expect(tokens.profileCompleted, isFalse);
    expect(tokens.roles, isEmpty);
    expect(tokens.accessTokenExpiresAt, isNull);
  });
}

Map<String, Object?> _tokens({required bool profileCompleted}) => {
  'accessToken': 'access',
  'accessTokenExpiresAt': '2026-10-23T08:45:00Z',
  'refreshToken': 'refresh',
  'refreshTokenExpiresAt': '2026-11-22T08:30:00Z',
  'profileCompleted': profileCompleted,
  'roles': ['Player'],
};

/// Records the request and answers [answer] inside the success envelope.
class _RecordingApi implements HttpClientAdapter {
  Object? answer;
  late String method;
  late Uri uri;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    uri = options.uri;
    final bytes = await requestStream?.expand((chunk) => chunk).toList();
    body = bytes == null ? null : jsonDecode(utf8.decode(bytes));
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'statusCode': 200, 'message': 'Request completed successfully', 'data': answer}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
