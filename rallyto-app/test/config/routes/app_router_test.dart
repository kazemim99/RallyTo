import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';
import 'package:rallyto_app/features/notifications/presentation/deep_links.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/memory_secure_storage.dart';

/// Where each sign-in state may be, and where it is sent otherwise:
/// * signed out → only `/auth/…`, else `/auth/phone`;
/// * signed in, profile not completed → only `/onboarding`;
/// * signed in and onboarded → anywhere but `/auth/…`, `/onboarding` and `/`, which go to `/home`.
void main() {
  const signedOut = Unauthenticated();
  const notOnboarded = Authenticated(profileCompleted: false, roles: ['Player']);
  const onboarded = Authenticated(profileCompleted: true, roles: ['Player']);

  String? redirect(String location, AuthState state) => AppRouter.redirectFor(location, state);

  group('signed out', () {
    test('every app location goes to phone entry', () {
      for (final location in ['/home', '/onboarding', '/', '', '/matches/42', '/authority']) {
        expect(redirect(location, signedOut), Routes.phone, reason: location);
      }
    });

    test('phone entry, and any later screen under /auth, stay', () {
      expect(redirect(Routes.phone, signedOut), isNull);
      expect(redirect(Routes.code, signedOut), isNull, reason: 'code entry');
    });

    test('a server sign-out message does not change where the player may be', () {
      const endedByServer = Unauthenticated(message: 'حساب شما مسدود شده است');
      expect(redirect('/home', endedByServer), Routes.phone);
      expect(redirect(Routes.phone, endedByServer), isNull);
    });

    test('bare /auth goes to phone entry', () {
      expect(redirect(Routes.auth, signedOut), Routes.phone);
    });
  });

  group('signed in, profile not completed', () {
    test('every other location goes to onboarding', () {
      for (final location in ['/home', '/auth/phone', '/auth/code', '/', '/matches/42']) {
        expect(redirect(location, notOnboarded), Routes.onboarding, reason: location);
      }
    });

    test('onboarding stays', () {
      expect(redirect(Routes.onboarding, notOnboarded), isNull);
    });
  });

  group('signed in and onboarded', () {
    test('sign-in screens, onboarding and the root go home', () {
      for (final location in ['/auth/phone', '/auth/code', '/auth', '/onboarding', '/']) {
        expect(redirect(location, onboarded), Routes.home, reason: location);
      }
    });

    test('home and any other app location stay', () {
      for (final location in ['/home', '/matches/42', '/profile', Routes.venuePath('3fa85f64-5717-4562-b3fc')]) {
        expect(redirect(location, onboarded), isNull, reason: location);
      }
    });
  });

  test('a venue page is addressable by id', () {
    expect(Routes.venuePath('3fa85f64-5717'), '/venues/3fa85f64-5717');
    expect(redirect(Routes.venuePath('v-1'), signedOut), Routes.phone);
    expect(redirect(Routes.venuePath('v-1'), notOnboarded), Routes.onboarding);
  });

  test('search, saved searches, games, invitations and share links are addressable, behind sign-in and onboarding', () {
    expect(Routes.matchPath('3fa85f64-5717'), '/matches/3fa85f64-5717');
    expect(Routes.invitePlayerPath('u-2'), '/players/u-2/invite');
    expect(Routes.sharedMatchPath('a1b2c3d4e5f6'), '/m/a1b2c3d4e5f6');
    for (final location in [
      Routes.search,
      Routes.savedSearches,
      Routes.matches,
      Routes.matchNew,
      Routes.matchPath('m-1'),
      Routes.invitePlayerPath('u-2'),
      Routes.sharedMatchPath('a1b2c3d4e5f6'),
    ]) {
      expect(redirect(location, onboarded), isNull, reason: location);
      expect(redirect(location, notOnboarded), Routes.onboarding, reason: location);
      expect(redirect(location, signedOut), Routes.phone, reason: location);
    }
  });

  group('the new routes resolve to their screens', () {
    late AppRouter appRouter;

    setUp(() {
      final session = AuthSessionCubit(
        TokenStorage(SecureStorageService(MemorySecureStorage(timers: false))),
        api: FakeAuthApi(),
      );
      addTearDown(session.close);
      appRouter = AppRouter(session);
      addTearDown(appRouter.dispose);
    });

    String routeOf(String location) {
      final match = appRouter.router.configuration.findMatch(Uri.parse(location));
      return match.last.route.path;
    }

    test('/matches/new is the form, not a game called «new»', () {
      expect(routeOf('/matches/new'), Routes.matchNew);
      expect(routeOf('/matches/3fa85f64'), Routes.match);
      expect(appRouter.router.configuration.findMatch(Uri.parse('/matches/3fa85f64')).pathParameters, {
        'id': '3fa85f64',
      });
    });

    test('the chat inbox, a conversation, a player\'s and a game\'s conversation, and the notifications', () {
      expect(routeOf('/chat'), Routes.chat);
      expect(routeOf('/chat/c-1'), Routes.conversation);
      expect(appRouter.router.configuration.findMatch(Uri.parse('/chat/c-1')).pathParameters, {'id': 'c-1'});
      expect(routeOf('/players/u-2/chat'), Routes.playerChat);
      expect(routeOf('/matches/m-1/chat'), Routes.matchChat, reason: 'not a game called «m-1/chat»');
      expect(routeOf('/matches/m-1'), Routes.match);
      expect(routeOf('/notifications'), Routes.notifications);
      expect(routeOf('/notifications/settings'), Routes.notificationSettings);
    });

    test("every notification deep link lands on the app's own screen", () {
      expect(routeOf(DeepLinks.targetFor('/matches/m-1')), Routes.match);
      expect(routeOf(DeepLinks.targetFor('/chat/c-1')), Routes.conversation);
      expect(routeOf(DeepLinks.targetFor('/saved-searches/ss-1')), Routes.savedSearches);
      expect(routeOf(DeepLinks.targetFor('/availability')), Routes.availability);
      expect(routeOf(DeepLinks.targetFor('/profile')), Routes.profile);
      expect(routeOf(DeepLinks.targetFor('/something-new')), Routes.notifications);
    });

    test('rating a player of a game, the report form, and my reports', () {
      expect(routeOf('/matches/m-1/rate/u-2'), Routes.rateMatchPlayer, reason: 'not a game called «m-1/rate/u-2»');
      expect(appRouter.router.configuration.findMatch(Uri.parse('/matches/m-1/rate/u-2')).pathParameters, {
        'id': 'm-1',
        'playerId': 'u-2',
      });
      expect(routeOf('/report'), Routes.report);
      expect(routeOf('/profile/reports'), Routes.myReports, reason: 'not the profile');
      expect(routeOf('/profile'), Routes.profile);
    });

    testWidgets('the report form without a target (a deep link, a restored route) goes home', (tester) async {
      final route = appRouter.router.configuration.findMatch(Uri.parse('/report')).last.route;
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      GoRouterState state(Object? extra) => GoRouterState(
        appRouter.router.configuration,
        uri: Uri.parse('/report'),
        matchedLocation: '/report',
        fullPath: '/report',
        pathParameters: const {},
        extra: extra,
        pageKey: const ValueKey('/report'),
      );

      expect(await route.redirect!(context, state(null)), Routes.home);
      expect(await route.redirect!(context, state('u-2')), Routes.home);
      expect(await route.redirect!(context, state(const ReportTarget.player('u-2'))), isNull);
    });

    test('sign-in and onboarding are outside the tab shell; every other screen is in it', () {
      bool inShell(String location) =>
          appRouter.router.configuration.findMatch(Uri.parse(location)).matches.first is ShellRouteMatch;
      for (final location in [Routes.phone, Routes.code, Routes.onboarding]) {
        expect(inShell(location), isFalse, reason: location);
      }
      for (final location in [
        Routes.home,
        Routes.search,
        Routes.matches,
        Routes.chat,
        Routes.profile,
        Routes.playerPath('u-2'),
        Routes.matchPath('m-1'),
        Routes.venuePath('v-1'),
        Routes.savedSearches,
        Routes.availability,
        Routes.notifications,
        Routes.myReports,
        Routes.blockedPlayers,
        Routes.sharedMatchPath('t'),
        Routes.matchNew,
        Routes.invitePlayerPath('u-2'),
        Routes.availabilityNew,
        Routes.availabilityEdit,
        Routes.rateMatchPlayerPath('m-1', 'u-2'),
        Routes.report,
        Routes.chatPath('c-1'),
        Routes.playerChatPath('u-2'),
        Routes.matchChatPath('m-1'),
        Routes.notificationSettings,
      ]) {
        expect(inShell(location), isTrue, reason: location);
      }
    });

    test('the bar hides on forms and the conversation screen, and shows on tab roots and read-only pages', () {
      expect(AppRouter.fullScreenRoutes, {
        Routes.matchNew,
        Routes.invitePlayer,
        Routes.availabilityNew,
        Routes.availabilityEdit,
        Routes.rateMatchPlayer,
        Routes.report,
        Routes.conversation,
        Routes.playerChat,
        Routes.matchChat,
        Routes.notificationSettings,
      });
      for (final shown in [
        Routes.home,
        Routes.search,
        Routes.matches,
        Routes.chat,
        Routes.profile,
        Routes.player,
        Routes.match,
        Routes.sharedMatch,
        Routes.venue,
        Routes.savedSearches,
        Routes.availability,
        Routes.notifications,
        Routes.myReports,
        Routes.blockedPlayers,
      ]) {
        expect(AppRouter.fullScreenRoutes, isNot(contains(shown)), reason: shown);
      }
    });

    test('the search, its saved searches, my games, an invitation and a share link', () {
      expect(routeOf('/search'), Routes.search);
      expect(routeOf('/search/saved'), Routes.savedSearches);
      expect(routeOf('/matches'), Routes.matches);
      expect(routeOf('/players/u-2/invite'), Routes.invitePlayer);
      expect(routeOf('/players/u-2'), Routes.player);
      expect(routeOf('/m/a1b2c3d4e5f6'), Routes.sharedMatch);
      expect(appRouter.router.configuration.findMatch(Uri.parse('/m/a1b2c3d4e5f6')).pathParameters, {
        'token': 'a1b2c3d4e5f6',
      });
    });
  });

  test('ratings and reports are addressable, behind sign-in and onboarding', () {
    expect(Routes.rateMatchPlayerPath('m-1', 'u-2'), '/matches/m-1/rate/u-2');
    for (final location in [Routes.rateMatchPlayerPath('m-1', 'u-2'), Routes.report, Routes.myReports]) {
      expect(redirect(location, onboarded), isNull, reason: location);
      expect(redirect(location, notOnboarded), Routes.onboarding, reason: location);
      expect(redirect(location, signedOut), Routes.phone, reason: location);
    }
  });

  test('chat and notifications are addressable, behind sign-in and onboarding', () {
    expect(Routes.chatPath('3fa85f64'), '/chat/3fa85f64');
    expect(Routes.playerChatPath('u-2'), '/players/u-2/chat');
    expect(Routes.matchChatPath('m-1'), '/matches/m-1/chat');
    for (final location in [
      Routes.chat,
      Routes.chatPath('c-1'),
      Routes.playerChatPath('u-2'),
      Routes.matchChatPath('m-1'),
      Routes.notifications,
      Routes.notificationSettings,
    ]) {
      expect(redirect(location, onboarded), isNull, reason: location);
      expect(redirect(location, notOnboarded), Routes.onboarding, reason: location);
      expect(redirect(location, signedOut), Routes.phone, reason: location);
    }
  });

  test('the profile, player and availability screens are addressable, and held behind sign-in and onboarding', () {
    expect(Routes.playerPath('3fa85f64-5717'), '/players/3fa85f64-5717');
    for (final location in [
      Routes.profile,
      Routes.blockedPlayers,
      Routes.playerPath('u-2'),
      Routes.availability,
      Routes.availabilityNew,
      Routes.availabilityEdit,
    ]) {
      expect(redirect(location, onboarded), isNull, reason: location);
      expect(redirect(location, notOnboarded), Routes.onboarding, reason: location);
      expect(redirect(location, signedOut), Routes.phone, reason: location);
    }
  });
}
