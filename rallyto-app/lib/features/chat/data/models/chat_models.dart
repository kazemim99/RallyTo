import 'package:json_annotation/json_annotation.dart';

import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/utils/server_time.dart';
import '../../domain/entities/chat.dart';

part 'chat_models.g.dart';

/// `ConversationSummary`. Enums arrive as strings.
@JsonSerializable(createToJson: false)
class ConversationSummaryModel {
  const ConversationSummaryModel({
    required this.id,
    required this.kind,
    this.matchId,
    this.title = '',
    this.otherUserId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isRequest = false,
    this.canSend = false,
    this.muted = false,
    this.isRequestRecipient = false,
  });

  factory ConversationSummaryModel.fromJson(Map<String, dynamic> json) => _$ConversationSummaryModelFromJson(json);

  final String id;
  final String kind;
  final String? matchId;
  final String title;
  final String? otherUserId;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;
  final bool isRequest;
  final bool canSend;
  final bool muted;
  final bool isRequestRecipient;

  Conversation toEntity() => Conversation(
    id: id,
    kind: ConversationKind.tryParse(kind) ?? (matchId == null ? ConversationKind.direct : ConversationKind.match),
    matchId: matchId,
    title: title,
    otherUserId: otherUserId,
    lastMessage: lastMessage,
    lastMessageAt: parseServerInstant(lastMessageAt),
    unreadCount: unreadCount,
    isRequest: isRequest,
    canSend: canSend,
    muted: muted,
    isRequestRecipient: isRequestRecipient,
  );
}

/// `MessageView`: from the history, a send, and the realtime `message.received` event.
@JsonSerializable(createToJson: false)
class MessageViewModel {
  const MessageViewModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sentAt,
    this.senderName = '',
    this.body,
    this.deleted = false,
    this.readByOthers = false,
    this.clientMessageId = '',
  });

  factory MessageViewModel.fromJson(Map<String, dynamic> json) => _$MessageViewModelFromJson(json);

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? body;
  final bool deleted;
  final String sentAt;
  final bool readByOthers;
  final String clientMessageId;

  ChatMessage toEntity() => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    body: deleted ? null : body,
    deleted: deleted,
    sentAt: parseServerInstant(sentAt) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    readByOthers: readByOthers,
    clientMessageId: clientMessageId,
  );
}

/// `MessagePage`.
@JsonSerializable(createToJson: false)
class MessagePageModel {
  const MessagePageModel({this.items = const [], this.nextCursor});

  factory MessagePageModel.fromJson(Map<String, dynamic> json) => _$MessagePageModelFromJson(json);

  final List<MessageViewModel> items;
  final String? nextCursor;

  MessagePage toEntity() => MessagePage(
    items: [for (final m in items) m.toEntity()],
    nextCursor: nextCursor == null || nextCursor!.isEmpty ? null : nextCursor,
  );
}

/// `UnreadCountsView`.
@JsonSerializable(createToJson: false)
class UnreadCountsModel {
  const UnreadCountsModel({this.conversations = 0, this.requests = 0});

  factory UnreadCountsModel.fromJson(Map<String, dynamic> json) => _$UnreadCountsModelFromJson(json);

  final int conversations;
  final int requests;

  ChatUnreadCounts toEntity() => ChatUnreadCounts(conversations: conversations, requests: requests);
}

/// `OpenDirectRequest`.
@JsonSerializable(createFactory: false)
class OpenDirectRequestModel {
  const OpenDirectRequestModel({required this.playerId});

  final String playerId;

  Map<String, dynamic> toJson() => _$OpenDirectRequestModelToJson(this);
}

/// `SendMessageRequest`.
@JsonSerializable(createFactory: false)
class SendMessageRequestModel {
  const SendMessageRequestModel({required this.clientMessageId, required this.body});

  final String clientMessageId;
  final String body;

  Map<String, dynamic> toJson() => _$SendMessageRequestModelToJson(this);
}

/// `MarkReadRequest`.
@JsonSerializable(createFactory: false)
class MarkReadRequestModel {
  const MarkReadRequestModel({required this.upToMessageId});

  final String upToMessageId;

  Map<String, dynamic> toJson() => _$MarkReadRequestModelToJson(this);
}

/// `MuteRequest`.
@JsonSerializable(createFactory: false)
class MuteRequestModel {
  const MuteRequestModel({required this.muted});

  final bool muted;

  Map<String, dynamic> toJson() => _$MuteRequestModelToJson(this);
}

/// The chat event in a realtime event, or null for any other event or a payload that cannot be read.
ChatEvent? chatEventOf(RealtimeEvent event) {
  final payload = event.payload;
  try {
    switch (event.name) {
      case RealtimeEvents.messageReceived:
        return MessageReceived(MessageViewModel.fromJson(payload).toEntity());
      case RealtimeEvents.messageDeleted:
        final conversationId = payload['conversationId'];
        final messageId = payload['messageId'];
        if (conversationId is! String || messageId is! String) return null;
        return MessageDeleted(conversationId, messageId);
      case RealtimeEvents.conversationRead:
        final conversationId = payload['conversationId'];
        final userId = payload['userId'];
        final upTo = payload['upToMessageId'];
        if (conversationId is! String || userId is! String || upTo is! String) return null;
        return ConversationRead(conversationId, userId: userId, upToMessageId: upTo);
    }
  } catch (_) {
    // A payload this app cannot read: ignored, and the next poll or reload catches up.
  }
  return null;
}
