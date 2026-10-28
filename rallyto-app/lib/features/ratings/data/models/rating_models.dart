import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/rating.dart';

part 'rating_models.g.dart';

/// `RatingRequest`. Enums go as strings.
@JsonSerializable(createFactory: false, includeIfNull: false)
class RatingInputModel {
  const RatingInputModel({
    required this.rateeId,
    required this.stars,
    required this.tags,
    this.levelAccuracy,
    this.privateNote,
  });

  factory RatingInputModel.fromDraft(RatingDraft draft) {
    final note = draft.privateNote?.trim();
    return RatingInputModel(
      rateeId: draft.rateeId,
      stars: draft.stars,
      tags: [for (final tag in draft.tags.toSet()) tag.wire],
      levelAccuracy: draft.levelAccuracy?.wire,
      privateNote: note == null || note.isEmpty ? null : note,
    );
  }

  final String rateeId;
  final int stars;
  final List<String> tags;
  final String? levelAccuracy;
  final String? privateNote;

  Map<String, dynamic> toJson() => _$RatingInputModelToJson(this);
}

/// `RatingReceiptView`.
@JsonSerializable(createToJson: false)
class RatingReceiptModel {
  const RatingReceiptModel({required this.id});

  factory RatingReceiptModel.fromJson(Map<String, dynamic> json) => _$RatingReceiptModelFromJson(json);

  final String id;
}

/// `SportReputationView`. A tag this app does not know is dropped.
@JsonSerializable(createToJson: false)
class SportReputationModel {
  const SportReputationModel({
    required this.sportId,
    this.isNew = true,
    this.starAverage,
    this.ratingCount = 0,
    this.topTags = const [],
    this.levelStatement,
  });

  factory SportReputationModel.fromJson(Map<String, dynamic> json) => _$SportReputationModelFromJson(json);

  final String sportId;
  final bool isNew;
  final double? starAverage;
  final int ratingCount;
  final List<String> topTags;
  final String? levelStatement;

  SportReputation toEntity() => SportReputation(
    sportId: sportId,
    isNew: isNew || starAverage == null,
    starAverage: starAverage,
    ratingCount: ratingCount,
    topTags: [for (final t in topTags) ?RatingTag.tryParse(t)],
    levelStatement: LevelAccuracy.tryParse(levelStatement),
  );
}

/// `ReputationView`, on `PlayerProfileView` and `MyProfileView`.
@JsonSerializable(createToJson: false)
class ReputationModel {
  const ReputationModel({this.reliability, this.sports = const []});

  factory ReputationModel.fromJson(Map<String, dynamic> json) => _$ReputationModelFromJson(json);

  final String? reliability;
  final List<SportReputationModel> sports;

  Reputation toEntity() =>
      Reputation(reliability: ReliabilityTier.tryParse(reliability), sports: [for (final s in sports) s.toEntity()]);
}
