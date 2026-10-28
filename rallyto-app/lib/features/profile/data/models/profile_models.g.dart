// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NamedRefModel _$NamedRefModelFromJson(Map<String, dynamic> json) =>
    NamedRefModel(id: json['id'] as String, name: json['name'] as String);

CityRefModel _$CityRefModelFromJson(Map<String, dynamic> json) =>
    CityRefModel(id: (json['id'] as num).toInt(), name: json['name'] as String);

SportProfileModel _$SportProfileModelFromJson(Map<String, dynamic> json) => SportProfileModel(
  sportId: json['sportId'] as String,
  sportCode: json['sportCode'] as String,
  level: json['level'] as String,
  levelName: json['levelName'] as String? ?? '',
  levelDescription: json['levelDescription'] as String?,
  experience: json['experience'] as String?,
  formats: (json['formats'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  goals: (json['goals'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);

MyProfileModel _$MyProfileModelFromJson(Map<String, dynamic> json) => MyProfileModel(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String,
  city: CityRefModel.fromJson(json['city'] as Map<String, dynamic>),
  photoUrl: json['photoUrl'] as String?,
  gender: json['gender'] as String?,
  birthDate: json['birthDate'] as String?,
  ageRange: json['ageRange'] as String? ?? '',
  bio: json['bio'] as String?,
  visibility: json['visibility'] as String?,
  status: json['status'] as String?,
  sports:
      (json['sports'] as List<dynamic>?)?.map((e) => SportProfileModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  homeVenues:
      (json['homeVenues'] as List<dynamic>?)?.map((e) => NamedRefModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  reputation: json['reputation'] == null ? null : ReputationModel.fromJson(json['reputation'] as Map<String, dynamic>),
);

PlayerProfileModel _$PlayerProfileModelFromJson(Map<String, dynamic> json) => PlayerProfileModel(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String,
  city: CityRefModel.fromJson(json['city'] as Map<String, dynamic>),
  photoUrl: json['photoUrl'] as String?,
  gender: json['gender'] as String?,
  ageRange: json['ageRange'] as String? ?? '',
  bio: json['bio'] as String?,
  sports:
      (json['sports'] as List<dynamic>?)?.map((e) => SportProfileModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  homeVenues:
      (json['homeVenues'] as List<dynamic>?)?.map((e) => NamedRefModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  memberSince: json['memberSince'] as String?,
  lastActive: json['lastActive'] as String?,
  reputation: json['reputation'] == null ? null : ReputationModel.fromJson(json['reputation'] as Map<String, dynamic>),
);

BlockedPlayerModel _$BlockedPlayerModelFromJson(Map<String, dynamic> json) => BlockedPlayerModel(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String,
  blockedAt: json['blockedAt'] as String?,
);

Map<String, dynamic> _$SportProfileInputModelToJson(SportProfileInputModel instance) => <String, dynamic>{
  'sportId': instance.sportId,
  'level': instance.level,
  'experience': instance.experience,
  'formats': instance.formats,
  'goals': instance.goals,
};

Map<String, dynamic> _$CreateProfileRequestToJson(CreateProfileRequest instance) => <String, dynamic>{
  'displayName': instance.displayName,
  'gender': instance.gender,
  'birthDate': instance.birthDate,
  'cityId': instance.cityId,
  'bio': instance.bio,
  'sports': instance.sports.map((e) => e.toJson()).toList(),
};

Map<String, dynamic> _$UpdateProfileRequestToJson(UpdateProfileRequest instance) => <String, dynamic>{
  'displayName': instance.displayName,
  'gender': instance.gender,
  'cityId': instance.cityId,
  'bio': instance.bio,
};

Map<String, dynamic> _$HomeVenuesRequestToJson(HomeVenuesRequest instance) => <String, dynamic>{
  'venueIds': instance.venueIds,
};

Map<String, dynamic> _$VisibilityRequestToJson(VisibilityRequest instance) => <String, dynamic>{
  'visibility': instance.visibility,
};
