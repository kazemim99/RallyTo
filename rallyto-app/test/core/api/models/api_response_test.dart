import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/models/api_response.dart';
import 'package:rallyto_app/core/api/models/auth_models.dart';

/// The envelope exactly as the forked AsanRezerve middleware writes it: `ApiResponseMiddleware` for success (numeric
/// statusCode, metadata with duration and version) and `ExceptionHandlingMiddleware` for errors (statusCode as a
/// STRING, `error: { code, message, errors: { field: [..] } }`).
void main() {
  test('reads a success envelope with typed data and metadata', () {
    final response = ApiResponse<OtpSendResponse>.fromJson({
      'success': true,
      'statusCode': 200,
      'message': 'Request completed successfully',
      'data': {'expiresInSeconds': 300, 'resendAfterSeconds': 60},
      'metadata': {
        'requestId': '0HN7:00000001',
        'traceId': '4bf92f3577b34da6a3ce929d0e0e4736',
        'timestamp': '2026-10-23T08:30:00.123+00:00',
        'duration': 42,
        'path': '/api/v1/auth/otp/send',
        'method': 'POST',
        'version': '1.0',
      },
    }, (json) => OtpSendResponse.fromJson(json! as Map<String, dynamic>));

    expect(response.success, isTrue);
    expect(response.isSuccess, isTrue);
    expect(response.statusCode, 200);
    expect(response.data?.expiresInSeconds, 300);
    expect(response.data?.resendAfterSeconds, 60);
    expect(response.error, isNull);
    expect(response.metadata?.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
    expect(response.metadata?.timestamp, DateTime.utc(2026, 10, 23, 8, 30, 0, 123));
    expect(response.metadata?.duration, 42);
    expect(response.metadata?.version, '1.0');
  });

  test('reads an error envelope, whose statusCode is a string', () {
    final response = ApiResponse<Object?>.fromJson({
      'success': false,
      'statusCode': '400',
      'message': 'Validation failed for property PhoneNumber',
      'data': null,
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'Validation failed for property PhoneNumber',
        'errors': {
          'PhoneNumber': ['شماره موبایل معتبر نیست'],
        },
      },
      'metadata': {
        'requestId': '0HN7:00000002',
        'traceId': 'abc',
        'timestamp': '2026-10-23T08:30:00+00:00',
        'path': '/api/v1/auth/otp/send',
        'method': 'POST',
      },
    }, (json) => json);

    expect(response.success, isFalse);
    expect(response.isSuccess, isFalse);
    expect(response.statusCode, 400);
    expect(response.data, isNull);
    expect(response.error?.code, 'VALIDATION_ERROR');
    expect(response.error?.errors, {
      'PhoneNumber': ['شماره موبایل معتبر نیست'],
    });
    expect(response.firstFieldError, 'شماره موبایل معتبر نیست');
    expect(response.metadata?.duration, isNull);
  });

  test('reads a body with members missing, and data that is a bare value', () {
    final response = ApiResponse<String>.fromJson({'data': 'ok'}, (json) => json! as String);

    expect(response.success, isFalse, reason: 'success is only what the server says it is');
    expect(response.statusCode, isNull);
    expect(response.data, 'ok');
    expect(response.firstFieldError, isNull);
  });

  test('reads top-level per-field errors when the envelope carries them there', () {
    final response = ApiResponse<Object?>.fromJson({
      'success': false,
      'statusCode': 422,
      'errors': {
        'Code': ['کد واردشده درست نیست'],
      },
    }, (json) => json);

    expect(response.firstFieldError, 'کد واردشده درست نیست');
  });
}
