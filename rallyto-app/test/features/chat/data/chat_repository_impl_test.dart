import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/features/chat/data/chat_api.dart';
import 'package:rallyto_app/features/chat/data/chat_repository_impl.dart';
import 'package:rallyto_app/features/chat/domain/chat_rules.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';

import '../../../helpers/fake_realtime.dart';
import '../../../helpers/fake_server.dart';

/// Chat over the real client stack, against the backend's contract (ConversationsController, ConversationSummary,
/// MessageView, MessagePage, UnreadCountsView; ChatTests): enums as strings, 204s without a body, the server's error
/// codes, and the hub's events.
void main() {
  late FakeServer server;
  late FakeRealtimeClient realtime;
  late ChatRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    realtime = FakeRealtimeClient();
    repository = ChatRepositoryImpl(ChatApi(server.dio()), realtime);
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  test('the inbox and the requests are the same list with box=inbox|requests', () async {
    server.routes['GET /api/v1/conversations'] = (options) =>
        okBody(options.queryParameters['box'] == 'requests' ? [_requestJson] : [_directJson, _groupJson]);

    final inbox = valueOf(await repository.getConversations());
    final requests = valueOf(await repository.getConversations(requests: true));

    expect([for (final r in server.requests) r.queryParameters['box']], ['inbox', 'requests']);
    final direct = inbox.first;
    expect(direct.kind, ConversationKind.direct);
    expect(direct.title, 'علی');
    expect(direct.otherUserId, 'u-2');
    expect(direct.lastMessageAt, DateTime.utc(2026, 10, 23, 7, 2));
    expect(direct.unreadCount, 2);
    expect(direct.canSend, isTrue);
    final group = inbox.last;
    expect(group.kind, ConversationKind.match);
    expect(group.matchId, 'm-1');
    expect(group.otherUserId, isNull);
    expect(group.muted, isTrue);
    expect(requests.single.isRequest, isTrue);
  });

  test("a game's group conversation is asked for by match id; none is CONVERSATION_NOT_FOUND", () async {
    server.routes['GET /api/v1/conversations/match/m-1'] = (_) => okBody({
      'id': 'c-group',
      'kind': 'Match',
      'matchId': 'm-1',
      'title': 'پدل ‏•‏ دونفره',
      'otherUserId': null,
      'lastMessage': null,
      'lastMessageAt': null,
      'unreadCount': 0,
      'isRequest': false,
      'canSend': true,
      'muted': false,
      'isRequestRecipient': false,
    });
    server.routes['GET /api/v1/conversations/match/m-9'] = (_) =>
        errorBody(404, 'CONVERSATION_NOT_FOUND', 'گفتگو پیدا نشد.');

    final group = (await repository.getMatchConversation('m-1')).fold((f) => fail('$f'), (c) => c);
    expect(group.id, 'c-group');
    expect(group.isMatch, isTrue);
    expect(group.matchId, 'm-1');

    final missing = (await repository.getMatchConversation('m-9')).fold((f) => f, (_) => fail('expected none'));
    expect(missing, isA<NotFoundFailure>());
    expect(missing.code, 'CONVERSATION_NOT_FOUND');
  });

  test('isRequestRecipient is read from the summary', () async {
    server.routes['GET /api/v1/conversations/c-req'] = (_) => okBody({
      'id': 'c-req',
      'kind': 'Direct',
      'title': 'رضا',
      'otherUserId': 'u-3',
      'isRequest': true,
      'canSend': true,
      'isRequestRecipient': true,
    });

    final summary = (await repository.getConversation('c-req')).fold((f) => fail('$f'), (c) => c);

    expect(summary.isRequestRecipient, isTrue);
  });

  test('unread counts: conversations and requests', () async {
    server.routes['GET /api/v1/conversations/unread'] = (_) => okBody({'conversations': 3, 'requests': 1});

    expect(valueOf(await repository.getUnreadCounts()), const ChatUnreadCounts(conversations: 3, requests: 1));
  });

  test('opening a direct conversation posts the player id', () async {
    server.routes['POST /api/v1/conversations/direct'] = (_) => okBody(_directJson);

    final conversation = valueOf(await repository.openDirect('u-2'));

    expect(server.lastJson, {'playerId': 'u-2'});
    expect(conversation.id, 'c-1');
  });

  test('history is newest first with a before cursor; a deleted message has no body', () async {
    server.routes['GET /api/v1/conversations/c-1/messages'] = (options) => okBody({
      'items': [
        _messageJson('m-2', sender: 'u-2', deleted: true),
        _messageJson('m-1', sender: 'u-me', readByOthers: true),
      ],
      'nextCursor': options.queryParameters['before'] == null ? '41' : null,
    });

    final first = valueOf(await repository.getHistory('c-1'));
    final older = valueOf(await repository.getHistory('c-1', before: first.nextCursor));

    expect(server.requests.first.queryParameters.containsKey('before'), isFalse);
    expect(server.requests.last.queryParameters['before'], '41');
    expect(first.nextCursor, '41');
    expect(older.nextCursor, isNull);
    final deleted = first.items.first;
    expect(deleted.deleted, isTrue);
    expect(deleted.body, isNull);
    expect(first.items.last.readByOthers, isTrue);
    expect(first.items.last.clientMessageId, 'cid-m-1');
    expect(first.items.last.sentAt, DateTime.utc(2026, 10, 23, 7, 1));
  });

  test('sending posts the client id and the trimmed body', () async {
    server.routes['POST /api/v1/conversations/c-1/messages'] = (_) => okBody(_messageJson('m-3', sender: 'u-me'));

    final message = valueOf(await repository.send('c-1', clientMessageId: 'abc', body: '  سلام  '));

    expect(server.lastJson, {'clientMessageId': 'abc', 'body': 'سلام'});
    expect(message.id, 'm-3');
    expect(message.isSent, isTrue);
  });

  test("the server's chat refusals keep their codes", () async {
    for (final (status, code) in [
      (409, ChatErrorCodes.requestNotAccepted),
      (403, ChatErrorCodes.cannotReply),
      (400, ChatErrorCodes.messageTooLong),
      (400, ChatErrorCodes.messageEmpty),
      (404, ChatErrorCodes.conversationNotFound),
      (429, ChatErrorCodes.tooManyRequests),
    ]) {
      server.routes['POST /api/v1/conversations/c-1/messages'] = (_) => errorBody(status, code, 'پیام سرور');
      expect(failureOf(await repository.send('c-1', clientMessageId: 'x', body: 'سلام')).code, code);
    }
    server.routes['POST /api/v1/conversations/direct'] = (_) =>
        errorBody(404, ChatErrorCodes.playerNotFound, 'بازیکن پیدا نشد.');
    expect(failureOf(await repository.openDirect('u-9')), isA<NotFoundFailure>());
  });

  test('delete and read are 204s; accept, ignore and mute answer with the conversation', () async {
    server.routes['DELETE /api/v1/conversations/c-1/messages/m-1'] = (_) => noContentBody();
    server.routes['POST /api/v1/conversations/c-1/read'] = (_) => noContentBody();
    server.routes['POST /api/v1/conversations/c-1/accept'] = (_) => okBody(_directJson);
    server.routes['POST /api/v1/conversations/c-1/ignore'] = (_) => okBody(_requestJson);
    server.routes['POST /api/v1/conversations/c-1/mute'] = (_) => okBody({..._directJson, 'muted': true});

    expect(valueOf(await repository.deleteMessage('c-1', 'm-1')), unit);
    expect(valueOf(await repository.markRead('c-1', 'm-2')), unit);
    expect(server.lastJson, {'upToMessageId': 'm-2'});
    expect(valueOf(await repository.answerRequest('c-1', accept: true)).isRequest, isFalse);
    expect(valueOf(await repository.answerRequest('c-1', accept: false)).isRequest, isTrue);
    expect(valueOf(await repository.setMuted('c-1', muted: true)).muted, isTrue);
    expect(server.lastJson, {'muted': true});
  });

  test("the hub's chat events are read; others and unreadable ones are skipped", () async {
    final events = <ChatEvent>[];
    final subscription = repository.events.listen(events.add);
    addTearDown(subscription.cancel);

    realtime
      ..emit(RealtimeEvents.messageReceived, _messageJson('m-5', sender: 'u-2'))
      ..emit(RealtimeEvents.messageDeleted, {'conversationId': 'c-1', 'messageId': 'm-1'})
      ..emit(RealtimeEvents.conversationRead, {'conversationId': 'c-1', 'userId': 'u-2', 'upToMessageId': 'm-5'})
      ..emit(RealtimeEvents.notificationCreated, {'notification': <String, dynamic>{}, 'unreadCount': 1})
      ..emit(RealtimeEvents.messageDeleted, {'conversationId': 'c-1'});
    await pumpEventQueue();

    expect(events, hasLength(3));
    expect((events[0] as MessageReceived).message.id, 'm-5');
    expect(events[1], const MessageDeleted('c-1', 'm-1'));
    expect(events[2], const ConversationRead('c-1', userId: 'u-2', upToMessageId: 'm-5'));
  });
}

const Map<String, Object?> _directJson = {
  'id': 'c-1',
  'kind': 'Direct',
  'matchId': null,
  'title': 'علی',
  'otherUserId': 'u-2',
  'lastMessage': 'سلام',
  'lastMessageAt': '2026-10-23T07:02:00Z',
  'unreadCount': 2,
  'isRequest': false,
  'canSend': true,
  'muted': false,
};

const Map<String, Object?> _groupJson = {
  'id': 'c-2',
  'kind': 'Match',
  'matchId': 'm-1',
  'title': 'پدل ‏•‏ دونفره',
  'otherUserId': null,
  'lastMessage': null,
  'lastMessageAt': null,
  'unreadCount': 0,
  'isRequest': false,
  'canSend': true,
  'muted': true,
};

const Map<String, Object?> _requestJson = {
  'id': 'c-3',
  'kind': 'Direct',
  'matchId': null,
  'title': 'رضا',
  'otherUserId': 'u-3',
  'lastMessage': 'سلام، شنبه‌ها استقلال بازی می‌کنی؟',
  'lastMessageAt': '2026-10-23T07:05:00',
  'unreadCount': 1,
  'isRequest': true,
  'canSend': true,
  'muted': false,
};

Map<String, Object?> _messageJson(
  String id, {
  required String sender,
  bool deleted = false,
  bool readByOthers = false,
}) => {
  'id': id,
  'conversationId': 'c-1',
  'senderId': sender,
  'senderName': sender == 'u-me' ? 'من' : 'علی',
  'body': deleted ? null : 'سلام',
  'deleted': deleted,
  'sentAt': '2026-10-23T07:0${id.substring(2)}:00Z',
  'readByOthers': readByOthers,
  'clientMessageId': 'cid-$id',
};
