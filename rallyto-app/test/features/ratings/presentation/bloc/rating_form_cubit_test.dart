import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/domain/rating_rules.dart';
import 'package:rallyto_app/features/ratings/presentation/bloc/rating_form_cubit.dart';

import '../../../../helpers/fake_ratings.dart';

/// Rating one partner: stars, up to 3 tags, the required level accuracy and a private note; what is missing is said
/// before asking the server, a refusal in the app's words for each code, and the form closes once stored.
void main() {
  late FakeRatingRepository ratings;

  setUp(() => ratings = FakeRatingRepository());

  RatingFormCubit open() {
    final cubit = RatingFormCubit(ratings, const RatingTarget(matchId: 'm-1', rateeId: 'u-2', rateeName: 'علی'));
    addTearDown(cubit.close);
    return cubit;
  }

  RatingFormCubit filled() => open()
    ..setStars(4)
    ..toggleTag(RatingTag.onTime)
    ..toggleTag(RatingTag.goodRally)
    ..setLevelAccuracy(LevelAccuracy.aboutRight)
    ..setNote('بازی خوبی بود');

  test('starts empty: no stars, tags or level, nothing sent', () {
    final cubit = open();

    expect(cubit.state.stars, 0);
    expect(cubit.state.tags, isEmpty);
    expect(cubit.state.levelAccuracy, isNull);
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.done, isFalse);
  });

  test('stars are 1 to 5; anything else is ignored', () {
    final cubit = open()..setStars(3);
    expect(cubit.state.stars, 3);

    cubit
      ..setStars(0)
      ..setStars(6);
    expect(cubit.state.stars, 3);
  });

  test('tags toggle; a fourth is refused with TOO_MANY_TAGS and not added', () {
    final cubit = open()
      ..toggleTag(RatingTag.onTime)
      ..toggleTag(RatingTag.friendly)
      ..toggleTag(RatingTag.onTime);
    expect(cubit.state.tags, [RatingTag.friendly]);

    cubit
      ..toggleTag(RatingTag.fairCalls)
      ..toggleTag(RatingTag.goodRally)
      ..toggleTag(RatingTag.sportsmanship);

    expect(cubit.state.tags, [RatingTag.friendly, RatingTag.fairCalls, RatingTag.goodRally]);
    expect(cubit.state.feedback?.code, RatingErrorCodes.tooManyTags);
    expect(cubit.state.feedback?.message, AppStrings.tooManyTags);
  });

  test('a full rating is sent once and closes the form', () async {
    final cubit = filled();

    await cubit.submit();

    expect(ratings.rated, hasLength(1));
    final (matchId, draft) = ratings.rated.single;
    expect(matchId, 'm-1');
    expect(
      draft,
      const RatingDraft(
        rateeId: 'u-2',
        stars: 4,
        tags: [RatingTag.onTime, RatingTag.goodRally],
        levelAccuracy: LevelAccuracy.aboutRight,
        privateNote: 'بازی خوبی بود',
      ),
    );
    expect(cubit.state.done, isTrue);
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.feedback?.message, AppStrings.ratingSubmitted);
    expect(cubit.state.feedback?.isError, isFalse);

    await cubit.submit();
    expect(ratings.rated, hasLength(1), reason: 'a stored rating cannot be sent again');
  });

  group('refused before sending', () {
    test('no stars: INVALID_STARS', () async {
      final cubit = open()..setLevelAccuracy(LevelAccuracy.higher);

      await cubit.submit();

      expect(cubit.state.feedback?.code, RatingErrorCodes.invalidStars);
      expect(cubit.state.feedback?.message, AppStrings.invalidStars);
      expect(ratings.rated, isEmpty);
    });

    test('no level answer: LEVEL_ACCURACY_REQUIRED', () async {
      final cubit = open()..setStars(5);

      await cubit.submit();

      expect(cubit.state.feedback?.code, RatingErrorCodes.levelAccuracyRequired);
      expect(cubit.state.feedback?.message, AppStrings.levelAccuracyRequired);
      expect(ratings.rated, isEmpty);
    });

    test('a note over 500 characters: NOTE_TOO_LONG', () async {
      final cubit = filled()..setNote('ا' * 501);

      await cubit.submit();

      expect(cubit.state.feedback?.code, RatingErrorCodes.noteTooLong);
      expect(cubit.state.feedback?.message, AppStrings.ratingNoteTooLong);
      expect(ratings.rated, isEmpty);
    });

    test('500 characters is allowed', () async {
      final cubit = filled()..setNote('ا' * 500);

      await cubit.submit();

      expect(cubit.state.done, isTrue);
    });
  });

  group("the server's refusals, in the app's words", () {
    const cases = {
      RatingErrorCodes.ratingNotAllowed: AppStrings.ratingNotAllowed,
      RatingErrorCodes.ratingWindowClosed: AppStrings.ratingWindowClosed,
      RatingErrorCodes.alreadyRated: AppStrings.alreadyRated,
      RatingErrorCodes.cannotRateSelf: AppStrings.cannotRateSelf,
      RatingErrorCodes.invalidStars: AppStrings.invalidStars,
      RatingErrorCodes.tooManyTags: AppStrings.tooManyTags,
      RatingErrorCodes.levelAccuracyRequired: AppStrings.levelAccuracyRequired,
      RatingErrorCodes.noteTooLong: AppStrings.ratingNoteTooLong,
      RatingErrorCodes.matchNotFound: AppStrings.matchNotAvailable,
    };
    for (final MapEntry(key: code, value: message) in cases.entries) {
      test(code, () async {
        ratings.failure = ServerFailure('server words', code: code, statusCode: 409);
        final cubit = filled();

        await cubit.submit();

        expect(cubit.state.done, isFalse);
        expect(cubit.state.submitting, isFalse);
        expect(cubit.state.feedback?.message, message);
        expect(cubit.state.feedback?.isError, isTrue);
        expect(cubit.state.feedback?.code, code);
      });
    }

    test("an unknown code keeps the server's words; offline says so", () async {
      ratings.failure = const ServerFailure('پیام سرور', code: 'SOMETHING_NEW');
      final cubit = filled();
      await cubit.submit();
      expect(cubit.state.feedback?.message, 'پیام سرور');

      ratings.failure = const NetworkFailure(AppStrings.offlineActionError);
      await cubit.submit();
      expect(cubit.state.feedback?.message, AppStrings.offlineActionError);
    });
  });
}
