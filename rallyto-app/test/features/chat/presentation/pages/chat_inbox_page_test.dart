import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_inbox_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/pages/chat_inbox_page.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_realtime.dart';
import '../../../../helpers/router_shell.dart';

/// The inbox: two tabs with unread badges; each conversation with its last message, time and unread count; tapping
/// one opens it.
void main() {
  late FakeChatRepository chat;
  late FakeProfileRepository profiles;

  setUp(() {
    chat = FakeChatRepository();
    profiles = FakeProfileRepository();
  });

  Future<ChatInboxCubit> show(WidgetTester tester) async {
    final cubit = ChatInboxCubit(chat, FakeRealtimeClient(), profiles);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: ChatInboxPage(clock: () => DateTime.utc(2026, 10, 23, 8)),
        ),
      ),
      landingRoute(Routes.conversation),
    ]);
    return cubit;
  }

  testWidgets('conversations with their last message, time today and unread badge', (tester) async {
    await show(tester);

    expect(find.byKey(ChatInboxPage.conversationKey('c-1')), findsOneWidget);
    expect(find.byKey(ChatInboxPage.conversationKey('c-group')), findsOneWidget);
    expect(find.text('سلام، شنبه بازی؟'), findsNWidgets(2));
    expect(find.text('۱۰:۳۲'), findsNWidgets(2), reason: '07:02 UTC is 10:32 in Tehran, today');
  });

  testWidgets('each segment carries its unread count, «۹+» beyond nine', (tester) async {
    chat.unread = const ChatUnreadCounts(conversations: 12, requests: 1);
    await show(tester);

    expect(find.text(AppStrings.segmentWithCount(AppStrings.conversationsTab, '۹+')), findsOneWidget);
    expect(find.text(AppStrings.segmentWithCount(AppStrings.requestsTab, '۱')), findsOneWidget);
  });

  testWidgets('no unread requests: no count on that segment', (tester) async {
    chat.unread = const ChatUnreadCounts(conversations: 1);
    await show(tester);

    expect(find.text(AppStrings.requestsTab), findsOneWidget);
    expect(find.text(AppStrings.segmentWithCount(AppStrings.conversationsTab, '۱')), findsOneWidget);
  });

  testWidgets('a conversation with unread messages shows the unread badge', (tester) async {
    chat.inbox = [testConversation(unreadCount: 3)];
    await show(tester);

    expect(
      find.descendant(of: find.byKey(ChatInboxPage.conversationKey('c-1')), matching: find.byType(AppBadge)),
      findsOneWidget,
    );
    expect(find.text('۳'), findsOneWidget);
  });

  testWidgets('the requests segment lists message requests as cards with their message', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ChatInboxPage.conversationKey('c-req')), findsOneWidget);
    expect(find.text('رضا'), findsOneWidget);
    expect(find.text(AppStrings.messageRequestLabel), findsOneWidget);
    expect(find.text('سلام، شنبه بازی؟'), findsOneWidget);
    expect(find.byKey(ChatInboxPage.acceptKey('c-req')), findsOneWidget);
    expect(find.byKey(ChatInboxPage.ignoreKey('c-req')), findsOneWidget);
  });

  testWidgets('accepting a request from its card answers it and opens the conversation', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ChatInboxPage.acceptKey('c-req')));
    await tester.pumpAndSettle();

    expect(chat.calls, contains('accept:c-req'));
    expect(find.text('landed /chat/c-req'), findsOneWidget);
  });

  testWidgets('ignoring a request from its card answers it, says so and reloads the lists', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();
    chat.calls.clear();

    await tester.tap(find.byKey(ChatInboxPage.ignoreKey('c-req')));
    await tester.pumpAndSettle();

    expect(chat.calls.first, 'ignore:c-req');
    expect(chat.calls, contains('list:requests'));
    expect(find.text(AppStrings.requestIgnoredDone), findsOneWidget);
    expect(find.text('landed /chat/c-req'), findsNothing);
  });

  testWidgets("blocking a request's sender asks first, then the request leaves the list", (tester) async {
    profiles.onBlock = (_) => chat.requests = [];
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.tap(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.blockQuestion('رضا')), findsOneWidget);
    expect(find.text(AppStrings.blockExplanation), findsOneWidget);
    expect(profiles.blocked, isEmpty, reason: 'nothing happens before the confirmation');

    await tester.tap(find.byKey(ChatInboxPage.confirmBlockKey));
    await tester.pumpAndSettle();

    expect(profiles.blocked, ['u-3']);
    expect(find.byKey(ChatInboxPage.conversationKey('c-req')), findsNothing);
    expect(find.text(AppStrings.blocked('رضا')), findsOneWidget);
    expect(find.text(AppStrings.requestsEmptyTitle), findsOneWidget);
    expect(find.text('landed /chat/c-req'), findsNothing);
  });

  testWidgets('cancelling the block leaves the request as it was', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.tap(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(profiles.blocked, isEmpty);
    expect(find.byKey(ChatInboxPage.conversationKey('c-req')), findsOneWidget);
  });

  testWidgets('a refused block is said, and the request stays', (tester) async {
    profiles.blockFailure = const NetworkFailure(AppStrings.offlineActionError);
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.tap(find.byKey(ChatInboxPage.blockKey('c-req')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChatInboxPage.confirmBlockKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.offlineActionError), findsOneWidget);
    expect(find.byKey(ChatInboxPage.conversationKey('c-req')), findsOneWidget);
  });

  testWidgets('a refused answer is said, and the conversation does not open', (tester) async {
    chat.actionFailure = const ServerFailure('x', code: 'CONVERSATION_NOT_FOUND', statusCode: 404);
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ChatInboxPage.acceptKey('c-req')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.chatConversationNotFound), findsOneWidget);
    expect(find.text('landed /chat/c-req'), findsNothing);
  });

  testWidgets('tapping a request card opens the conversation', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.messageRequestLabel));
    await tester.pumpAndSettle();

    expect(find.text('landed /chat/c-req'), findsOneWidget);
    expect(chat.calls.where((c) => c.startsWith('accept') || c.startsWith('ignore')), isEmpty);
  });

  testWidgets('empty tabs explain themselves', (tester) async {
    chat
      ..inbox = []
      ..requests = [];
    await show(tester);

    expect(find.text(AppStrings.conversationsEmptyTitle), findsOneWidget);
    await tester.tap(find.byKey(ChatInboxPage.requestsTabKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.requestsEmptyTitle), findsOneWidget);
  });

  testWidgets('tapping a conversation opens it', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(ChatInboxPage.conversationKey('c-1')));
    await tester.pumpAndSettle();

    expect(find.text('landed /chat/c-1'), findsOneWidget);
  });
}
