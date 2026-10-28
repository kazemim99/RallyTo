import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/my_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/player_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/pages/my_profile_page.dart';
import 'package:rallyto_app/features/profile/presentation/pages/player_profile_page.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/presentation/widgets/reputation_widgets.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/report_form_cubit.dart';
import 'package:rallyto_app/features/reports/presentation/pages/report_form_page.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_ratings.dart';
import '../../../../helpers/fake_reports.dart';
import '../../../../helpers/router_shell.dart';

/// Reputation on the profiles (the tier badge, and per sport «بازیکن جدید» or the average, tags and level statement),
/// reporting a player or their photo from their page (with "block" leaving it), and the way to «گزارش‌های من».
void main() {
  late FakeProfileRepository profiles;
  late FakeReportRepository reports;

  setUp(() {
    profiles = FakeProfileRepository();
    reports = FakeReportRepository();
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Another player's page opened over a stand-in home, with the real report form behind `/report`.
  Future<void> showPlayer(WidgetTester tester) async {
    tall(tester);
    final cubit = PlayerProfileCubit(profiles, FakeAvailabilityRepository(), FakeCatalogRepository(), 'u-2');
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(onPressed: () => context.push('/player'), child: const Text('open')),
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const PlayerProfilePage()),
      ),
      GoRoute(
        path: Routes.report,
        builder: (context, state) => BlocProvider(
          create: (_) => ReportFormCubit(reports, state.extra! as ReportTarget),
          child: const ReportFormPage(),
        ),
      ),
    ]);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group("another player's page", () {
    testWidgets('the reliability badge, and the tennis average with its count, tags and level statement', (
      tester,
    ) async {
      profiles.player = testPlayerProfile(reputation: testReputation());
      await showPlayer(tester);

      expect(find.byType(ReliabilityBadge), findsOneWidget);
      expect(find.text('خوش‌قولی: خوب'), findsOneWidget);
      expect(find.byKey(SportReputationSummary.summaryKey('s-tennis')), findsOneWidget);
      expect(find.text('۴٫۳ ستاره از ۳ امتیاز'), findsOneWidget);
      expect(find.text(AppStrings.tagOnTime), findsOneWidget);
      expect(find.text(AppStrings.tagGoodRally), findsOneWidget);
      expect(find.text('بیشتر هم‌بازی‌ها می‌گویند سطح اعلام‌شده درست است'), findsOneWidget);
    });

    testWidgets('a new player: «بازیکن جدید» and «تازه‌وارد», no average', (tester) async {
      profiles.player = testPlayerProfile(
        reputation: testReputation(reliability: ReliabilityTier.newPlayer, isNew: true),
      );
      await showPlayer(tester);

      expect(find.text(AppStrings.reputationNewPlayer), findsOneWidget);
      expect(find.text(AppStrings.reliabilityNew), findsOneWidget);
      expect(find.textContaining('ستاره از'), findsNothing);
    });

    testWidgets('no reputation from the server: no badge and no summary', (tester) async {
      await showPlayer(tester);

      expect(find.byType(ReliabilityBadge), findsNothing);
      expect(find.byType(SportReputationSummary), findsNothing);
    });

    testWidgets('reporting the player with "block" files it and leaves their page, as a block does', (tester) async {
      await showPlayer(tester);

      await tester.tap(find.byKey(PlayerProfilePage.moreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(PlayerProfilePage.reportPhotoKey), findsNothing, reason: 'no photo, nothing to report');
      await tester.tap(find.byKey(PlayerProfilePage.reportKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportPlayerTitle), findsOneWidget);
      expect(find.text(AppStrings.reportBlockNamed('علی')), findsOneWidget);
      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.fakeProfile)));
      await tester.tap(find.byKey(ReportFormPage.blockKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(reports.filed.single.target, const ReportTarget.player('u-2', playerName: 'علی'));
      expect(reports.filed.single.block, isTrue);
      expect(find.byType(PlayerProfilePage), findsNothing, reason: 'their profile is no longer visible');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('reporting the photo, without blocking, stays on their page', (tester) async {
      profiles.player = testPlayerProfile(photoUrl: 'https://api.test/media/avatars/u-2.jpg');
      await showPlayer(tester);

      await tester.tap(find.byKey(PlayerProfilePage.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PlayerProfilePage.reportPhotoKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportPhotoTitle), findsOneWidget);
      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.inappropriateContent)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(reports.filed.single.target, const ReportTarget.photo('u-2', playerName: 'علی'));
      expect(reports.filed.single.block, isFalse);
      expect(find.byType(PlayerProfilePage), findsOneWidget);
    });
  });

  group('my profile', () {
    Future<void> showMine(WidgetTester tester) async {
      tall(tester);
      final cubit = MyProfileCubit(profiles, FakeCatalogRepository());
      addTearDown(cubit.close);
      await cubit.load();
      await pumpRouter(tester, [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(value: cubit, child: const MyProfilePage()),
        ),
        landingRoute(Routes.myReports),
        landingRoute(Routes.blockedPlayers),
        landingRoute(Routes.availability),
        landingRoute(Routes.notificationSettings),
      ]);
    }

    testWidgets('my own badge in the hero, and my reputation per sport in its section', (tester) async {
      profiles.profile = testMyProfile(reputation: testReputation(reliability: ReliabilityTier.high));
      await showMine(tester);

      expect(find.text('خوش‌قولی: عالی'), findsOneWidget);

      await tester.tap(find.byKey(MyProfilePage.reputationKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.myReputationTitle), findsOneWidget);
      expect(find.byKey(SportReputationSummary.summaryKey('s-tennis')), findsOneWidget);
      expect(find.text('۴٫۳ ستاره از ۳ امتیاز'), findsOneWidget);
      expect(find.text('خوش‌قولی: عالی'), findsOneWidget);
    });

    testWidgets('no reputation from the server: the section says there is none yet', (tester) async {
      await showMine(tester);

      await tester.tap(find.byKey(MyProfilePage.reputationKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reputationEmptyTitle), findsOneWidget);
      expect(find.byType(SportReputationSummary), findsNothing);
    });

    for (final (key, location) in [
      (MyProfilePage.blockedPlayersKey, Routes.blockedPlayers),
      (MyProfilePage.availabilityKey, Routes.availability),
      (MyProfilePage.notificationSettingsKey, Routes.notificationSettings),
    ]) {
      testWidgets('the profile menu links to $location', (tester) async {
        await showMine(tester);

        await tester.scrollUntilVisible(find.byKey(key), 200);
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();

        expect(find.text('landed $location'), findsOneWidget);
      });
    }

    testWidgets('«گزارش‌های من» is linked from the profile', (tester) async {
      await showMine(tester);

      await tester.scrollUntilVisible(find.byKey(MyProfilePage.myReportsKey), 200);
      await tester.tap(find.byKey(MyProfilePage.myReportsKey));
      await tester.pumpAndSettle();

      expect(find.text('landed /profile/reports'), findsOneWidget);
    });
  });
}
