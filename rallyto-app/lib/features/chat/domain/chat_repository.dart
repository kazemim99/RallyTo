import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/chat.dart';

/// Conversations and messages. Nothing is cached; live changes arrive on [events]. Refusals carry the server's code
/// ([ChatErrorCodes]).
abstract class ChatRepository {
  /// The inbox, or with [requests] the message requests this player received; newest first.
  Future<Either<Failure, List<Conversation>>> getConversations({bool requests = false});

  Future<Either<Failure, ChatUnreadCounts>> getUnreadCounts();

  /// The pair's one direct conversation, existing or new. `PLAYER_NOT_FOUND` for a player who cannot be seen (blocked,
  /// hidden), `TOO_MANY_REQUESTS` beyond 20 new conversations a day.
  Future<Either<Failure, Conversation>> openDirect(String playerId);

  /// `CONVERSATION_NOT_FOUND` for one this player is not in.
  Future<Either<Failure, Conversation>> getConversation(String id);

  /// The group conversation of game [matchId]. `CONVERSATION_NOT_FOUND` when the game has none, or this player is not
  /// in it.
  Future<Either<Failure, Conversation>> getMatchConversation(String matchId);

  /// One page of history, newest first; [before] is the previous page's cursor.
  Future<Either<Failure, MessagePage>> getHistory(String conversationId, {String? before});

  /// Sends [body] under [clientMessageId]; sending again with the same id answers with the same message.
  Future<Either<Failure, ChatMessage>> send(
    String conversationId, {
    required String clientMessageId,
    required String body,
  });

  /// Deletes this player's own message for everyone.
  Future<Either<Failure, Unit>> deleteMessage(String conversationId, String messageId);

  /// The request's recipient accepts it, or ignores it (silently, for the sender).
  Future<Either<Failure, Conversation>> answerRequest(String conversationId, {required bool accept});

  /// Moves this player's read cursor up to [upToMessageId].
  Future<Either<Failure, Unit>> markRead(String conversationId, String upToMessageId);

  Future<Either<Failure, Conversation>> setMuted(String conversationId, {required bool muted});

  /// Chat events from the realtime hub, while it is connected.
  Stream<ChatEvent> get events;
}
