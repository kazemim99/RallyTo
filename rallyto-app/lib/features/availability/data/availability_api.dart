import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/availability_models.dart';

part 'availability_api.g.dart';

/// The availability endpoints, on the `apiDio` client.
@RestApi()
abstract class AvailabilityApi {
  factory AvailabilityApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _AvailabilityApi;

  @GET(ApiPaths.availability)
  Future<ApiResponse<List<AvailabilityViewModel>>> mine();

  @GET(ApiPaths.playerAvailability)
  Future<ApiResponse<List<AvailabilityViewModel>>> forPlayer(@Path('userId') String userId);

  @POST(ApiPaths.availability)
  Future<ApiResponse<AvailabilityViewModel>> create(@Body() AvailabilityInputModel body);

  @PUT(ApiPaths.availabilityWindow)
  Future<ApiResponse<AvailabilityViewModel>> update(@Path('id') String id, @Body() AvailabilityInputModel body);

  @POST(ApiPaths.availabilityPause)
  Future<ApiResponse<AvailabilityViewModel>> pause(@Path('id') String id);

  @POST(ApiPaths.availabilityResume)
  Future<ApiResponse<AvailabilityViewModel>> resume(@Path('id') String id);

  @POST(ApiPaths.availabilityConfirm)
  Future<ApiResponse<AvailabilityViewModel>> confirm(@Path('id') String id);

  /// 204, no body.
  @DELETE(ApiPaths.availabilityWindow)
  Future<void> delete(@Path('id') String id);
}

/// Registers [AvailabilityApi] with get_it.
@module
abstract class AvailabilityModule {
  @lazySingleton
  AvailabilityApi availabilityApi(@Named(DioNames.api) Dio dio) => AvailabilityApi(dio);
}
