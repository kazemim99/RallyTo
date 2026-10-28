// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$RatingInputModelToJson(RatingInputModel instance) => <String, dynamic>{
  'rateeId': instance.rateeId,
  'stars': instance.stars,
  'tags': instance.tags,
  'levelAccuracy': ?instance.levelAccuracy,
  'privateNote': ?instance.privateNote,
};

RatingReceiptModel _$RatingReceiptModelFromJson(Map<String, dynamic> json) =>
    RatingReceiptModel(id: json['id'] as String);

SportReputationModel _$SportReputationModelFromJson(Map<String, dynamic> json) => SportReputationModel(
  sportId: json['sportId'] as String,
  isNew: json['isNew'] as bool? ?? true,
  starAverage: (json['starAverage'] as num?)?.toDouble(),
  ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
  topTags: (json['topTags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  levelStatement: json['levelStatement'] as String?,
);

ReputationModel _$ReputationModelFromJson(Map<String, dynamic> json) => ReputationModel(
  reliability: json['reliability'] as String?,
  sports:
      (json['sports'] as List<dynamic>?)
          ?.map((e) => SportReputationModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
