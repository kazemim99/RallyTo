import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/conversation_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/pages/conversation_page.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_realtime.dart';
import '../../../../helpers/router_shell.dart';

/// The conversation screen: messages with their state (pending, failed with retry, read, deleted), the safety notice,
/// the request recipient's bar, the composer, the read-only footer, and reporting another player's message.
void main() {
  late FakeChatRepository chat;
  late FakeProfileRepository profiles;
  var ids = 0;

  /// What the stand-in report screen was opened with, and what it closes with.
  Object? reported;
  var reportCloses = false;

  setUp(() {
    chat = FakeChatRepository();
    profiles = FakeProfileRepository();
    ids = 0;
    reported = null;
    reportCloses = false;
  });

  Future<ConversationCubit> show(
    WidgetTester tester, {
    ConversationTarget target = const ConversationTarget.id('c-1'),
  }) async {
    final cubit = ConversationCubit(
      chat,
      profiles,
      FakeRealtimeClient(),
      FakeCurrentUser(),
      target,
      clock: () => DateTime.utc(2026, 10, 23, 8),
      newClientMessageId: () => 'local-${++ids}',
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => context.push('/c'), child: const Text('open')),
          ),
        ),
      ),
      GoRoute(
        path: '/c',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const ConversationPage()),
      ),
      landingRoute(Routes.player),
      landingRoute(Routes.home),
      GoRoute(
        path: Routes.report,
        builder: (context, state) {
          reported = state.extra;
          return Scaffold(
            body: TextButton(onPressed: () => Navigator.of(context).pop(reportCloses), child: const Text('close')),
          );
        },
      ),
    ]);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('the messages, newest at the bottom, with the time on Tehran\'s clock', (tester) async {
    await show(tester);

    expect(find.text('علی'), findsOneWidget, reason: 'the title');
    expect(find.text('سلام، شنبه بازی؟'), findsOneWidget);
    expect(find.text('سلام'), findsOneWidget);
    expect(find.text('۱۰:۳۲'), findsOneWidget, reason: '07:02 UTC');
    final newest = tester.getTopLeft(find.text('سلام، شنبه بازی؟')).dy;
    final older = tester.getTopLeft(find.text('سلام')).dy;
    expect(newest, greaterThan(older));
  });

  testWidgets('a deleted message reads «پیام حذف شد»; a message the other player read says so', (tester) async {
    chat.pages = {
      null: MessagePage(
        items: [
          testMessage(id: 'm-2', sender: other, deleted: true, minute: 2),
          testMessage(id: 'm-1', sender: me, readByOthers: true, minute: 1),
        ],
      ),
    };
    final cubit = await show(tester);

    expect(find.text(AppStrings.deletedMessage), findsOneWidget);
    expect(find.byKey(ConversationPage.readKey(cubit.state.messages.last.key)), findsOneWidget);
    expect(find.text(AppStrings.messageRead), findsOneWidget);
  });

  testWidgets('typing and sending shows the message, then it is sent', (tester) async {
    final cubit = await show(tester);

    await tester.enterText(find.byKey(ConversationPage.composerKey), 'ساعت ۶ استقلال');
    await tester.tap(find.byKey(ConversationPage.sendKey));
    await tester.pumpAndSettle();

    expect(find.text('ساعت ۶ استقلال'), findsOneWidget);
    expect(chat.sent.single.$3, 'ساعت ۶ استقلال');
    expect(cubit.state.messages.first.delivery, MessageDelivery.sent);
    final field = tester.widget<TextField>(find.byKey(ConversationPage.composerKey));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('an empty message is refused on the spot', (tester) async {
    await show(tester);

    await tester.enterText(find.byKey(ConversationPage.composerKey), '   ');
    await tester.tap(find.byKey(ConversationPage.sendKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.chatMessageEmpty), findsOneWidget);
    expect(chat.sent, isEmpty);
  });

  testWidgets('a failed message offers retry, which sends again with the same client id', (tester) async {
    chat.sendFailures = [const NetworkFailure(AppStrings.offlineActionError), null];
    final cubit = await show(tester);

    await tester.enterText(find.byKey(ConversationPage.composerKey), 'سلام دوباره');
    await tester.tap(find.byKey(ConversationPage.sendKey));
    await tester.pumpAndSettle();
    final failed = cubit.state.messages.first;
    expect(failed.delivery, MessageDelivery.failed);
    expect(find.text(AppStrings.messageFailed), findsOneWidget);

    await tester.tap(find.byKey(ConversationPage.retryKey(failed.key)));
    await tester.pumpAndSettle();

    expect(chat.sent.map((s) => s.$2), ['local-1', 'local-1']);
    expect(find.text(AppStrings.messageFailed), findsNothing);
  });

  testWidgets('a pending message says it is on its way', (tester) async {
    final gate = Completer<void>();
    chat.sendGate = gate;
    await show(tester);

    await tester.enterText(find.byKey(ConversationPage.composerKey), 'در راه');
    await tester.tap(find.byKey(ConversationPage.sendKey));
    await tester.pump();

    expect(find.text(AppStrings.messagePending), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets("a long press on the other player's message reports it, with its id and sender", (tester) async {
    await show(tester);

    await tester.longPress(find.text('سلام، شنبه بازی؟'));
    await tester.pumpAndSettle();

    expect(reported, const ReportTarget.message('m-2', senderName: 'علی'));
    expect(find.text(AppStrings.deleteMessageQuestion), findsNothing);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(chat.calls.where((c) => c == 'get:c-1'), hasLength(1), reason: 'not blocked: nothing to refresh');
  });

  testWidgets('a report that blocked the sender fetches the conversation again', (tester) async {
    await show(tester);
    reportCloses = true;
    chat.conversation = testConversation(canSend: false);

    await tester.longPress(find.text('سلام، شنبه بازی؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(chat.calls.where((c) => c == 'get:c-1'), hasLength(2));
    expect(find.byKey(ConversationPage.readOnlyKey), findsOneWidget);
  });

  testWidgets('a deleted message cannot be reported', (tester) async {
    chat.pages = {
      null: MessagePage(
        items: [testMessage(id: 'm-2', sender: other, deleted: true, minute: 2)],
      ),
    };
    await show(tester);

    await tester.longPress(find.text(AppStrings.deletedMessage));
    await tester.pumpAndSettle();

    expect(reported, isNull);
  });

  testWidgets('a long press deletes our own message after asking', (tester) async {
    await show(tester);

    await tester.longPress(find.text('سلام'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteMessageQuestion), findsOneWidget);
    await tester.tap(find.byKey(ConversationPage.confirmKey));
    await tester.pumpAndSettle();

    expect(chat.calls.last, 'delete:m-1');
    expect(find.text(AppStrings.deletedMessage), findsNWidgets(2), reason: 'the bubble, and the confirmation');
  });

  testWidgets('a new conversation shows the safety notice above the messages', (tester) async {
    chat.pages = {
      null: MessagePage(
        items: [testMessage(id: 'm-1', sender: me)],
      ),
    };
    await show(tester);

    expect(find.byKey(ConversationPage.safetyNoticeKey), findsOneWidget);
    expect(find.text(AppStrings.safetyBannerTitle), findsOneWidget);
    expect(find.textContaining(AppStrings.safetyMeetAtClubs), findsOneWidget);
    expect(find.textContaining(AppStrings.safetyNoPersonalDetails), findsOneWidget);
    expect(find.textContaining(AppStrings.safetyBlockReport), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(ConversationPage.safetyNoticeKey)).dy,
      lessThan(tester.getTopLeft(find.text('سلام')).dy),
    );
  });

  testWidgets('an established conversation shows no notice', (tester) async {
    await show(tester);

    expect(find.byKey(ConversationPage.safetyNoticeKey), findsNothing);
  });

  testWidgets('when this player can no longer send, the composer gives way to the read-only footer', (tester) async {
    chat.conversation = testConversation(canSend: false);
    await show(tester);

    expect(find.byKey(ConversationPage.composerKey), findsNothing);
    expect(find.byKey(ConversationPage.readOnlyKey), findsOneWidget);
    expect(find.text(AppStrings.cannotReplyFooter), findsOneWidget);
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

    testWidgets('shows who asks, the safety notice, and accept, ignore and block', (tester) async {
      await show(tester, target: const ConversationTarget.id('c-req'));

      expect(find.byKey(ConversationPage.requestBarKey), findsOneWidget);
      expect(find.text(AppStrings.requestFrom('رضا')), findsOneWidget);
      expect(find.byKey(ConversationPage.safetyNoticeKey), findsOneWidget);
    });

    testWidgets('accepting removes the bar', (tester) async {
      await show(tester, target: const ConversationTarget.id('c-req'));

      await tester.tap(find.byKey(ConversationPage.acceptKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ConversationPage.requestBarKey), findsNothing);
      expect(find.text(AppStrings.requestAcceptedDone), findsOneWidget);
    });

    testWidgets('ignoring closes the screen', (tester) async {
      await show(tester, target: const ConversationTarget.id('c-req'));

      await tester.tap(find.byKey(ConversationPage.ignoreKey));
      await tester.pumpAndSettle();

      expect(find.byType(ConversationPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('blocking asks first, blocks the sender and closes the screen', (tester) async {
      await show(tester, target: const ConversationTarget.id('c-req'));

      await tester.tap(find.byKey(ConversationPage.blockKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ConversationPage.confirmKey));
      await tester.pumpAndSettle();

      expect(profiles.blocked, ['u-3']);
      expect(find.byType(ConversationPage), findsNothing);
    });
  });

  testWidgets('mute, in the overflow menu, mutes the conversation and the title says so', (tester) async {
    await show(tester);
    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

    await tester.tap(find.byKey(ConversationPage.moreKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mute), findsOneWidget);
    await tester.tap(find.byKey(ConversationPage.muteKey));
    await tester.pumpAndSettle();

    expect(chat.calls.last, 'mute:true');
    expect(find.text(AppStrings.conversationMuted), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget, reason: 'the muted mark by the title');
  });

  testWidgets("the overflow menu opens the other player's profile", (tester) async {
    await show(tester);

    await tester.tap(find.byKey(ConversationPage.moreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConversationPage.profileKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /players/u-2'), findsOneWidget);
  });

  testWidgets('messages from two days are split by Jalali day separators', (tester) async {
    chat.pages = {
      null: MessagePage(
        items: [
          testMessage(id: 'm-2', sender: other, body: 'امروز'),
          ChatMessage(
            id: 'm-1',
            conversationId: 'c-1',
            senderId: me,
            senderName: 'من',
            body: 'دیروز',
            sentAt: DateTime.utc(2026, 10, 22, 7),
            clientMessageId: 'cid-m-1',
          ),
        ],
      ),
    };
    final cubit = await show(tester);

    // 22 and 23 October 2026 are Thursday 30 Mehr and Friday 1 Aban.
    expect(find.text('پنجشنبه، ۳۰ مهر'), findsOneWidget);
    expect(find.text('جمعه، ۱ آبان'), findsOneWidget);
    final today = tester.getTopLeft(find.text('جمعه، ۱ آبان')).dy;
    expect(today, greaterThan(tester.getTopLeft(find.text('دیروز')).dy), reason: "above today's first message");
    expect(today, lessThan(tester.getTopLeft(find.text('امروز')).dy));
    expect(cubit.state.messages, hasLength(2));
  });

  testWidgets("the other player's bubbles sit at the start (right), ours at the end (left)", (tester) async {
    await show(tester);

    final width = tester.getSize(find.byType(ConversationPage)).width;
    expect(tester.getCenter(find.text('سلام، شنبه بازی؟')).dx, greaterThan(width / 2), reason: 'theirs');
    expect(tester.getCenter(find.text('سلام')).dx, lessThan(width / 2), reason: 'mine');
  });

  testWidgets('older messages load from the top', (tester) async {
    chat.pages = {
      null: MessagePage(
        items: [testMessage(id: 'm-60', sender: other, minute: 59)],
        nextCursor: '10',
      ),
      '10': MessagePage(
        items: [testMessage(id: 'm-9', sender: me, body: 'قدیمی', minute: 1)],
      ),
    };
    await show(tester);

    await tester.tap(find.byKey(ConversationPage.loadOlderKey));
    await tester.pumpAndSettle();

    expect(find.text('قدیمی'), findsOneWidget);
    expect(find.byKey(ConversationPage.loadOlderKey), findsNothing);
  });

  testWidgets('a game without a group conversation says so', (tester) async {
    await show(tester, target: const ConversationTarget.match('m-9'));

    expect(find.text(AppStrings.matchChatMissing), findsOneWidget);
    expect(find.text(AppStrings.matchChatMissingHint), findsOneWidget);
  });

  testWidgets('a group conversation names each sender', (tester) async {
    chat.conversation = testConversation(kind: ConversationKind.match);
    chat.pages = {
      null: MessagePage(
        items: [testMessage(id: 'g-1', sender: 'u-5', senderName: 'مینا', body: 'من هستم')],
      ),
    };
    await show(tester);

    expect(find.text('مینا'), findsOneWidget);
    expect(find.text('من هستم'), findsOneWidget);
  });
}
