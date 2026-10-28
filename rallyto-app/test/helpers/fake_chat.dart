import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/auth/current_user.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/chat/domain/chat_repository.dart';
import 'package:rallyto_app/features/chat/domain/chat_rules.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';

/// This player in the chat tests.
const String me = 'u-me';

/// The other player of the test conversation.
const String other = 'u-2';

/// A [ChatRepository] answering from what the test set, recording what it was asked. [emit] delivers a realtime
/// chat event.
class FakeChatRepository implements ChatRepository {
  Conversation conversation = testConversation();
  List<Conversation> inbox = [testConversation(), testConversation(id: 'c-group', kind: ConversationKind.match)];
  List<Conversation> requests = [
    testConversation(id: 'c-req', isRequest: true, title: 'رضا', otherUserId: 'u-3', isRequestRecipient: true),
  ];
  ChatUnreadCounts unread = const ChatUnreadCounts(conversations: 1, requests: 1);

  /// History pages by cursor: null is the newest page.
  Map<String?, MessagePage> pages = {
    null: MessagePage(
      items: [
        testMessage(id: 'm-2', sender: other, body: 'سلام، شنبه بازی؟', minute: 2),
        testMessage(id: 'm-1', sender: me, body: 'سلام', minute: 1),
      ],
    ),
  };

  /// The group conversations by game id; a game not here has none (CONVERSATION_NOT_FOUND).
  Map<String, Conversation> matchGroups = {'m-1': testConversation(id: 'c-group', kind: ConversationKind.match)};

  /// When set, [send] answers with it (once per entry; the last repeats).
  List<Failure?> sendFailures = [];

  /// When set, every read (conversation, history, lists, counts) answers with it.
  Failure? loadFailure;

  /// When set, actions (accept, ignore, mute, delete, open) answer with it.
  Failure? actionFailure;

  /// When set, [send] waits on it.
  Completer<void>? sendGate;

  final List<String> calls = [];
  final List<(String conversationId, String clientMessageId, String body)> sent = [];
  final List<(String conversationId, String upTo)> marked = [];

  final StreamController<ChatEvent> _events = StreamController<ChatEvent>.broadcast(sync: true);

  void emit(ChatEvent event) => _events.add(event);

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations({bool requests = false}) async {
    calls.add(requests ? 'list:requests' : 'list:inbox');
    final failure = loadFailure;
    if (failure != null) return Left(failure);
    return Right(requests ? this.requests : inbox);
  }

  @override
  Future<Either<Failure, ChatUnreadCounts>> getUnreadCounts() async {
    calls.add('unread');
    final failure = loadFailure;
    return failure == null ? Right(unread) : Left(failure);
  }

  @override
  Future<Either<Failure, Conversation>> openDirect(String playerId) async {
    calls.add('open:$playerId');
    final failure = actionFailure ?? loadFailure;
    return failure == null ? Right(conversation) : Left(failure);
  }

  @override
  Future<Either<Failure, Conversation>> getConversation(String id) async {
    calls.add('get:$id');
    final failure = loadFailure;
    return failure == null ? Right(conversation) : Left(failure);
  }

  @override
  Future<Either<Failure, Conversation>> getMatchConversation(String matchId) async {
    calls.add('match:$matchId');
    final failure = loadFailure;
    if (failure != null) return Left(failure);
    final group = matchGroups[matchId];
    return group == null
        ? const Left(NotFoundFailure('گفتگو پیدا نشد.', code: ChatErrorCodes.conversationNotFound))
        : Right(group);
  }

  @override
  Future<Either<Failure, MessagePage>> getHistory(String conversationId, {String? before}) async {
    calls.add('history:$conversationId:${before ?? ''}');
    final failure = loadFailure;
    return failure == null ? Right(pages[before] ?? const MessagePage()) : Left(failure);
  }

  @override
  Future<Either<Failure, ChatMessage>> send(
    String conversationId, {
    required String clientMessageId,
    required String body,
  }) async {
    sent.add((conversationId, clientMessageId, body));
    await sendGate?.future;
    final failure = sendFailures.isEmpty
        ? null
        : sendFailures.length > 1
        ? sendFailures.removeAt(0)
        : sendFailures.single;
    if (failure != null) return Left(failure);
    return Right(
      testMessage(
        id: 'srv-$clientMessageId',
        sender: me,
        body: body,
        minute: 30,
        clientMessageId: clientMessageId,
        conversationId: conversationId,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> deleteMessage(String conversationId, String messageId) async {
    calls.add('delete:$messageId');
    final failure = actionFailure;
    return failure == null ? const Right(unit) : Left(failure);
  }

  @override
  Future<Either<Failure, Conversation>> answerRequest(String conversationId, {required bool accept}) async {
    calls.add('${accept ? 'accept' : 'ignore'}:$conversationId');
    final failure = actionFailure;
    if (failure != null) return Left(failure);
    return Right(accept ? testConversation(id: conversationId) : conversation);
  }

  @override
  Future<Either<Failure, Unit>> markRead(String conversationId, String upToMessageId) async {
    marked.add((conversationId, upToMessageId));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Conversation>> setMuted(String conversationId, {required bool muted}) async {
    calls.add('mute:$muted');
    final failure = actionFailure;
    if (failure != null) return Left(failure);
    return Right(testConversation(id: conversationId, muted: muted, title: conversation.title));
  }
}

/// A [CurrentUser] that is always [id].
class FakeCurrentUser implements CurrentUser {
  FakeCurrentUser([this.userId = me]);

  final String? userId;

  @override
  Future<String?> id() async => userId;
}

/// A direct conversation with «علی».
Conversation testConversation({
  String id = 'c-1',
  ConversationKind kind = ConversationKind.direct,
  String title = 'علی',
  String? otherUserId = other,
  String? matchId,
  bool isRequest = false,
  bool canSend = true,
  bool muted = false,
  int unreadCount = 1,
  bool isRequestRecipient = false,
}) => Conversation(
  id: id,
  kind: kind,
  title: kind == ConversationKind.match && title == 'علی' ? 'تنیس ‏•‏ دونفره' : title,
  otherUserId: kind == ConversationKind.match ? null : otherUserId,
  matchId: kind == ConversationKind.match ? (matchId ?? 'm-1') : null,
  lastMessage: 'سلام، شنبه بازی؟',
  lastMessageAt: DateTime.utc(2026, 10, 23, 7, 2),
  unreadCount: unreadCount,
  isRequest: isRequest,
  canSend: canSend,
  muted: muted,
  isRequestRecipient: isRequestRecipient,
);

/// A message sent at 07:[minute] UTC on 2026-10-23 (10:[minute + 30] in Tehran).
ChatMessage testMessage({
  required String id,
  required String sender,
  String body = 'سلام',
  int minute = 0,
  bool deleted = false,
  bool readByOthers = false,
  String? clientMessageId,
  String conversationId = 'c-1',
  String? senderName,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  senderId: sender,
  senderName: senderName ?? (sender == me ? 'من' : 'علی'),
  body: deleted ? null : body,
  deleted: deleted,
  sentAt: DateTime.utc(2026, 10, 23, 7, minute),
  readByOthers: readByOthers,
  clientMessageId: clientMessageId ?? 'cid-$id',
);
