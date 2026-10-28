import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/profile_models.dart';

part 'profile_api.g.dart';

/// The profile, player and block endpoints, on the `apiDio` client (every one needs a signed-in player).
@RestApi()
abstract class ProfileApi {
  factory ProfileApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _ProfileApi;

  @POST(ApiPaths.profile)
  Future<ApiResponse<MyProfileModel>> createProfile(@Body() CreateProfileRequest body);

  @GET(ApiPaths.profileMe)
  Future<ApiResponse<MyProfileModel>> me();

  @PUT(ApiPaths.profile)
  Future<ApiResponse<MyProfileModel>> updateProfile(@Body() UpdateProfileRequest body);

  @PUT(ApiPaths.profileSport)
  Future<ApiResponse<MyProfileModel>> setSport(@Path('sportId') String sportId, @Body() SportProfileInputModel body);

  @DELETE(ApiPaths.profileSport)
  Future<ApiResponse<MyProfileModel>> removeSport(@Path('sportId') String sportId);

  @PUT(ApiPaths.profileHomeVenues)
  Future<ApiResponse<MyProfileModel>> setHomeVenues(@Body() HomeVenuesRequest body);

  @PUT(ApiPaths.profileVisibility)
  Future<ApiResponse<MyProfileModel>> setVisibility(@Body() VisibilityRequest body);

  @PUT(ApiPaths.profilePhoto)
  @MultiPart()
  Future<ApiResponse<MyProfileModel>> uploadPhoto(@Part(name: 'file') MultipartFile file);

  @DELETE(ApiPaths.profilePhoto)
  Future<ApiResponse<MyProfileModel>> removePhoto();

  @GET(ApiPaths.player)
  Future<ApiResponse<PlayerProfileModel>> player(@Path('userId') String userId);

  @GET(ApiPaths.blocks)
  Future<ApiResponse<List<BlockedPlayerModel>>> blocks();

  /// 204, no body.
  @POST(ApiPaths.block)
  Future<void> block(@Path('userId') String userId);

  /// 204, no body.
  @DELETE(ApiPaths.block)
  Future<void> unblock(@Path('userId') String userId);
}

/// Registers [ProfileApi] with get_it.
@module
abstract class ProfileModule {
  @lazySingleton
  ProfileApi profileApi(@Named(DioNames.api) Dio dio) => ProfileApi(dio);
}
