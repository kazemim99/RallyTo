import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/chat/domain/chat_rules.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/conversation_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/chat_labels.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_realtime.dart';

/// One conversation (spec chat, design D8): loading by id, with a player or a game; sending with a client id that a
/// retry reuses; read receipts both ways; deletion; the request recipient's accept, ignore and block; mute; the
/// safety notice; live events and the polling fallback.
void main() {
  late FakeChatRepository chat;
  late FakeProfileRepository profiles;
  late FakeRealtimeClient realtime;
  var ids = 0;

  setUp(() {
    chat = FakeChatRepository();
    profiles = FakeProfileRepository();
    realtime = FakeRealtimeClient();
    ids = 0;
  });

  ConversationCubit build([ConversationTarget target = const ConversationTarget.id('c-1')]) {
    final cubit = ConversationCubit(
      chat,
      profiles,
      realtime,
      FakeCurrentUser(),
      target,
      clock: () => DateTime.utc(2026, 10, 23, 8),
      newClientMessageId: () => 'local-${++ids}',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<ConversationCubit> open([ConversationTarget target = const ConversationTarget.id('c-1')]) async {
    final cubit = build(target);
    await cubit.load();
    return cubit;
  }

  group('loading', () {
    test('by id: the conversation and its newest page, newest first, then read up to the newest', () async {
      final cubit = await open();

      expect(cubit.state.status, ViewStatus.content);
      expect(cubit.state.title, 'علی');
      expect(cubit.state.myId, me);
      expect(cubit.state.messages.map((m) => m.id), ['m-2', 'm-1']);
      expect(chat.calls, ['get:c-1', 'history:c-1:']);
      expect(chat.marked, [('c-1', 'm-2')]);
      expect(cubit.state.isMine(cubit.state.messages.last), isTrue);
    });

    test(
      'with a player: their one direct conversation is opened (or started) first; the name shows meanwhile',
      () async {
        final cubit = build(const ConversationTarget.player('u-2', playerName: 'علی'));
        expect(cubit.state.title, 'علی');

        await cubit.load();

        expect(chat.calls.first, 'open:u-2');
        expect(cubit.state.conversation?.id, 'c-1');
      },
    );

    test("a game's group conversation is found by its match id", () async {
      chat.conversation = testConversation(id: 'c-group', kind: ConversationKind.match);
      final cubit = await open(const ConversationTarget.match('m-1'));

      expect(chat.calls.first, 'match:m-1', reason: 'asked by match id, not by scanning the inbox');
      expect(cubit.state.conversation?.id, 'c-group');
      expect(cubit.state.conversation?.isMatch, isTrue);
    });

    test('a game without a group conversation says so, without a retry', () async {
      final cubit = await open(const ConversationTarget.match('m-9'));

      expect(cubit.state.status, ViewStatus.error);
      expect(cubit.state.noMatchChat, isTrue);
      expect(cubit.state.notFound, isTrue);
      expect(cubit.state.errorMessage, AppStrings.matchChatMissing);
    });

    test('a conversation this player is not in is CONVERSATION_NOT_FOUND', () async {
      chat.loadFailure = const NotFoundFailure('گفتگو پیدا نشد.', code: ChatErrorCodes.conversationNotFound);
      final cubit = await open();

      expect(cubit.state.status, ViewStatus.error);
      expect(cubit.state.notFound, isTrue);
      expect(cubit.state.errorMessage, AppStrings.chatConversationNotFound);
    });

    test(
      'a player who cannot be seen is PLAYER_NOT_FOUND; too many new conversations today is TOO_MANY_REQUESTS',
      () async {
        chat.actionFailure = const NotFoundFailure('x', code: ChatErrorCodes.playerNotFound);
        final hidden = await open(const ConversationTarget.player('u-9'));
        expect(hidden.state.errorMessage, AppStrings.playerNotFound);
        expect(hidden.state.notFound, isTrue);

        chat.actionFailure = const ServerFailure('x', code: ChatErrorCodes.tooManyRequests, statusCode: 429);
        final limited = await open(const ConversationTarget.player('u-8'));
        expect(limited.state.errorMessage, AppStrings.chatTooManyRequests);
        expect(limited.state.notFound, isFalse, reason: 'it can be retried later');
      },
    );

    test('offline is an error to retry', () async {
      chat.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = await open();

      expect(cubit.state.status, ViewStatus.error);
      expect(cubit.state.notFound, isFalse);
      expect(cubit.state.errorMessage, AppStrings.offlineActionError);
    });

    test('older pages come with the before cursor and are added behind, without repeats', () async {
      chat.pages = {
        null: MessagePage(
          items: [testMessage(id: 'm-60', sender: other, minute: 59)],
          nextCursor: '10',
        ),
        '10': MessagePage(
          items: [
            testMessage(id: 'm-60', sender: other, minute: 59),
            testMessage(id: 'm-9', sender: me, minute: 1),
          ],
        ),
      };
      final cubit = await open();
      expect(cubit.state.nextCursor, '10');

      await cubit.loadOlder();

      expect(chat.calls.last, 'history:c-1:10');
      expect(cubit.state.messages.map((m) => m.id), ['m-60', 'm-9']);
      expect(cubit.state.nextCursor, isNull);
    });
  });

  group('sending', () {
    test('shows the message as pending at once, then as sent with the server id', () async {
      final cubit = await open();
      final gate = Completer<void>();
      chat.sendGate = gate;

      final sending = cubit.send('  شنبه ساعت ۶  ');
      await pumpEventQueue();
      final pending = cubit.state.messages.first;
      expect(pending.delivery, MessageDelivery.pending);
      expect(pending.body, 'شنبه ساعت ۶');
      expect(pending.clientMessageId, 'local-1');

      gate.complete();
      expect(await sending, isNull);

      final sent = cubit.state.messages.first;
      expect(sent.delivery, MessageDelivery.sent);
      expect(sent.id, 'srv-local-1');
      expect(cubit.state.messages.where((m) => m.clientMessageId == 'local-1'), hasLength(1));
      expect(chat.sent.single, ('c-1', 'local-1', 'شنبه ساعت ۶'));
    });

    test('a failed send stays as failed; retrying sends again with the SAME client id', () async {
      final cubit = await open();
      chat.sendFailures = [const NetworkFailure(AppStrings.offlineActionError), null];

      await cubit.send('سلام');
      final failed = cubit.state.messages.first;
      expect(failed.delivery, MessageDelivery.failed);
      expect(failed.errorMessage, AppStrings.offlineActionError);
      expect(cubit.state.feedback?.isError, isTrue);

      await cubit.retry(failed);

      expect(chat.sent.map((s) => s.$2), ['local-1', 'local-1'], reason: 'idempotent on the client id');
      expect(cubit.state.messages.first.delivery, MessageDelivery.sent);
      expect(cubit.state.messages.where((m) => m.clientMessageId == 'local-1'), hasLength(1));
    });

    test('a failed message can be discarded instead', () async {
      final cubit = await open();
      chat.sendFailures = [const NetworkFailure(AppStrings.offlineActionError)];
      await cubit.send('سلام');

      cubit.discard(cubit.state.messages.first);

      expect(cubit.state.messages.map((m) => m.id), ['m-2', 'm-1']);
    });

    test('the echo of our own message over the hub does not duplicate it', () async {
      final cubit = await open();
      await cubit.send('سلام');
      final sent = cubit.state.messages.first;

      chat.emit(MessageReceived(sent));

      expect(cubit.state.messages.where((m) => m.key == sent.key), hasLength(1));
    });

    test('empty and too-long messages are refused on the device, before the server', () async {
      final cubit = await open();

      expect(await cubit.send('   '), AppStrings.chatMessageEmpty);
      expect(await cubit.send('ا' * (ChatRules.maxLength + 1)), AppStrings.chatMessageTooLong);
      expect(await cubit.send('ا' * ChatRules.maxLength), isNull);
      expect(chat.sent, hasLength(1));
    });

    test("a request's first message is at most 500 characters", () async {
      chat.conversation = testConversation(isRequest: true);
      chat.pages = {null: const MessagePage()};
      final cubit = await open();
      expect(cubit.state.sendsRequest, isTrue);
      expect(cubit.state.maxLength, ChatRules.requestMaxLength);

      expect(await cubit.send('ا' * 501), AppStrings.chatRequestMessageTooLong);
      expect(chat.sent, isEmpty);
    });

    test("the server's MESSAGE_TOO_LONG on a request's first message names the 500 limit", () async {
      chat.conversation = testConversation(isRequest: true);
      chat.pages = {null: const MessagePage()};
      chat.sendFailures = [const ValidationFailure('x', code: ChatErrorCodes.messageTooLong)];
      final cubit = await open();

      await cubit.send('سلام');

      expect(cubit.state.messages.first.errorMessage, AppStrings.chatRequestMessageTooLong);
    });

    test('after a request\'s first message the summary is read again: the sender cannot send more', () async {
      chat.conversation = testConversation(isRequest: true);
      chat.pages = {null: const MessagePage()};
      final cubit = await open();
      chat.conversation = testConversation(isRequest: true, canSend: false);

      await cubit.send('سلام، شنبه‌ها استقلال بازی می‌کنی؟');

      expect(cubit.state.canSend, isFalse);
      expect(await cubit.send('هستی؟'), AppStrings.chatCannotReply);
    });

    test('CANNOT_REPLY and REQUEST_NOT_ACCEPTED close the composer', () async {
      for (final code in [ChatErrorCodes.cannotReply, ChatErrorCodes.requestNotAccepted]) {
        chat.sendFailures = [UnauthorizedFailure('x', code: code)];
        final cubit = await open();

        await cubit.send('سلام');

        expect(cubit.state.canSend, isFalse, reason: code);
        expect(cubit.state.messages.first.delivery, MessageDelivery.failed);
        expect(cubit.state.feedback?.code, code);
      }
    });

    test("every chat refusal is in the app's Persian words", () {
      const expected = {
        ChatErrorCodes.requestNotAccepted: AppStrings.chatRequestNotAccepted,
        ChatErrorCodes.cannotReply: AppStrings.chatCannotReply,
        ChatErrorCodes.messageTooLong: AppStrings.chatMessageTooLong,
        ChatErrorCodes.messageEmpty: AppStrings.chatMessageEmpty,
        ChatErrorCodes.playerNotFound: AppStrings.playerNotFound,
        ChatErrorCodes.conversationNotFound: AppStrings.chatConversationNotFound,
        ChatErrorCodes.tooManyRequests: AppStrings.chatTooManyRequests,
      };
      for (final entry in expected.entries) {
        expect(ChatLabels.error(ServerFailure('server words', code: entry.key)), entry.value, reason: entry.key);
      }
      expect(ChatLabels.error(const ServerFailure('server words', code: 'SOMETHING_NEW')), 'server words');
    });
  });

  group('live and read state', () {
    test("another member's new message is added and read at once", () async {
      final cubit = await open();

      chat.emit(MessageReceived(testMessage(id: 'm-3', sender: other, body: 'ساعت ۶؟', minute: 3)));
      await pumpEventQueue();

      expect(cubit.state.messages.first.id, 'm-3');
      expect(chat.marked.last, ('c-1', 'm-3'));
    });

    test("other conversations' events are ignored", () async {
      final cubit = await open();

      chat.emit(MessageReceived(testMessage(id: 'x-1', sender: other, conversationId: 'c-9', minute: 9)));

      expect(cubit.state.messages.map((m) => m.id), ['m-2', 'm-1']);
    });

    test('a deleted message shows as deleted, without its text', () async {
      final cubit = await open();

      chat.emit(const MessageDeleted('c-1', 'm-2'));

      final deleted = cubit.state.messages.first;
      expect(deleted.deleted, isTrue);
      expect(deleted.body, isNull);
    });

    test('conversation.read from the other player marks our messages up to that one as read', () async {
      chat.pages = {
        null: MessagePage(
          items: [
            testMessage(id: 'm-4', sender: me, minute: 4),
            testMessage(id: 'm-3', sender: me, minute: 3),
            testMessage(id: 'm-2', sender: other, minute: 2),
            testMessage(id: 'm-1', sender: me, minute: 1),
          ],
        ),
      };
      final cubit = await open();

      chat.emit(const ConversationRead('c-1', userId: other, upToMessageId: 'm-3'));

      final read = {for (final m in cubit.state.messages) m.id: m.readByOthers};
      expect(read, {'m-4': false, 'm-3': true, 'm-2': false, 'm-1': true});
    });

    test('our own read on another device changes nothing; readByOthers from the server shows as read', () async {
      chat.pages = {
        null: MessagePage(
          items: [testMessage(id: 'm-1', sender: me, readByOthers: true)],
        ),
      };
      final cubit = await open();

      chat.emit(const ConversationRead('c-1', userId: me, upToMessageId: 'm-1'));

      expect(cubit.state.messages.single.readByOthers, isTrue);
    });

    test('in a group, a read event re-reads the newest page (everyone must have read)', () async {
      chat.conversation = testConversation(id: 'c-1', kind: ConversationKind.match);
      final cubit = await open();
      chat.calls.clear();

      chat.emit(const ConversationRead('c-1', userId: other, upToMessageId: 'm-1'));
      await pumpEventQueue();

      expect(chat.calls, ['get:c-1', 'history:c-1:']);
      expect(cubit.state.messages, hasLength(2));
    });

    test('deleting our own message', () async {
      final cubit = await open();
      final mine = cubit.state.messages.last;

      await cubit.delete(mine);

      expect(chat.calls.last, 'delete:m-1');
      expect(cubit.state.messages.last.deleted, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.messageDeleted);
    });

    test("someone else's message cannot be deleted", () async {
      final cubit = await open();

      await cubit.delete(cubit.state.messages.first);

      expect(chat.calls.where((c) => c.startsWith('delete')), isEmpty);
    });
  });

  group('polling fallback', () {
    test('with the hub down the conversation is re-read every 15 s, and not once it is back', () {
      fakeAsync((async) {
        realtime.setStatus(RealtimeStatus.disconnected);
        final cubit = build();
        unawaited(cubit.load());
        async.flushMicrotasks();
        chat.calls.clear();
        chat.pages = {
          null: MessagePage(
            items: [
              testMessage(id: 'm-3', sender: other, minute: 3),
              ...chat.pages[null]!.items,
            ],
          ),
        };

        async.elapse(const Duration(seconds: 15));
        expect(chat.calls, ['get:c-1', 'history:c-1:']);
        expect(cubit.state.messages.first.id, 'm-3');
        expect(chat.marked.last, ('c-1', 'm-3'));

        realtime.setStatus(RealtimeStatus.connected);
        async.flushMicrotasks();
        chat.calls.clear();
        async.elapse(const Duration(minutes: 2));
        expect(chat.calls, isEmpty);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('a refresh keeps pending messages', () async {
      final cubit = await open();
      chat.sendGate = Completer<void>();
      unawaited(cubit.send('هنوز می‌رود'));
      await pumpEventQueue();

      await cubit.refresh();

      expect(cubit.state.messages.first.delivery, MessageDelivery.pending);
      chat.sendGate!.complete();
    });
  });

  test("who received a request is the server's word (isRequestRecipient), not read from the messages", () async {
    chat.conversation = testConversation(id: 'c-req', otherUserId: 'u-3', isRequest: true);
    chat.pages = {
      null: MessagePage(
        items: [testMessage(id: 'r-1', sender: 'u-3', conversationId: 'c-req')],
      ),
    };

    final cubit = await open(const ConversationTarget.id('c-req'));

    expect(cubit.state.isRequestRecipient, isFalse);
    expect(cubit.state.sendsRequest, isTrue);
  });

  group('a message request, for its recipient', () {
    setUp(() {
      chat.conversation = testConversation(
        id: 'c-req',
        title: 'رضا',
        otherUserId: 'u-3',
        isRequest: true,
        isRequestRecipient: true,
      );
      chat.pages = {
        null: MessagePage(
          items: [testMessage(id: 'r-1', sender: 'u-3', conversationId: 'c-req', body: 'سلام، شنبه‌ها؟')],
        ),
      };
    });

    test('is recognised (the server says so), shows the safety notice, and allows a full reply', () async {
      final cubit = await open(const ConversationTarget.id('c-req'));

      expect(cubit.state.isRequestRecipient, isTrue);
      expect(cubit.state.showSafetyNotice, isTrue);
      expect(cubit.state.sendsRequest, isFalse);
      expect(cubit.state.maxLength, ChatRules.maxLength);
    });

    test('accepting turns it into a normal conversation', () async {
      final cubit = await open(const ConversationTarget.id('c-req'));

      await cubit.accept();

      expect(chat.calls.last, 'accept:c-req');
      expect(cubit.state.conversation?.isRequest, isFalse);
      expect(cubit.state.isRequestRecipient, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.requestAcceptedDone);
      expect(cubit.state.left, isFalse);
    });

    test('ignoring closes the screen', () async {
      final cubit = await open(const ConversationTarget.id('c-req'));

      await cubit.ignore();

      expect(chat.calls.last, 'ignore:c-req');
      expect(cubit.state.left, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.requestIgnoredDone);
    });

    test('blocking the sender goes through POST /blocks/{userId} and closes the screen', () async {
      final cubit = await open(const ConversationTarget.id('c-req'));

      await cubit.blockOther();

      expect(profiles.blocked, ['u-3']);
      expect(cubit.state.left, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.blocked('رضا'));
    });

    test('a refused answer keeps the screen and says why', () async {
      chat.actionFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = await open(const ConversationTarget.id('c-req'));

      await cubit.accept();

      expect(cubit.state.left, isFalse);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.offlineActionError);
    });
  });

  group('the safety notice and mute', () {
    test('a new direct conversation shows the notice until both players have written', () async {
      chat.pages = {
        null: MessagePage(
          items: [testMessage(id: 'm-1', sender: me)],
        ),
      };
      final fresh = await open();
      expect(fresh.state.showSafetyNotice, isTrue);

      chat.pages = {null: const MessagePage()};
      final empty = await open();
      expect(empty.state.showSafetyNotice, isTrue);

      chat.pages = {
        null: MessagePage(
          items: [
            testMessage(id: 'm-2', sender: other, minute: 2),
            testMessage(id: 'm-1', sender: me, minute: 1),
          ],
        ),
      };
      final talking = await open();
      expect(talking.state.showSafetyNotice, isFalse);
    });

    test('a group conversation never shows it', () async {
      chat.conversation = testConversation(kind: ConversationKind.match);
      chat.pages = {null: const MessagePage()};
      final cubit = await open();

      expect(cubit.state.showSafetyNotice, isFalse);
    });

    test('mute toggles both ways', () async {
      final cubit = await open();

      await cubit.toggleMute();
      expect(cubit.state.conversation?.muted, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.conversationMuted);

      await cubit.toggleMute();
      expect(cubit.state.conversation?.muted, isFalse);
      expect(chat.calls.where((c) => c.startsWith('mute')), ['mute:true', 'mute:false']);
    });
  });
}
