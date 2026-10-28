import 'package:equatable/equatable.dart';

/// A direct conversation between two players, or the group conversation of a match.
enum ConversationKind {
  direct('Direct'),
  match('Match');

  const ConversationKind(this.wire);

  final String wire;

  static ConversationKind? tryParse(String? value) {
    for (final kind in values) {
      if (kind.wire.toLowerCase() == value?.toLowerCase()) return kind;
    }
    return null;
  }
}

/// One conversation as its member sees it (`ConversationSummary`).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.kind,
    required this.title,
    this.matchId,
    this.otherUserId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isRequest = false,
    this.canSend = true,
    this.muted = false,
    this.isRequestRecipient = false,
  });

  final String id;
  final ConversationKind kind;

  /// The game, for a match conversation.
  final String? matchId;

  /// The other player's name in a direct conversation («کاربر حذف‌شده» for a deleted account), the game's title in a
  /// match conversation.
  final String title;

  /// The other player, in a direct conversation.
  final String? otherUserId;

  /// The latest message's text («پیام حذف شد» for a deleted one), or null when there is none.
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// Still a message request (for both members): the recipient has not accepted, ignored or replied.
  final bool isRequest;

  /// Whether this member can send now. False after a block, with a deleted account, after leaving a match, and for a
  /// request's sender once their one message is out.
  final bool canSend;
  final bool muted;

  /// This member received the message request and it is still pending: they can accept, ignore or block.
  final bool isRequestRecipient;

  bool get isMatch => kind == ConversationKind.match;

  Conversation copyWith({bool? canSend, int? unreadCount}) => Conversation(
    id: id,
    kind: kind,
    title: title,
    matchId: matchId,
    otherUserId: otherUserId,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    isRequest: isRequest,
    canSend: canSend ?? this.canSend,
    muted: muted,
    isRequestRecipient: isRequestRecipient,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    matchId,
    title,
    otherUserId,
    lastMessage,
    lastMessageAt,
    unreadCount,
    isRequest,
    canSend,
    muted,
    isRequestRecipient,
  ];
}

/// Where an outgoing message is: on the server, on its way, or failed (to retry with the same client id).
enum MessageDelivery { sent, pending, failed }

/// One message (`MessageView`), or one of this player's messages not yet confirmed by the server.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    required this.clientMessageId,
    this.body,
    this.deleted = false,
    this.readByOthers = false,
    this.delivery = MessageDelivery.sent,
    this.errorMessage,
  });

  /// The server's id; empty until the server confirmed the message.
  final String id;
  final String conversationId;
  final String senderId;

  /// «کاربر حذف‌شده» for a deleted account.
  final String senderName;

  /// Null once deleted.
  final String? body;
  final bool deleted;
  final DateTime sentAt;

  /// Every other current member has read it (in a direct conversation: the other player).
  final bool readByOthers;

  /// The id this device gave the message, which makes a retry idempotent.
  final String clientMessageId;
  final MessageDelivery delivery;

  /// Why sending failed, for a [MessageDelivery.failed] message.
  final String? errorMessage;

  bool get isSent => delivery == MessageDelivery.sent;

  /// A key that stays the same from pending to sent.
  String get key => clientMessageId.isNotEmpty ? 'c:$senderId:$clientMessageId' : 'm:$id';

  ChatMessage copyWith({
    bool? deleted,
    bool? readByOthers,
    MessageDelivery? delivery,
    String? Function()? errorMessage,
    bool clearBody = false,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    sentAt: sentAt,
    clientMessageId: clientMessageId,
    body: clearBody ? null : body,
    deleted: deleted ?? this.deleted,
    readByOthers: readByOthers ?? this.readByOthers,
    delivery: delivery ?? this.delivery,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    body,
    deleted,
    sentAt,
    readByOthers,
    clientMessageId,
    delivery,
    errorMessage,
  ];
}

/// One page of history, newest first; [nextCursor] fetches the older page, null on the oldest.
class MessagePage extends Equatable {
  const MessagePage({this.items = const [], this.nextCursor});

  final List<ChatMessage> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}

/// How many conversations, and how many message requests, have unread messages.
class ChatUnreadCounts extends Equatable {
  const ChatUnreadCounts({this.conversations = 0, this.requests = 0});

  final int conversations;
  final int requests;

  int get total => conversations + requests;

  @override
  List<Object?> get props => [conversations, requests];
}

/// A chat event from the realtime hub.
sealed class ChatEvent extends Equatable {
  const ChatEvent(this.conversationId);

  final String conversationId;
}

/// `message.received`: a new message, also this player's own from another device or from this one.
final class MessageReceived extends ChatEvent {
  MessageReceived(this.message) : super(message.conversationId);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

/// `message.deleted`.
final class MessageDeleted extends ChatEvent {
  const MessageDeleted(super.conversationId, this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [conversationId, messageId];
}

/// `conversation.read`: [userId] read up to [upToMessageId].
final class ConversationRead extends ChatEvent {
  const ConversationRead(super.conversationId, {required this.userId, required this.upToMessageId});

  final String userId;
  final String upToMessageId;

  @override
  List<Object?> get props => [conversationId, userId, upToMessageId];
}
