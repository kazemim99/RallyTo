import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/config/api_config.dart';

void main() {
  test('the base URL is the compiled-in one when given, else the Android emulator host', () {
    const override = String.fromEnvironment('API_BASE_URL');
    expect(ApiConfig.baseUrl, override.isEmpty ? 'http://10.0.2.2:5100' : ApiConfig.resolveBaseUrl(override));
  });

  test('an override wins, without its trailing slash; an empty one falls back to the default', () {
    expect(ApiConfig.resolveBaseUrl('https://api.rallyto.ir/'), 'https://api.rallyto.ir');
    expect(ApiConfig.resolveBaseUrl('  https://api.rallyto.ir  '), 'https://api.rallyto.ir');
    expect(ApiConfig.resolveBaseUrl(''), 'http://10.0.2.2:5100');
    expect(ApiConfig.resolveBaseUrl('   '), 'http://10.0.2.2:5100');
  });

  test('auth paths follow api/v1', () {
    expect(ApiPaths.otpSend, '/api/v1/auth/otp/send');
    expect(ApiPaths.otpVerify, '/api/v1/auth/otp/verify');
    expect(ApiPaths.refresh, '/api/v1/auth/refresh');
  });
}
