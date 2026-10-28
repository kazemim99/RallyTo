import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/home/presentation/bloc/home_cubit.dart';
import 'package:rallyto_app/features/home/presentation/pages/home_page.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/presentation/match_labels.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';

import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_home.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_notifications.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/router_shell.dart';

/// Home: the greeting, the bell and the messages row with their live unread badges, the hero and quick actions, the
/// next game, what waits on the player, and the "still free?" reminder; tab roots switch tabs inside the shell.
void main() {
  late FakeChatRepository chat;
  late FakeNotificationRepository notifications;
  late FakeMatchRepository matches;
  late FakeAvailabilityRepository availability;
  late FakeProfileRepository profiles;

  setUp(() {
    chat = FakeChatRepository();
    notifications = FakeNotificationRepository();
    matches = FakeMatchRepository();
    availability = FakeAvailabilityRepository();
    profiles = FakeProfileRepository();
  });

  Widget home() => homeWithBadges(
    chat: chat,
    notifications: notifications,
    matches: matches,
    availability: availability,
    profiles: profiles,
  );

  Future<GoRouter> show(WidgetTester tester) => pumpRouter(tester, [
    GoRoute(path: '/', builder: (context, state) => home()),
    landingRoute(Routes.chat),
    landingRoute(Routes.notifications),
    landingRoute(Routes.search),
    landingRoute(Routes.matches),
    landingRoute(Routes.matchNew),
    landingRoute(Routes.match),
    landingRoute(Routes.availability),
  ]);

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  /// A confirmed game this player plays in, tomorrow.
  Match myGame({String id = 'm-3'}) => testMatch(
    id: id,
    status: MatchStatus.confirmed,
    myState: ParticipantState.accepted,
    participants: const [
      MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
      MatchParticipant(userId: 'u-me', displayName: 'علی', state: ParticipantState.accepted),
    ],
  );

  group('header and badges', () {
    testWidgets("the greeting for Tehran's time of day, with the player's name", (tester) async {
      await show(tester);

      expect(find.text(AppStrings.greetingMorning), findsOneWidget, reason: '11:30 in Tehran');
      expect(find.text(AppStrings.homeReadyNamed('سارا')), findsOneWidget);
    });

    testWidgets('without a profile the question stands alone', (tester) async {
      profiles = _UnreadableProfile();
      await show(tester);

      expect(find.text(AppStrings.homeReady), findsOneWidget);
    });

    testWidgets('both badges show the unread counts', (tester) async {
      chat.unread = const ChatUnreadCounts(conversations: 2, requests: 1);
      notifications.unreadCount = 4;
      await show(tester);

      expect(find.descendant(of: find.byKey(HomePage.notificationsKey), matching: find.text('۴')), findsOneWidget);
      await reveal(tester, find.byKey(HomePage.chatKey));
      expect(find.byKey(HomePage.chatBadgeKey), findsOneWidget);
      expect(find.text('۳'), findsOneWidget, reason: 'conversations and requests together');
      expect(
        find.text('${AppStrings.unreadConversations('۲')}، ${AppStrings.unreadChatRequests('۱')}'),
        findsOneWidget,
      );
    });

    testWidgets('nothing unread: no messages row and no chat badge', (tester) async {
      chat.unread = const ChatUnreadCounts();
      notifications.unreadCount = 0;
      await show(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(HomePage.chatKey), findsNothing);
      expect(find.byKey(HomePage.chatBadgeKey), findsNothing);
    });

    testWidgets('a notification arriving live updates the badge at once', (tester) async {
      notifications.unreadCount = 1;
      await show(tester);

      notifications.emit(NotificationCreated(testNotification(id: 'n-9'), 7));
      await tester.pumpAndSettle();

      expect(find.text('۷'), findsOneWidget);
    });

    testWidgets('a message arriving live re-reads the chat badge', (tester) async {
      chat.unread = const ChatUnreadCounts(conversations: 1);
      await show(tester);

      chat.unread = const ChatUnreadCounts(conversations: 5);
      chat.emit(MessageReceived(testMessage(id: 'm-9', sender: other, minute: 9)));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(HomePage.chatBadgeKey));

      expect(find.text('۵'), findsOneWidget);
    });

    testWidgets('messages and notifications open their screens, and the badges are re-read on return', (tester) async {
      final router = await show(tester);

      await reveal(tester, find.byKey(HomePage.chatKey));
      await tester.tap(find.byKey(HomePage.chatKey));
      await tester.pumpAndSettle();
      expect(find.text('landed /chat'), findsOneWidget);

      chat.calls.clear();
      router.pop();
      await tester.pumpAndSettle();
      expect(chat.calls, ['unread']);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomePage.notificationsKey));
      await tester.pumpAndSettle();
      expect(find.text('landed /notifications'), findsOneWidget);
    });
  });

  group('the way to a partner', () {
    testWidgets('the hero and quick actions open search, a new post and availability', (tester) async {
      final router = await show(tester);

      expect(find.text(AppStrings.homeHeroEyebrow), findsOneWidget);
      await tester.tap(find.byKey(HomePage.searchKey));
      await tester.pumpAndSettle();
      expect(find.text('landed /search'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HomePage.postKey));
      await tester.pumpAndSettle();
      expect(find.text('landed /matches/new'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HomePage.availabilityKey));
      await tester.pumpAndSettle();
      expect(find.text('landed /availability'), findsOneWidget);
    });

    testWidgets('my availability shows how many windows are active', (tester) async {
      availability.mine = [
        testWindow(id: 'w-1'),
        testWindow(id: 'w-3'),
        testWindow(id: 'w-2', status: AvailabilityStatus.paused),
      ];
      await show(tester);

      expect(find.text(AppStrings.activeWindows('۲')), findsOneWidget);
    });

    testWidgets('inside the tab shell, tab roots switch tabs instead of stacking on home', (tester) async {
      late StatefulNavigationShell shell;
      StatefulShellBranch branch(String path) => StatefulShellBranch(routes: [landingRoute(path)]);
      await pumpRouter(tester, [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => shell = navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/', builder: (context, state) => home())],
            ),
            branch(Routes.search),
            branch(Routes.matches),
            branch(Routes.chat),
          ],
        ),
      ]);

      await tester.tap(find.byKey(HomePage.searchKey));
      await tester.pumpAndSettle();
      expect(shell.currentIndex, HomePage.searchTab);
      expect(find.text('landed /search'), findsOneWidget);

      shell.goBranch(0);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(HomePage.matchesKey));
      await tester.tap(find.byKey(HomePage.matchesKey));
      await tester.pumpAndSettle();
      expect(shell.currentIndex, HomePage.matchesTab);

      shell.goBranch(0);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(HomePage.chatKey));
      await tester.tap(find.byKey(HomePage.chatKey));
      await tester.pumpAndSettle();
      expect(shell.currentIndex, HomePage.chatTab);
    });

    testWidgets('sign-out is no longer on home: it lives on the profile tab', (tester) async {
      await show(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.signOut), findsNothing);
    });
  });

  group('next game', () {
    testWidgets('the soonest game I play in, with its status, club and players; it opens the game', (tester) async {
      matches.upcoming = [testMatch(id: 'm-1'), myGame()];
      await show(tester);
      await reveal(tester, find.byKey(HomePage.nextGameKey));

      final card = find.byKey(HomePage.nextGameKey);
      expect(find.descendant(of: card, matching: find.text('تنیس ‏•‏ انفرادی')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(MatchLabels.status(MatchStatus.confirmed))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('باشگاه انقلاب')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('سارا، علی')), findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('landed /matches/m-3'), findsOneWidget);
    });

    testWidgets('no game ahead: invites to post one', (tester) async {
      matches.upcoming = [testMatch(id: 'm-1')];
      await show(tester);
      await reveal(tester, find.text(AppStrings.nextGameEmptyTitle));

      await tester.tap(find.widgetWithText(DashedButton, AppStrings.quickPost));
      await tester.pumpAndSettle();
      expect(find.text('landed /matches/new'), findsOneWidget);
    });

    testWidgets('games that cannot be read: the error, and a retry that reads them again', (tester) async {
      matches.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      await show(tester);
      await reveal(tester, find.text(AppStrings.offlineActionError));

      matches.loadFailure = null;
      matches.upcoming = [myGame()];
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(find.byKey(HomePage.nextGameKey), findsOneWidget);
    });
  });

  group('pending actions', () {
    testWidgets('an invitation, join requests to answer and an attendance question, each opening its game', (
      tester,
    ) async {
      final invitation = testMatch(id: 'm-inv', myState: ParticipantState.invited);
      final hosted = testHostedMatch();
      final ended = testEndedMatch();
      matches.upcoming = [invitation, hosted];
      matches.past = [ended];
      await show(tester);

      await reveal(tester, find.byKey(HomePage.taskKey(HomeTask(HomeTaskKind.attendance, ended))));
      expect(find.text(AppStrings.pendingTitle), findsOneWidget);
      expect(find.text(AppStrings.pendingInvitation('سارا')), findsOneWidget);
      expect(find.text(AppStrings.pendingRequests('۲')), findsOneWidget);
      expect(find.text(AppStrings.pendingAttendance), findsOneWidget);

      await tester.tap(find.byKey(HomePage.taskKey(HomeTask(HomeTaskKind.attendance, ended))));
      await tester.pumpAndSettle();
      expect(find.text('landed /matches/m-1'), findsOneWidget);
    });
  });

  group('still free?', () {
    testWidgets("the reminder names the window's days and pause day, and «هنوز آزادم» confirms only it", (
      tester,
    ) async {
      availability.mine = [
        testWindow(id: 'w-1', needsReconfirmation: true, pausesOn: '1405/08/30'),
        testWindow(id: 'w-fresh', pausesOn: '1405/09/20'),
        testWindow(id: 'w-2', status: AvailabilityStatus.paused),
      ];
      await show(tester);
      await reveal(tester, find.byKey(HomePage.reconfirmKey));

      expect(find.text(AppStrings.reconfirmDays('شنبه، دوشنبه')), findsOneWidget);
      expect(find.text('بازهٔ زمانی شما ۳۰ آبان ۱۴۰۵ متوقف می‌شود.'), findsOneWidget, reason: 'Persian digits');
      await tester.tap(find.text(AppStrings.confirmStillAvailable));
      await tester.pumpAndSettle();

      expect(availability.actions, [('confirm', 'w-1')], reason: 'the fresh and the paused windows are left alone');
      expect(find.text(AppStrings.availabilityConfirmed), findsOneWidget);
      expect(find.byKey(HomePage.reconfirmKey), findsNothing);
    });

    testWidgets('active weekly windows confirmed recently: no reminder', (tester) async {
      availability.mine = [testWindow(id: 'w-1', pausesOn: '1405/09/20')];
      await show(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(HomePage.reconfirmKey), findsNothing);
    });

    testWidgets('no active weekly window: no reminder', (tester) async {
      availability.mine = [testWindow(id: 'w-once', kind: AvailabilityKind.oneOff)];
      await show(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(HomePage.reconfirmKey), findsNothing);
    });
  });
}

/// A profile that cannot be read.
class _UnreadableProfile extends FakeProfileRepository {
  @override
  Future<Either<Failure, MyProfile>> getMyProfile() async => const Left(NetworkFailure(AppStrings.offlineActionError));
}
