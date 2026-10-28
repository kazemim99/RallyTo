// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchingWindowModel _$MatchingWindowModelFromJson(Map<String, dynamic> json) => MatchingWindowModel(
  availabilityId: json['availabilityId'] as String,
  startTime: json['startTime'] as String,
  endTime: json['endTime'] as String,
  overlapStart: json['overlapStart'] as String,
  overlapEnd: json['overlapEnd'] as String,
  venues:
      (json['venues'] as List<dynamic>?)?.map((e) => NamedRefModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  weekdays: (json['weekdays'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  date: json['date'] as String?,
  formats: (json['formats'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);

PartnerResultModel _$PartnerResultModelFromJson(Map<String, dynamic> json) => PartnerResultModel(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String? ?? '',
  photoUrl: json['photoUrl'] as String?,
  gender: json['gender'] as String?,
  ageRange: json['ageRange'] as String? ?? '',
  level: json['level'] as String?,
  levelName: json['levelName'] as String? ?? '',
  experience: json['experience'] as String?,
  lastActive: json['lastActive'] as String?,
  windows:
      (json['windows'] as List<dynamic>?)
          ?.map((e) => MatchingWindowModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  reliability: json['reliability'] as String?,
  ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
  ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
);

SearchResultsModel _$SearchResultsModelFromJson(Map<String, dynamic> json) => SearchResultsModel(
  players:
      (json['players'] as List<dynamic>?)
          ?.map((e) => PartnerResultModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  posts:
      (json['posts'] as List<dynamic>?)?.map((e) => MatchViewModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  nextCursor: json['nextCursor'] as String?,
);

SearchCriteriaModel _$SearchCriteriaModelFromJson(Map<String, dynamic> json) => SearchCriteriaModel(
  sportId: json['sportId'] as String,
  cityId: (json['cityId'] as num?)?.toInt(),
  venueIds: (json['venueIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  date: json['date'] as String?,
  weekdays: (json['weekdays'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  from: json['from'] as String?,
  to: json['to'] as String?,
  minLevel: json['minLevel'] as String?,
  maxLevel: json['maxLevel'] as String?,
  gender: json['gender'] as String?,
  format: json['format'] as String?,
);

SavedSearchModel _$SavedSearchModelFromJson(Map<String, dynamic> json) => SavedSearchModel(
  id: json['id'] as String,
  criteria: SearchCriteriaModel.fromJson(json['criteria'] as Map<String, dynamic>),
  name: json['name'] as String? ?? '',
  alertsEnabled: json['alertsEnabled'] as bool? ?? false,
  alertsSent: (json['alertsSent'] as num?)?.toInt() ?? 0,
  pendingMatches: (json['pendingMatches'] as num?)?.toInt() ?? 0,
  lastAlertAt: json['lastAlertAt'] as String?,
  expiresOn: json['expiresOn'] as String?,
  city: json['city'] == null ? null : CityRefModel.fromJson(json['city'] as Map<String, dynamic>),
  venues:
      (json['venues'] as List<dynamic>?)?.map((e) => NamedRefModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
);

Map<String, dynamic> _$SearchCriteriaInputModelToJson(SearchCriteriaInputModel instance) => <String, dynamic>{
  'sportId': instance.sportId,
  'cityId': ?instance.cityId,
  'venueIds': ?instance.venueIds,
  'date': ?instance.date,
  'weekdays': ?instance.weekdays,
  'from': ?instance.from,
  'to': ?instance.to,
  'minLevel': ?instance.minLevel,
  'maxLevel': ?instance.maxLevel,
  'gender': ?instance.gender,
  'format': ?instance.format,
};

Map<String, dynamic> _$SavedSearchRequestModelToJson(SavedSearchRequestModel instance) => <String, dynamic>{
  'name': instance.name,
  'alertsEnabled': instance.alertsEnabled,
  'criteria': instance.criteria.toJson(),
};
