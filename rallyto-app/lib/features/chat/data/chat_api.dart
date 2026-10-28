import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/chat_models.dart';

part 'chat_api.g.dart';

/// The chat endpoints, on the `apiDio` client.
@RestApi()
abstract class ChatApi {
  factory ChatApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _ChatApi;

  /// [box] is `inbox` or `requests`.
  @GET(ApiPaths.conversations)
  Future<ApiResponse<List<ConversationSummaryModel>>> conversations(@Query('box') String box);

  @GET(ApiPaths.conversationsUnread)
  Future<ApiResponse<UnreadCountsModel>> unread();

  @POST(ApiPaths.conversationDirect)
  Future<ApiResponse<ConversationSummaryModel>> openDirect(@Body() OpenDirectRequestModel body);

  @GET(ApiPaths.conversation)
  Future<ApiResponse<ConversationSummaryModel>> conversation(@Path('id') String id);

  @GET(ApiPaths.matchConversation)
  Future<ApiResponse<ConversationSummaryModel>> matchConversation(@Path('matchId') String matchId);

  @GET(ApiPaths.conversationMessages)
  Future<ApiResponse<MessagePageModel>> history(@Path('id') String id, {@Query('before') String? before});

  @POST(ApiPaths.conversationMessages)
  Future<ApiResponse<MessageViewModel>> send(@Path('id') String id, @Body() SendMessageRequestModel body);

  /// 204, no body.
  @DELETE(ApiPaths.conversationMessage)
  Future<void> deleteMessage(@Path('id') String id, @Path('messageId') String messageId);

  @POST(ApiPaths.conversationAccept)
  Future<ApiResponse<ConversationSummaryModel>> accept(@Path('id') String id);

  @POST(ApiPaths.conversationIgnore)
  Future<ApiResponse<ConversationSummaryModel>> ignore(@Path('id') String id);

  /// 204, no body.
  @POST(ApiPaths.conversationRead)
  Future<void> markRead(@Path('id') String id, @Body() MarkReadRequestModel body);

  @POST(ApiPaths.conversationMute)
  Future<ApiResponse<ConversationSummaryModel>> mute(@Path('id') String id, @Body() MuteRequestModel body);
}

/// Registers [ChatApi] with get_it.
@module
abstract class ChatModule {
  @lazySingleton
  ChatApi chatApi(@Named(DioNames.api) Dio dio) => ChatApi(dio);
}
