import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_badge_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_inbox_cubit.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_realtime.dart';

/// The inbox (conversations and requests with their unread badges) and the home badge: loaded, kept live by the hub's
/// events, and polled while it is down.
void main() {
  late FakeChatRepository chat;
  late FakeRealtimeClient realtime;
  late FakeProfileRepository profiles;

  setUp(() {
    chat = FakeChatRepository();
    realtime = FakeRealtimeClient();
    profiles = FakeProfileRepository();
  });

  group('inbox', () {
    test('loads both tabs and the unread counts together', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.conversations.status, ViewStatus.content);
      expect(cubit.state.conversations.items.map((c) => c.id), ['c-1', 'c-group']);
      expect(cubit.state.requests.items.single.isRequest, isTrue);
      expect(cubit.state.unread, const ChatUnreadCounts(conversations: 1, requests: 1));
      expect(chat.calls.toSet(), {'list:inbox', 'list:requests', 'unread'});
    });

    test('empty tabs are empty, not errors', () async {
      chat
        ..inbox = []
        ..requests = []
        ..unread = const ChatUnreadCounts();
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.conversations.status, ViewStatus.empty);
      expect(cubit.state.requests.status, ViewStatus.empty);
    });

    test('a failed first load is an error to retry; a failed reload keeps what is shown', () async {
      chat.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.conversations.status, ViewStatus.error);
      expect(cubit.state.conversations.errorMessage, AppStrings.offlineActionError);

      chat.loadFailure = null;
      await cubit.load();
      chat.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      await cubit.refresh();
      expect(cubit.state.conversations.status, ViewStatus.content);
      expect(cubit.state.unread.total, 2);
    });

    test('a new message over the hub reloads the lists and badges', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();
      chat
        ..unread = const ChatUnreadCounts(conversations: 2, requests: 1)
        ..calls.clear();

      chat.emit(MessageReceived(testMessage(id: 'm-9', sender: other, minute: 9)));
      await pumpEventQueue();

      expect(chat.calls.toSet(), {'list:inbox', 'list:requests', 'unread'});
      expect(cubit.state.unread.conversations, 2);
    });

    test('with the hub down it polls every 15 s', () {
      fakeAsync((async) {
        realtime.setStatus(RealtimeStatus.disconnected);
        final cubit = ChatInboxCubit(chat, realtime, profiles);
        unawaited(cubit.load());
        async.flushMicrotasks();
        chat.calls.clear();

        async.elapse(const Duration(seconds: 15));
        expect(chat.calls.where((c) => c == 'unread'), hasLength(1));
        async.elapse(const Duration(seconds: 15));
        expect(chat.calls.where((c) => c == 'unread'), hasLength(2));

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });

  group('home badge', () {
    test('starts with the counts, and re-reads them on every new message', () async {
      final cubit = ChatBadgeCubit(chat, realtime);
      addTearDown(cubit.close);

      await cubit.start();
      expect(cubit.state.total, 2);

      chat.unread = const ChatUnreadCounts(conversations: 3, requests: 1);
      chat.emit(MessageReceived(testMessage(id: 'm-9', sender: other, minute: 9)));
      await pumpEventQueue();

      expect(cubit.state, const ChatUnreadCounts(conversations: 3, requests: 1));
    });

    test('a failed read keeps the last counts', () async {
      final cubit = ChatBadgeCubit(chat, realtime);
      addTearDown(cubit.close);
      await cubit.start();

      chat.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      await cubit.refresh();

      expect(cubit.state.total, 2);
    });

    test('with the hub down it polls every 60 s, and stops when it is back', () {
      fakeAsync((async) {
        realtime.setStatus(RealtimeStatus.disconnected);
        final cubit = ChatBadgeCubit(chat, realtime);
        unawaited(cubit.start());
        async.flushMicrotasks();
        chat.calls.clear();

        async.elapse(const Duration(seconds: 59));
        expect(chat.calls, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(chat.calls, ['unread']);

        realtime.setStatus(RealtimeStatus.connected);
        async.flushMicrotasks();
        chat.calls.clear();
        async.elapse(const Duration(minutes: 5));
        expect(chat.calls, isEmpty);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });

  group('answering a request from the inbox', () {
    test('accepting answers the server, says so and reloads both lists', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();
      chat.calls.clear();

      final answered = await cubit.answerRequest(cubit.state.requests.items.single, accept: true);

      expect(answered, isTrue);
      expect(chat.calls.first, 'accept:c-req');
      expect(chat.calls, containsAll(['list:inbox', 'list:requests', 'unread']));
      expect(cubit.state.feedback?.message, AppStrings.requestAcceptedDone);
      expect(cubit.state.feedback?.isError, isFalse);
      expect(cubit.state.answeringId, isNull);
    });

    test('ignoring says so', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();

      final answered = await cubit.answerRequest(cubit.state.requests.items.single, accept: false);

      expect(answered, isTrue);
      expect(chat.calls, contains('ignore:c-req'));
      expect(cubit.state.feedback?.message, AppStrings.requestIgnoredDone);
    });

    test("a refusal is said in the app's words and answers false", () async {
      chat.actionFailure = const ServerFailure('x', code: 'CONVERSATION_NOT_FOUND', statusCode: 404);
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();

      final answered = await cubit.answerRequest(cubit.state.requests.items.single, accept: true);

      expect(answered, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.chatConversationNotFound);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.answeringId, isNull);
    });

    test('a second answer while one is on its way is not sent', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();
      final request = cubit.state.requests.items.single;

      final first = cubit.answerRequest(request, accept: true);
      final second = await cubit.answerRequest(request, accept: false);
      await first;

      expect(second, isFalse);
      expect(chat.calls.where((c) => c.startsWith('accept') || c.startsWith('ignore')), ['accept:c-req']);
    });
  });
  group("blocking a request's sender from the inbox", () {
    test('blocks the sender through the profile path, takes the request off at once, says so and reloads', () async {
      profiles.onBlock = (_) => chat.requests = [];
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();
      chat.calls.clear();
      final request = cubit.state.requests.items.single;
      final states = <ChatInboxState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      final blocked = await cubit.blockSender(request);

      expect(blocked, isTrue);
      expect(profiles.blocked, ['u-3']);
      expect(
        states.any((s) => s.answeringId == null && s.requests.items.isEmpty && s.feedback != null),
        isTrue,
        reason: 'gone before the reload answers',
      );
      expect(chat.calls, containsAll(['list:inbox', 'list:requests', 'unread']));
      expect(cubit.state.requests.status, ViewStatus.empty);
      expect(cubit.state.feedback?.message, AppStrings.blocked('رضا'));
      expect(cubit.state.feedback?.isError, isFalse);
      expect(cubit.state.answeringId, isNull);
    });

    test('a refusal is said, the request stays, and it answers false', () async {
      profiles.blockFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();

      final blocked = await cubit.blockSender(cubit.state.requests.items.single);

      expect(blocked, isFalse);
      expect(cubit.state.requests.items.single.id, 'c-req');
      expect(cubit.state.feedback?.message, AppStrings.offlineActionError);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.answeringId, isNull);
    });

    test('not while another answer is on its way, and not without a sender', () async {
      final cubit = ChatInboxCubit(chat, realtime, profiles);
      addTearDown(cubit.close);
      await cubit.load();
      final request = cubit.state.requests.items.single;

      final accepting = cubit.answerRequest(request, accept: true);
      final whileBusy = await cubit.blockSender(request);
      await accepting;
      final noSender = await cubit.blockSender(testConversation(id: 'c-x', isRequest: true, otherUserId: null));

      expect(whileBusy, isFalse);
      expect(noSender, isFalse);
      expect(profiles.blocked, isEmpty);
    });
  });
}
