import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/errors/failures.dart';
import '../../../core/realtime/realtime_client.dart';
import '../domain/chat_repository.dart';
import '../domain/entities/chat.dart';
import 'chat_api.dart';
import 'models/chat_models.dart';

/// [ChatRepository] over [ChatApi], with live events from the shared [RealtimeClient]. Nothing is cached.
@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._api, this._realtime);

  final ChatApi _api;
  final RealtimeClient _realtime;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations({bool requests = false}) async {
    final result = await safeApiCall(() => _api.conversations(requests ? 'requests' : 'inbox'));
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  @override
  Future<Either<Failure, ChatUnreadCounts>> getUnreadCounts() async {
    final result = await safeApiCall(_api.unread);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, Conversation>> openDirect(String playerId) =>
      _summary(() => _api.openDirect(OpenDirectRequestModel(playerId: playerId)));

  @override
  Future<Either<Failure, Conversation>> getConversation(String id) => _summary(() => _api.conversation(id));

  @override
  Future<Either<Failure, Conversation>> getMatchConversation(String matchId) =>
      _summary(() => _api.matchConversation(matchId));

  @override
  Future<Either<Failure, MessagePage>> getHistory(String conversationId, {String? before}) async {
    final result = await safeApiCall(() => _api.history(conversationId, before: before));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, ChatMessage>> send(
    String conversationId, {
    required String clientMessageId,
    required String body,
  }) async {
    final result = await safeApiCall(
      () => _api.send(conversationId, SendMessageRequestModel(clientMessageId: clientMessageId, body: body.trim())),
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, Unit>> deleteMessage(String conversationId, String messageId) =>
      safeNoContentCall(() => _api.deleteMessage(conversationId, messageId));

  @override
  Future<Either<Failure, Conversation>> answerRequest(String conversationId, {required bool accept}) =>
      _summary(() => accept ? _api.accept(conversationId) : _api.ignore(conversationId));

  @override
  Future<Either<Failure, Unit>> markRead(String conversationId, String upToMessageId) =>
      safeNoContentCall(() => _api.markRead(conversationId, MarkReadRequestModel(upToMessageId: upToMessageId)));

  @override
  Future<Either<Failure, Conversation>> setMuted(String conversationId, {required bool muted}) =>
      _summary(() => _api.mute(conversationId, MuteRequestModel(muted: muted)));

  @override
  Stream<ChatEvent> get events => _realtime.events.map(chatEventOf).where((e) => e != null).cast<ChatEvent>();

  Future<Either<Failure, Conversation>> _summary(
    Future<ApiResponse<ConversationSummaryModel>> Function() request,
  ) async {
    final result = await safeApiCall(request);
    return result.map((model) => model.toEntity());
  }
}
