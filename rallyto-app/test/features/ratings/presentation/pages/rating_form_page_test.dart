import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/presentation/bloc/rating_form_cubit.dart';
import 'package:rallyto_app/features/ratings/presentation/pages/rating_form_page.dart';

import '../../../../helpers/fake_ratings.dart';
import '../../../../helpers/router_shell.dart';

/// The rating form: the double-blind and no-edit notice up front, stars, tags (at most 3), the required level
/// accuracy, the admins-only note; it closes with `true` once stored, and stays with the reason when refused.
void main() {
  late FakeRatingRepository ratings;
  late List<Object?> closedWith;

  setUp(() {
    ratings = FakeRatingRepository();
    closedWith = [];
  });

  /// Opened from a stand-in game screen, which records what the form closed with.
  Future<void> show(WidgetTester tester, {String? name = 'علی'}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () async => closedWith.add(await context.push<bool>('/rate')),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/rate',
        builder: (context, state) => BlocProvider(
          create: (_) => RatingFormCubit(ratings, RatingTarget(matchId: 'm-1', rateeId: 'u-2', rateeName: name)),
          child: const RatingFormPage(),
        ),
      ),
    ]);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says it is double-blind and final, and that the note is for admins only', (tester) async {
    await show(tester);

    expect(find.text(AppStrings.ratePlayer('علی')), findsOneWidget);
    expect(find.text(AppStrings.ratingBlindNotice), findsOneWidget);
    expect(find.text(AppStrings.privateNoteHint), findsOneWidget);
    expect(find.text(AppStrings.privateNoteAdminsOnly), findsOneWidget);
    expect(find.text(AppStrings.ratingBlindTitle), findsOneWidget);
    for (final tag in [
      AppStrings.tagOnTime,
      AppStrings.tagFriendly,
      AppStrings.tagFairCalls,
      AppStrings.tagGoodRally,
      AppStrings.tagSportsmanship,
      AppStrings.tagWellOrganised,
    ]) {
      expect(find.text(tag), findsOneWidget);
    }
    for (final level in [AppStrings.levelLower, AppStrings.levelAboutRight, AppStrings.levelHigher]) {
      expect(find.text(level), findsOneWidget);
    }
  });

  testWidgets('without a name, the partner is «هم‌بازی»', (tester) async {
    await show(tester, name: null);

    expect(find.text(AppStrings.ratePlayer(AppStrings.ratingDefaultName)), findsOneWidget);
  });

  testWidgets('a full rating is sent and the form closes with true', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(RatingFormPage.starKey(4)));
    await tester.tap(find.byKey(RatingFormPage.tagKey(RatingTag.onTime)));
    await tester.tap(find.byKey(RatingFormPage.tagKey(RatingTag.goodRally)));
    await tester.tap(find.byKey(RatingFormPage.levelKey(LevelAccuracy.aboutRight)));
    await tester.enterText(find.byKey(RatingFormPage.noteKey), 'کمی دیر رسید');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));

    await tester.tap(find.byKey(RatingFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(
      ratings.rated.single.$2,
      const RatingDraft(
        rateeId: 'u-2',
        stars: 4,
        tags: [RatingTag.onTime, RatingTag.goodRally],
        levelAccuracy: LevelAccuracy.aboutRight,
        privateNote: 'کمی دیر رسید',
      ),
    );
    expect(find.byType(RatingFormPage), findsNothing);
    expect(closedWith, [true]);
    expect(find.text(AppStrings.ratingSubmitted), findsOneWidget);
  });

  testWidgets('a fourth tag is refused; a missing level answer is said before sending', (tester) async {
    await show(tester);

    for (final tag in [RatingTag.onTime, RatingTag.friendly, RatingTag.fairCalls, RatingTag.goodRally]) {
      await tester.tap(find.byKey(RatingFormPage.tagKey(tag)));
      await tester.pumpAndSettle();
    }
    expect(find.text(AppStrings.tooManyTags), findsOneWidget);
    expect(tester.widget<AppChip>(find.byKey(RatingFormPage.tagKey(RatingTag.goodRally))).tone, AppChipTone.neutral);
    expect(tester.widget<AppChip>(find.byKey(RatingFormPage.tagKey(RatingTag.fairCalls))).tone, AppChipTone.active);
    expect(find.text(AppStrings.countOf('۳', '۳')), findsOneWidget, reason: 'the tag counter');

    await tester.tap(find.byKey(RatingFormPage.starKey(5)));
    await tester.tap(find.byKey(RatingFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelAccuracyRequired), findsOneWidget);
    expect(ratings.rated, isEmpty);
    expect(find.byType(RatingFormPage), findsOneWidget);
  });

  testWidgets('a refusal (ALREADY_RATED) is said and the form stays', (tester) async {
    ratings.failure = const ServerFailure('x', code: 'ALREADY_RATED', statusCode: 409);
    await show(tester);

    await tester.tap(find.byKey(RatingFormPage.starKey(3)));
    await tester.tap(find.byKey(RatingFormPage.levelKey(LevelAccuracy.lower)));
    await tester.tap(find.byKey(RatingFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.alreadyRated), findsOneWidget);
    expect(find.byType(RatingFormPage), findsOneWidget);
    expect(closedWith, isEmpty);
  });
}
