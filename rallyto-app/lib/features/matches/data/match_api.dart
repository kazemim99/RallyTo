import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/match_models.dart';

part 'match_api.g.dart';

/// The match endpoints, on the `apiDio` client.
@RestApi()
abstract class MatchApi {
  factory MatchApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _MatchApi;

  @POST(ApiPaths.matchPosts)
  Future<ApiResponse<MatchViewModel>> createPost(@Body() MatchInputModel body);

  @POST(ApiPaths.matchInvitations)
  Future<ApiResponse<MatchViewModel>> createInvitation(@Body() InvitationInputModel body);

  /// [scope] is `upcoming` or `past`.
  @GET(ApiPaths.myMatches)
  Future<ApiResponse<List<MatchViewModel>>> mine(@Query('scope') String scope);

  @GET(ApiPaths.match)
  Future<ApiResponse<MatchViewModel>> get(@Path('id') String id);

  @GET(ApiPaths.matchByToken)
  Future<ApiResponse<MatchViewModel>> byToken(@Path('token') String token);

  @POST(ApiPaths.matchCancel)
  Future<ApiResponse<MatchViewModel>> cancel(@Path('id') String id, @Body() CancelRequestModel body);

  @POST(ApiPaths.matchJoin)
  Future<ApiResponse<MatchViewModel>> join(@Path('id') String id, @Body() JoinRequestModel body);

  @POST(ApiPaths.matchWithdraw)
  Future<ApiResponse<MatchViewModel>> withdraw(@Path('id') String id);

  @POST(ApiPaths.matchAcceptRequest)
  Future<ApiResponse<MatchViewModel>> acceptRequest(@Path('id') String id, @Path('playerId') String playerId);

  @POST(ApiPaths.matchDeclineRequest)
  Future<ApiResponse<MatchViewModel>> declineRequest(@Path('id') String id, @Path('playerId') String playerId);

  @POST(ApiPaths.matchInvite)
  Future<ApiResponse<MatchViewModel>> invite(@Path('id') String id, @Body() InviteRequestModel body);

  @POST(ApiPaths.matchAcceptInvitation)
  Future<ApiResponse<MatchViewModel>> acceptInvitation(@Path('id') String id);

  @POST(ApiPaths.matchDeclineInvitation)
  Future<ApiResponse<MatchViewModel>> declineInvitation(@Path('id') String id);

  @POST(ApiPaths.matchConfirm)
  Future<ApiResponse<MatchViewModel>> confirm(@Path('id') String id);

  @POST(ApiPaths.matchLeave)
  Future<ApiResponse<MatchViewModel>> leave(@Path('id') String id);

  @POST(ApiPaths.matchRemoveParticipant)
  Future<ApiResponse<MatchViewModel>> removeParticipant(@Path('id') String id, @Path('playerId') String playerId);

  @POST(ApiPaths.matchShareToken)
  Future<ApiResponse<MatchViewModel>> regenerateShareToken(@Path('id') String id);

  @POST(ApiPaths.matchAttendance)
  Future<ApiResponse<MatchViewModel>> answerAttendance(@Path('id') String id, @Body() AttendanceRequestModel body);
}

/// Registers [MatchApi] with get_it.
@module
abstract class MatchModule {
  @lazySingleton
  MatchApi matchApi(@Named(DioNames.api) Dio dio) => MatchApi(dio);
}
