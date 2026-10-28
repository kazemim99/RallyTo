import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/config/routes/main_shell.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/current_user.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/di/injection.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/share/share_service.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';
import 'package:rallyto_app/features/auth/presentation/pages/phone_page.dart';
import 'package:rallyto_app/features/availability/domain/availability_repository.dart';
import 'package:rallyto_app/features/catalog/domain/catalog_repository.dart';
import 'package:rallyto_app/features/chat/domain/chat_repository.dart';
import 'package:rallyto_app/features/chat/domain/entities/chat.dart';
import 'package:rallyto_app/features/chat/presentation/pages/chat_inbox_page.dart';
import 'package:rallyto_app/features/chat/presentation/pages/conversation_page.dart';
import 'package:rallyto_app/features/home/presentation/pages/home_page.dart';
import 'package:rallyto_app/features/matches/domain/match_repository.dart';
import 'package:rallyto_app/features/matches/presentation/pages/match_form_page.dart';
import 'package:rallyto_app/features/matches/presentation/pages/my_matches_page.dart';
import 'package:rallyto_app/features/notifications/domain/notification_repository.dart';
import 'package:rallyto_app/features/notifications/presentation/pages/notification_inbox_page.dart';
import 'package:rallyto_app/features/profile/domain/profile_repository.dart';
import 'package:rallyto_app/features/profile/presentation/pages/my_profile_page.dart';
import 'package:rallyto_app/features/profile/presentation/pages/player_profile_page.dart';
import 'package:rallyto_app/features/ratings/domain/rating_repository.dart';
import 'package:rallyto_app/features/reports/domain/report_repository.dart';
import 'package:rallyto_app/features/search/domain/search_repository.dart';
import 'package:rallyto_app/features/search/presentation/pages/partner_search_page.dart';
import 'package:rallyto_app/main.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_catalog.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_matches.dart';
import '../../helpers/fake_notifications.dart';
import '../../helpers/fake_profile.dart';
import '../../helpers/fake_ratings.dart';
import '../../helpers/fake_realtime.dart';
import '../../helpers/fake_reports.dart';
import '../../helpers/fake_search.dart';
import '../../helpers/fake_share.dart';
import '../../helpers/memory_secure_storage.dart';

/// The signed-in frame: five tab stacks (right to left: home, search, my games, chats, profile) under the bottom bar,
/// each keeping its own stack; the bar's chat badge from the one chat-unread source; the bar hidden on full-screen
/// flows; every route still reachable by push and by go.
void main() {
  late FakeChatRepository chat;

  Future<GoRouter> startApp(WidgetTester tester, {bool signedIn = true}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await configureDependencies();
    addTearDown(getIt.reset);

    final storage = MemorySecureStorage(timers: false);
    if (signedIn) storage.values[TokenStorage.sessionKey] = testSession(profileCompleted: true).encode();
    final tokens = TokenStorage(SecureStorageService(storage));
    final session = AuthSessionCubit(tokens, api: FakeAuthApi());
    addTearDown(session.close);
    chat = FakeChatRepository();

    void swap<T extends Object>(T fake) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(fake);
    }

    swap<AuthApi>(FakeAuthApi());
    swap<TokenStorage>(tokens);
    swap<AuthSessionCubit>(session);
    swap<CatalogRepository>(FakeCatalogRepository());
    swap<ChatRepository>(chat);
    swap<NotificationRepository>(FakeNotificationRepository());
    swap<RealtimeClient>(FakeRealtimeClient());
    swap<SearchRepository>(FakeSearchRepository());
    swap<ProfileRepository>(FakeProfileRepository());
    swap<AvailabilityRepository>(FakeAvailabilityRepository());
    swap<MatchRepository>(FakeMatchRepository());
    swap<RatingRepository>(FakeRatingRepository());
    swap<ReportRepository>(FakeReportRepository());
    swap<CurrentUser>(FakeCurrentUser());
    swap<ShareService>(FakeShareService());

    await session.restore();
    await tester.pumpWidget(RallytoApp(session: session));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    return GoRouter.of(context);
  }

  Finder tab(int index) => find.byKey(MainShell.tabKeys[index]);
  bool selected(WidgetTester tester, int index) => tester.widget<Semantics>(tab(index)).properties.selected ?? false;
  Finder visibleBar() => find.byKey(MainShell.navKey).hitTestable();

  Future<void> tapTab(WidgetTester tester, int index) async {
    await tester.tap(tab(index));
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the bar: five tabs right to left, home selected', (tester) async {
    await startApp(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(visibleBar(), findsOneWidget);
    final labels = [
      AppStrings.navHome,
      AppStrings.navSearch,
      AppStrings.navMatches,
      AppStrings.navChat,
      AppStrings.navProfile,
    ];
    final xs = [
      for (final label in labels)
        tester.getCenter(find.descendant(of: find.byKey(MainShell.navKey), matching: find.text(label))).dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], lessThan(xs[i - 1]), reason: '${labels[i]} is left of ${labels[i - 1]}');
    }
    expect(selected(tester, 0), isTrue);
    for (var i = 1; i < 5; i++) {
      expect(selected(tester, i), isFalse);
    }
  });

  testWidgets('each tab opens its root screen', (tester) async {
    await startApp(tester);

    await tapTab(tester, 1);
    expect(find.byType(PartnerSearchPage), findsOneWidget);
    expect(selected(tester, 1), isTrue);
    await tapTab(tester, 2);
    expect(find.byType(MyMatchesPage), findsOneWidget);
    await tapTab(tester, 3);
    expect(find.byType(ChatInboxPage), findsOneWidget);
    await tapTab(tester, 4);
    expect(find.byType(MyProfilePage), findsOneWidget);
    await tapTab(tester, 0);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the chats tab carries the unread count, from the same source as home, kept live', (tester) async {
    await startApp(tester);
    // FakeChatRepository starts at one conversation and one request.

    final bar = find.byKey(MainShell.navKey);
    expect(find.descendant(of: bar, matching: find.text('۲')), findsOneWidget);
    expect(find.byKey(HomePage.chatBadgeKey), findsOneWidget);
    expect(chat.calls.where((c) => c == 'unread'), hasLength(1), reason: 'one ChatBadgeCubit for home and the bar');
    expect(tester.widget<Semantics>(tab(3)).properties.label, contains(AppStrings.unreadCount('۲')));

    chat.unread = const ChatUnreadCounts(conversations: 12);
    chat.emit(MessageReceived(testMessage(id: 'm-9', sender: other, minute: 9)));
    await tester.pumpAndSettle();
    expect(find.descendant(of: bar, matching: find.text('۹+')), findsOneWidget);

    chat.unread = const ChatUnreadCounts();
    chat.emit(MessageReceived(testMessage(id: 'm-10', sender: other, minute: 10)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.textContaining(RegExp('[۰-۹]'))),
      findsNothing,
      reason: 'no badge at zero',
    );
  });

  testWidgets('each tab keeps its own stack; tapping the current tab pops it to its root', (tester) async {
    final router = await startApp(tester);

    unawaited(router.push(Routes.notifications));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationInboxPage), findsOneWidget);
    expect(visibleBar(), findsOneWidget, reason: 'the notification inbox is a read-only page');
    expect(selected(tester, 0), isTrue);

    await tapTab(tester, 2);
    expect(find.byType(MyMatchesPage), findsOneWidget);

    await tapTab(tester, 0);
    expect(find.byType(NotificationInboxPage), findsOneWidget, reason: 'home kept its stack');

    await tapTab(tester, 0);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(NotificationInboxPage), findsNothing);
  });

  testWidgets('full-screen flows hide the bar; a player opened from a conversation shows it again', (tester) async {
    final router = await startApp(tester);

    unawaited(router.push(Routes.chatPath('c-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationPage), findsOneWidget);
    expect(visibleBar(), findsNothing);

    // A shell page pushed over a full-screen one: this would build the shell twice were the conversation on the
    // root navigator.
    unawaited(router.push(Routes.playerPath('u-2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PlayerProfilePage), findsOneWidget);
    expect(visibleBar(), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ConversationPage), findsOneWidget);
    expect(visibleBar(), findsNothing);

    chat.calls.clear();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(visibleBar(), findsOneWidget);
    expect(chat.calls, contains('unread'), reason: 'leaving a conversation re-reads the badge');
  });

  testWidgets('forms hide the bar', (tester) async {
    final router = await startApp(tester);

    unawaited(router.push(Routes.matchNew));
    await tester.pumpAndSettle();
    expect(find.byType(MatchFormPage), findsOneWidget);
    expect(visibleBar(), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(visibleBar(), findsOneWidget);
  });

  testWidgets('a location opened with go lands in its own tab', (tester) async {
    final router = await startApp(tester);

    router.go(Routes.playerPath('u-2'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerProfilePage), findsOneWidget);
    expect(selected(tester, 1), isTrue);

    router.go(Routes.sharedMatchPath('a1b2c3'));
    await tester.pumpAndSettle();
    expect(selected(tester, 2), isTrue);

    router.go(Routes.blockedPlayers);
    await tester.pumpAndSettle();
    expect(selected(tester, 4), isTrue);
    expect(visibleBar(), findsOneWidget);
  });

  testWidgets('signed out there is no bar', (tester) async {
    await startApp(tester, signedIn: false);

    expect(find.byType(PhonePage), findsOneWidget);
    expect(find.byKey(MainShell.navKey), findsNothing);
  });
}
