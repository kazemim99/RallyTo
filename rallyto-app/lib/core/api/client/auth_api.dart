import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';

part 'auth_api.g.dart';

/// The sign-in endpoints. Called on the `authDio` client, which carries no `AuthInterceptor`: these requests carry
/// no access token, and a 401 from them must never start a refresh.
@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _AuthApi;

  @POST(ApiPaths.otpSend)
  Future<ApiResponse<OtpSendResponse>> sendOtp(@Body() OtpSendRequest body);

  @POST(ApiPaths.otpVerify)
  Future<ApiResponse<TokenResponse>> verifyOtp(@Body() OtpVerifyRequest body);

  @POST(ApiPaths.refresh)
  Future<ApiResponse<TokenResponse>> refresh(@Body() RefreshTokenRequest body);

  /// 204, no body. [authorization] is `Bearer <access token>` when there is one: this client adds no token itself.
  @POST(ApiPaths.signOut)
  Future<void> signOut(@Body() RefreshTokenRequest body, @Header('Authorization') String? authorization);
}
