import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/profile/data/models/profile_models.dart';
import 'package:rallyto_app/features/ratings/data/models/rating_models.dart';
import 'package:rallyto_app/features/ratings/data/rating_api.dart';
import 'package:rallyto_app/features/ratings/data/rating_repository_impl.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';

import '../../../helpers/fake_server.dart';

/// Ratings over the real client stack, against the backend's contract (MatchesController.Rate, RatingRequest,
/// RatingReceiptView, ReputationView; AttendanceAndRatingTests, RatingApi): string enums, 201 with `{id}`, the
/// server's codes.
void main() {
  late FakeServer server;
  late RatingRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = RatingRepositoryImpl(RatingApi(server.dio()));
  });

  test('a rating posts the ratee, stars, tags, level accuracy and the trimmed note; 201 answers with its id', () async {
    server.routes['POST /api/v1/matches/m-1/ratings'] = (_) => okBody({'id': 'r-1'}, status: 201);

    final result = await repository.rate(
      'm-1',
      const RatingDraft(
        rateeId: 'u-2',
        stars: 4,
        tags: [RatingTag.onTime, RatingTag.goodRally],
        levelAccuracy: LevelAccuracy.aboutRight,
        privateNote: '  دیر رسید ولی خوب بود ',
      ),
    );

    expect(result, const Right<Failure, String>('r-1'));
    expect(server.lastJson, {
      'rateeId': 'u-2',
      'stars': 4,
      'tags': ['OnTime', 'GoodRally'],
      'levelAccuracy': 'AboutRight',
      'privateNote': 'دیر رسید ولی خوب بود',
    });
  });

  test('a blank note is left out', () async {
    server.routes['POST /api/v1/matches/m-1/ratings'] = (_) => okBody({'id': 'r-1'}, status: 201);

    await repository.rate(
      'm-1',
      const RatingDraft(rateeId: 'u-2', stars: 5, levelAccuracy: LevelAccuracy.higher, privateNote: '   '),
    );

    expect(server.lastJson, {'rateeId': 'u-2', 'stars': 5, 'tags': <String>[], 'levelAccuracy': 'Higher'});
  });

  test('every rating refusal keeps its code', () async {
    for (final (status, code) in [
      (409, 'RATING_NOT_ALLOWED'),
      (409, 'RATING_WINDOW_CLOSED'),
      (409, 'ALREADY_RATED'),
      (422, 'CANNOT_RATE_SELF'),
      (422, 'INVALID_STARS'),
      (422, 'TOO_MANY_TAGS'),
      (422, 'LEVEL_ACCURACY_REQUIRED'),
      (422, 'NOTE_TOO_LONG'),
      (404, 'MATCH_NOT_FOUND'),
    ]) {
      server.routes['POST /api/v1/matches/m-1/ratings'] = (_) => errorBody(status, code, 'x');
      final failure = (await repository.rate(
        'm-1',
        const RatingDraft(rateeId: 'u-2', stars: 4, levelAccuracy: LevelAccuracy.aboutRight),
      )).fold((f) => f, (_) => fail('expected a refusal'));
      expect(failure.code, code);
    }
  });

  group('reputation on a profile', () {
    test('reads the tier and each sport: average, count, top tags and the level statement', () {
      final reputation = ReputationModel.fromJson({
        'reliability': 'High',
        'sports': [
          {
            'sportId': 's-tennis',
            'isNew': false,
            'starAverage': 4.333,
            'ratingCount': 3,
            'topTags': ['OnTime', 'GoodRally', 'SomethingNew'],
            'levelStatement': 'Higher',
          },
          {
            'sportId': 's-padel',
            'isNew': true,
            'starAverage': null,
            'ratingCount': 2,
            'topTags': <String>[],
            'levelStatement': null,
          },
        ],
      }).toEntity();

      expect(reputation.reliability, ReliabilityTier.high);
      expect(
        reputation.forSport('s-tennis'),
        const SportReputation(
          sportId: 's-tennis',
          isNew: false,
          starAverage: 4.333,
          ratingCount: 3,
          topTags: [RatingTag.onTime, RatingTag.goodRally],
          levelStatement: LevelAccuracy.higher,
        ),
        reason: 'a tag this app does not know is dropped',
      );
      expect(reputation.forSport('s-padel')?.isNew, isTrue);
      expect(reputation.forSport('s-squash'), isNull);
    });

    test('a whole-number average arrives as an int; an unknown tier is no badge', () {
      final reputation = ReputationModel.fromJson({
        'reliability': 'Unknown',
        'sports': [
          {'sportId': 's-tennis', 'isNew': false, 'starAverage': 4, 'ratingCount': 5, 'topTags': <String>[]},
        ],
      }).toEntity();

      expect(reputation.reliability, isNull);
      expect(reputation.sports.single.starAverage, 4.0);
    });

    test('PlayerProfileView and MyProfileView carry it', () {
      const base = {
        'userId': 'u-2',
        'displayName': 'علی',
        'city': {'id': 1, 'name': 'تهران'},
        'sports': <Object>[],
        'homeVenues': <Object>[],
      };
      const reputation = {
        'reliability': 'New',
        'sports': [
          {'sportId': 's-tennis', 'isNew': true, 'ratingCount': 0, 'topTags': <String>[]},
        ],
      };

      final player = PlayerProfileModel.fromJson({...base, 'reputation': reputation}).toEntity();
      final mine = MyProfileModel.fromJson({...base, 'reputation': reputation}).toEntity();
      final older = PlayerProfileModel.fromJson(base).toEntity();

      expect(player.reputation?.reliability, ReliabilityTier.newPlayer);
      expect(mine.reputation?.forSport('s-tennis')?.isNew, isTrue);
      expect(older.reputation, isNull);
    });
  });
}
