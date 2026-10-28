import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/domain/rating_repository.dart';

/// A [RatingRepository] answering from what the test set, recording what it was asked.
class FakeRatingRepository implements RatingRepository {
  /// When set, the next rating answers with it instead of succeeding.
  Failure? failure;

  final List<(String matchId, RatingDraft draft)> rated = [];

  @override
  Future<Either<Failure, String>> rate(String matchId, RatingDraft draft) async {
    rated.add((matchId, draft));
    final failure = this.failure;
    return failure == null ? const Right('r-1') : Left(failure);
  }
}

/// A tennis reputation from 3 revealed ratings: 4.3 stars, two tags, «about right»; reliability Good.
Reputation testReputation({
  ReliabilityTier? reliability = ReliabilityTier.good,
  bool isNew = false,
  String sportId = 's-tennis',
}) => Reputation(
  reliability: reliability,
  sports: [
    SportReputation(
      sportId: sportId,
      isNew: isNew,
      starAverage: isNew ? null : 4.333,
      ratingCount: isNew ? 2 : 3,
      topTags: isNew ? const [] : const [RatingTag.onTime, RatingTag.goodRally],
      levelStatement: isNew ? null : LevelAccuracy.aboutRight,
    ),
  ],
);
