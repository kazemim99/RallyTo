import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/blocked_players_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/my_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/player_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/pages/blocked_players_page.dart';
import 'package:rallyto_app/features/profile/presentation/pages/my_profile_page.dart';
import 'package:rallyto_app/features/profile/presentation/pages/player_profile_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// The profile screens, right to left: the player's own profile, another player's, and the block list.
void main() {
  late FakeProfileRepository profiles;

  setUp(() => profiles = FakeProfileRepository());

  group('my profile', () {
    Future<MyProfileCubit> showMyProfile(WidgetTester tester) async {
      // Tall enough for the whole page, so every section is built.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = MyProfileCubit(profiles, FakeCatalogRepository());
      addTearDown(cubit.close);
      await cubit.load();
      await pumpInShell(tester, BlocProvider.value(value: cubit, child: const MyProfilePage()));
      return cubit;
    }

    testWidgets('renders right to left: a centred hero, then menu rows with the icon on the right', (tester) async {
      await showMyProfile(tester);

      final page = tester.element(find.byType(MyProfilePage));
      expect(Directionality.of(page), TextDirection.rtl);

      final width = tester.getSize(find.byType(MaterialApp)).width;
      final avatar = tester.getRect(find.byKey(MyProfilePage.avatarKey));
      expect(avatar.center.dx, moreOrLessEquals(width / 2, epsilon: 1), reason: 'the hero is centred');
      expect(find.text('سارا'), findsOneWidget);
      expect(find.text('تهران، ۲۵ تا ۳۴ سال'), findsOneWidget, reason: 'city and age range in Persian digits');
      expect(find.text('صبح‌های جمعه بازی می‌کنم'), findsOneWidget, reason: 'the bio');

      final icon = tester.getRect(
        find.descendant(of: find.byKey(MyProfilePage.reputationKey), matching: find.byIcon(Icons.star_outline_rounded)),
      );
      final label = tester.getRect(find.text(AppStrings.myReputationTitle));
      expect(icon.left, greaterThan(label.right), reason: 'the row starts with its icon, on the right');
      for (final text in [
        AppStrings.myReputationTitle,
        AppStrings.sportProfilesTitle,
        AppStrings.favoriteClubsTitle,
        AppStrings.availabilityTitle,
        AppStrings.notificationSettingsTitle,
        AppStrings.blockedPlayersTitle,
        AppStrings.myReportsTitle,
        AppStrings.signOut,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('the completion card counts what is filled in and nudges for the photo', (tester) async {
      await showMyProfile(tester);

      expect(find.byKey(MyProfilePage.completionKey), findsOneWidget);
      expect(find.text(AppStrings.percentLabel('۸۰')), findsOneWidget, reason: 'all but the photo');
      expect(find.text(AppStrings.completionHintPhoto), findsOneWidget);
    });

    testWidgets('a complete profile shows no completion card', (tester) async {
      profiles.profile = testMyProfile(photoUrl: 'https://api.test/media/avatars/u-1.jpg');
      await showMyProfile(tester);

      expect(find.byKey(MyProfilePage.completionKey), findsNothing);
    });

    testWidgets('«ویرایش» opens name, bio and city, with the age range and the gender that cannot change', (
      tester,
    ) async {
      await showMyProfile(tester);

      await tester.tap(find.byKey(MyProfilePage.editBasicsKey));
      await tester.pumpAndSettle();

      expect(find.text('۲۵ تا ۳۴ سال'), findsOneWidget, reason: 'the age range in Persian digits');
      expect(find.text('آقا (${AppStrings.genderCannotChange})'), findsNothing);
      expect(find.text('خانم (${AppStrings.genderCannotChange})'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'صبح‌های جمعه بازی می‌کنم'), findsOneWidget);
    });

    testWidgets('sport profiles: the level in its own words, its description and the facts', (tester) async {
      await showMyProfile(tester);

      await tester.tap(find.byKey(MyProfilePage.sportsKey));
      await tester.pumpAndSettle();

      expect(find.text('تنیس'), findsOneWidget);
      expect(find.text(AppStrings.levelNamed('متوسط')), findsOneWidget);
      expect(find.text('سرویس و بک‌هند مطمئن دارید'), findsOneWidget);
      expect(find.text('۱ تا ۳ سال'), findsOneWidget);
      expect(find.text('انفرادی، دونفره'), findsOneWidget);
      expect(find.text(AppStrings.goalFriendlyMatch), findsOneWidget);
      expect(find.byKey(MyProfilePage.addSportKey), findsOneWidget);
    });

    testWidgets('home clubs are listed in their own section', (tester) async {
      await showMyProfile(tester);

      await tester.tap(find.byKey(MyProfilePage.homeClubsKey));
      await tester.pumpAndSettle();

      expect(find.text('باشگاه انقلاب'), findsOneWidget);
      expect(find.byKey(MyProfilePage.homeVenuesKey), findsOneWidget);
    });

    testWidgets('the visibility switch is explained, and turning it on saves SameGender', (tester) async {
      await showMyProfile(tester);

      expect(find.text(AppStrings.visibilitySameGender), findsOneWidget);
      expect(find.text(AppStrings.visibilityExplanation), findsOneWidget);

      await tester.tap(find.byKey(MyProfilePage.visibilityKey));
      await tester.pumpAndSettle();

      expect(profiles.visibilitySet.single.wire, 'SameGender');
      expect(find.text(AppStrings.saved), findsOneWidget);
    });

    testWidgets('removing the last sport: confirmed, refused, and the server\'s words shown', (tester) async {
      const message = 'دست‌کم یک ورزش باید در پروفایل بماند.';
      profiles.editFailure = const ServerFailure(message, code: 'LAST_SPORT_PROFILE', statusCode: 409);
      await showMyProfile(tester);
      await tester.tap(find.byKey(MyProfilePage.sportsKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MyProfilePage.removeSportKey('s-tennis')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.removeSportQuestion('تنیس')), findsOneWidget);
      await tester.tap(find.text(AppStrings.remove));
      await tester.pumpAndSettle();

      expect(profiles.sportsRemoved, ['s-tennis']);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets("sign-out is the app's sign-out: the before-sign-out work runs, then the session ends", (tester) async {
      final session = AuthSessionCubit(memoryTokenStorage(MemorySecureStorage(timers: false)));
      addTearDown(session.close);
      await session.signIn(testSession(profileCompleted: true));
      final ran = <String>[];
      session.addBeforeSignOut(() async => ran.add('unregister push'));
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = MyProfileCubit(profiles, FakeCatalogRepository());
      addTearDown(cubit.close);
      await cubit.load();
      await pumpInShell(
        tester,
        BlocProvider.value(
          value: session,
          child: BlocProvider.value(value: cubit, child: const MyProfilePage()),
        ),
      );

      await tester.tap(find.byKey(MyProfilePage.signOutKey));
      await tester.pumpAndSettle();

      expect(ran, ['unregister push']);
      expect(session.state, const Unauthenticated());
    });
  });

  group("another player's profile", () {
    /// Opened over another screen, as from a search result, so blocking can leave it.
    Future<void> showPlayer(WidgetTester tester) async {
      final cubit = PlayerProfileCubit(profiles, FakeAvailabilityRepository(), FakeCatalogRepository(), 'u-2');
      addTearDown(cubit.close);
      await cubit.load();
      await pumpInShell(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(value: cubit, child: const PlayerProfilePage()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('age range, coarse last activity, sports, home clubs and active windows', (tester) async {
      await showPlayer(tester);

      expect(find.text('علی'), findsOneWidget);
      expect(find.text('۳۵ تا ۴۴ سال ‏•‏ تهران ‏•‏ ${AppStrings.lastActiveThisWeek}'), findsOneWidget);
      expect(find.text(AppStrings.memberSince('آبان ۱۴۰۵')), findsOneWidget);
      expect(find.text('دنبال هم‌بازی دونفره'), findsOneWidget, reason: 'the bio');
      expect(find.text('تنیس'), findsOneWidget);
      expect(find.text(AppStrings.levelNamed('متوسط')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('مجموعه آزادی'), 200);
      expect(find.text(AppStrings.favoriteClubsTitle), findsOneWidget);
      expect(find.text('مجموعه آزادی'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('شنبه، دوشنبه، ۱۸:۰۰ تا ۲۰:۰۰'), 200);
      expect(find.text('شنبه، دوشنبه، ۱۸:۰۰ تا ۲۰:۰۰'), findsOneWidget);
    });

    testWidgets('message and invite stay pinned at the bottom', (tester) async {
      await showPlayer(tester);

      expect(find.byType(StickyActions), findsOneWidget);
      expect(find.byKey(PlayerProfilePage.messageKey), findsOneWidget);
      expect(find.byKey(PlayerProfilePage.inviteKey), findsOneWidget);
      final height = tester.getSize(find.byType(PlayerProfilePage)).height;
      expect(tester.getRect(find.byKey(PlayerProfilePage.inviteKey)).bottom, greaterThan(height - 100));
    });

    testWidgets('blocking, from the overflow menu, asks first, then blocks', (tester) async {
      await showPlayer(tester);

      await tester.tap(find.byKey(PlayerProfilePage.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PlayerProfilePage.blockKey));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.blockQuestion('علی')), findsOneWidget);
      expect(find.text(AppStrings.blockExplanation), findsOneWidget);

      await tester.tap(find.byKey(PlayerProfilePage.confirmBlockKey));
      await tester.pumpAndSettle();

      expect(profiles.blocked, ['u-2']);
      expect(find.byType(PlayerProfilePage), findsNothing, reason: 'their profile is no longer visible');
      expect(find.text(AppStrings.blocked('علی')), findsOneWidget);
    });

    testWidgets('blocked, hidden or missing: «بازیکن پیدا نشد», with no retry', (tester) async {
      profiles.playerFailure = const NotFoundFailure('Not found', code: 'PLAYER_NOT_FOUND');
      await showPlayer(tester);

      expect(find.text(AppStrings.playerNotFound), findsOneWidget);
      expect(find.text(AppStrings.retry), findsNothing);
      expect(find.byKey(PlayerProfilePage.moreKey), findsNothing);
      expect(find.byKey(PlayerProfilePage.inviteKey), findsNothing);
    });
  });

  testWidgets('the block list unblocks a player', (tester) async {
    final cubit = BlockedPlayersCubit(profiles);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const BlockedPlayersPage()));

    expect(find.text('مزاحم'), findsOneWidget);
    await tester.tap(find.byKey(BlockedPlayersPage.unblockKey('u-9')));
    await tester.pumpAndSettle();

    expect(profiles.unblocked, ['u-9']);
    expect(find.text(AppStrings.blockedPlayersEmpty), findsOneWidget);
    expect(find.text(AppStrings.unblocked('مزاحم')), findsOneWidget);
  });
}
