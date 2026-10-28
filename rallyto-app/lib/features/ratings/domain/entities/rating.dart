import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile_enums.dart';

/// The fixed tags a rating may carry, at most three (spec player-ratings › Rating content).
enum RatingTag {
  onTime('OnTime'),
  friendly('Friendly'),
  fairCalls('FairCalls'),
  goodRally('GoodRally'),
  sportsmanship('Sportsmanship'),
  wellOrganised('WellOrganised');

  const RatingTag(this.wire);

  final String wire;

  static RatingTag? tryParse(String? value) => parseWire(values, value, (t) => t.wire);
}

/// How the ratee played against the level they declared for the game's sport.
enum LevelAccuracy {
  lower('Lower'),
  aboutRight('AboutRight'),
  higher('Higher');

  const LevelAccuracy(this.wire);

  final String wire;

  static LevelAccuracy? tryParse(String? value) => parseWire(values, value, (l) => l.wire);
}

/// One reliability tier across all sports, from the last 20 commitments. The score behind it is never shown.
enum ReliabilityTier {
  newPlayer('New'),
  low('Low'),
  good('Good'),
  high('High');

  const ReliabilityTier(this.wire);

  final String wire;

  static ReliabilityTier? tryParse(String? value) => parseWire(values, value, (r) => r.wire);
}

/// Who a rating form is for: [rateeId] in game [matchId]. [rateeName] is shown when known.
class RatingTarget extends Equatable {
  const RatingTarget({required this.matchId, required this.rateeId, this.rateeName});

  final String matchId;
  final String rateeId;
  final String? rateeName;

  @override
  List<Object?> get props => [matchId, rateeId, rateeName];
}

/// A rating as the player fills it in, sent as `RatingRequest`. Final once sent.
class RatingDraft extends Equatable {
  const RatingDraft({
    required this.rateeId,
    required this.stars,
    this.tags = const [],
    this.levelAccuracy,
    this.privateNote,
  });

  final String rateeId;

  /// 1 to 5.
  final int stars;

  /// At most 3, in the order picked.
  final List<RatingTag> tags;

  /// Required.
  final LevelAccuracy? levelAccuracy;

  /// Seen only by admins; up to 500 characters.
  final String? privateNote;

  @override
  List<Object?> get props => [rateeId, stars, tags, levelAccuracy, privateNote];
}

/// A player's public reputation in one sport, from revealed ratings only.
class SportReputation extends Equatable {
  const SportReputation({
    required this.sportId,
    required this.isNew,
    required this.ratingCount,
    this.starAverage,
    this.topTags = const [],
    this.levelStatement,
  });

  final String sportId;

  /// Fewer than 3 revealed ratings: shown as «بازیکن جدید», with no average.
  final bool isNew;
  final double? starAverage;
  final int ratingCount;

  /// The 3 most frequent tags.
  final List<RatingTag> topTags;

  /// What most partners (60% or more) say about the declared level; null when there is no majority.
  final LevelAccuracy? levelStatement;

  @override
  List<Object?> get props => [sportId, isNew, starAverage, ratingCount, topTags, levelStatement];
}

/// A player's public reputation (`ReputationView`): never individual ratings or their authors.
class Reputation extends Equatable {
  const Reputation({this.reliability, this.sports = const []});

  /// Null for a tier this app does not know.
  final ReliabilityTier? reliability;
  final List<SportReputation> sports;

  /// The summary for [sportId], or null when there is none.
  SportReputation? forSport(String sportId) {
    for (final sport in sports) {
      if (sport.sportId == sportId) return sport;
    }
    return null;
  }

  @override
  List<Object?> get props => [reliability, sports];
}
