import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/api/models/auth_models.dart';
import 'models/account_models.dart';

part 'account_api.g.dart';

/// The player's own account endpoints, on the `apiDio` client (both need a signed-in player).
@RestApi()
abstract class AccountApi {
  factory AccountApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _AccountApi;

  /// Sends an SMS code to the account's phone number; answers the code's timings, as sign-in does.
  @POST(ApiPaths.accountDeletionCode)
  Future<ApiResponse<OtpSendResponse>> requestDeletionCode();

  /// 204, no body.
  @POST(ApiPaths.accountDeletion)
  Future<void> deleteAccount(@Body() AccountDeletionRequest body);
}

/// Registers [AccountApi] with get_it.
@module
abstract class AccountModule {
  @lazySingleton
  AccountApi accountApi(@Named(DioNames.api) Dio dio) => AccountApi(dio);
}
