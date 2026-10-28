import 'package:json_annotation/json_annotation.dart';

import '../../../../core/api/config/api_config.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../ratings/data/models/rating_models.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/entities/profile_enums.dart';

part 'profile_models.g.dart';

// The profile's wire shapes. Enums arrive as strings and are parsed by `toEntity`; a value this app does not know is
// dropped instead of failing the whole response.

/// `{id, name}`: a venue or home club.
@JsonSerializable(createToJson: false)
class NamedRefModel {
  const NamedRefModel({required this.id, required this.name});

  factory NamedRefModel.fromJson(Map<String, dynamic> json) => _$NamedRefModelFromJson(json);

  final String id;
  final String name;

  NamedRef toEntity() => NamedRef(id: id, name: name);
}

/// `{id, name}`: a city.
@JsonSerializable(createToJson: false)
class CityRefModel {
  const CityRefModel({required this.id, required this.name});

  factory CityRefModel.fromJson(Map<String, dynamic> json) => _$CityRefModelFromJson(json);

  final int id;
  final String name;

  CityRef toEntity() => CityRef(id: id, name: name);
}

/// `SportProfileView`.
@JsonSerializable(createToJson: false)
class SportProfileModel {
  const SportProfileModel({
    required this.sportId,
    required this.sportCode,
    required this.level,
    this.levelName = '',
    this.levelDescription,
    this.experience,
    this.formats = const [],
    this.goals = const [],
  });

  factory SportProfileModel.fromJson(Map<String, dynamic> json) => _$SportProfileModelFromJson(json);

  final String sportId;
  final String sportCode;
  final String level;
  final String levelName;
  final String? levelDescription;
  final String? experience;
  final List<String> formats;
  final List<String> goals;

  SportProfile toEntity() => SportProfile(
    sportId: sportId,
    sportCode: sportCode,
    level: LevelTier.tryParse(level),
    levelName: levelName,
    levelDescription: levelDescription,
    experience: ExperienceBand.tryParse(experience),
    formats: [for (final f in formats) ?PlayFormat.tryParse(f)],
    goals: [for (final g in goals) ?PlayGoal.tryParse(g)],
  );
}

/// `MyProfileView`.
@JsonSerializable(createToJson: false)
class MyProfileModel {
  const MyProfileModel({
    required this.userId,
    required this.displayName,
    required this.city,
    this.photoUrl,
    this.gender,
    this.birthDate,
    this.ageRange = '',
    this.bio,
    this.visibility,
    this.status,
    this.sports = const [],
    this.homeVenues = const [],
    this.reputation,
  });

  factory MyProfileModel.fromJson(Map<String, dynamic> json) => _$MyProfileModelFromJson(json);

  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? gender;
  final String? birthDate;
  final String ageRange;
  final CityRefModel city;
  final String? bio;
  final String? visibility;
  final String? status;
  final List<SportProfileModel> sports;
  final List<NamedRefModel> homeVenues;
  final ReputationModel? reputation;

  MyProfile toEntity() => MyProfile(
    userId: userId,
    displayName: displayName,
    photoUrl: absolutePhotoUrl(photoUrl),
    gender: Gender.tryParse(gender),
    birthDate: birthDate,
    ageRange: ageRange,
    city: city.toEntity(),
    bio: _blankToNull(bio),
    visibility: ProfileVisibility.tryParse(visibility) ?? ProfileVisibility.everyone,
    status: status,
    sports: [for (final s in sports) s.toEntity()],
    homeVenues: [for (final v in homeVenues) v.toEntity()],
    reputation: reputation?.toEntity(),
  );
}

/// `PlayerProfileView`.
@JsonSerializable(createToJson: false)
class PlayerProfileModel {
  const PlayerProfileModel({
    required this.userId,
    required this.displayName,
    required this.city,
    this.photoUrl,
    this.gender,
    this.ageRange = '',
    this.bio,
    this.sports = const [],
    this.homeVenues = const [],
    this.memberSince,
    this.lastActive,
    this.reputation,
  });

  factory PlayerProfileModel.fromJson(Map<String, dynamic> json) => _$PlayerProfileModelFromJson(json);

  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? gender;
  final String ageRange;
  final CityRefModel city;
  final String? bio;
  final List<SportProfileModel> sports;
  final List<NamedRefModel> homeVenues;
  final String? memberSince;
  final String? lastActive;
  final ReputationModel? reputation;

  PlayerProfile toEntity() => PlayerProfile(
    userId: userId,
    displayName: displayName,
    photoUrl: absolutePhotoUrl(photoUrl),
    gender: Gender.tryParse(gender),
    ageRange: ageRange,
    city: city.toEntity(),
    bio: _blankToNull(bio),
    sports: [for (final s in sports) s.toEntity()],
    homeVenues: [for (final v in homeVenues) v.toEntity()],
    memberSince: memberSince,
    lastActive: LastActive.tryParse(lastActive),
    reputation: reputation?.toEntity(),
  );
}

/// An item of `GET /blocks`.
@JsonSerializable(createToJson: false)
class BlockedPlayerModel {
  const BlockedPlayerModel({required this.userId, required this.displayName, this.blockedAt});

  factory BlockedPlayerModel.fromJson(Map<String, dynamic> json) => _$BlockedPlayerModelFromJson(json);

  final String userId;
  final String displayName;
  final String? blockedAt;

  BlockedPlayer toEntity() =>
      BlockedPlayer(userId: userId, displayName: displayName, blockedAt: DateTime.tryParse(blockedAt ?? ''));
}

/// `SportProfileInput`.
@JsonSerializable(createFactory: false)
class SportProfileInputModel {
  const SportProfileInputModel({
    required this.sportId,
    required this.level,
    required this.experience,
    required this.formats,
    required this.goals,
  });

  /// [draft] must be complete (`SportRules.validate` passed).
  factory SportProfileInputModel.fromDraft(SportProfileDraft draft) => SportProfileInputModel(
    sportId: draft.sportId,
    level: draft.level?.wire ?? '',
    experience: draft.experience?.wire ?? '',
    formats: [
      for (final f in PlayFormat.values)
        if (draft.formats.contains(f)) f.wire,
    ],
    goals: [
      for (final g in PlayGoal.values)
        if (draft.goals.contains(g)) g.wire,
    ],
  );

  final String sportId;
  final String level;
  final String experience;
  final List<String> formats;
  final List<String> goals;

  Map<String, dynamic> toJson() => _$SportProfileInputModelToJson(this);
}

/// `POST /profile`.
@JsonSerializable(createFactory: false, explicitToJson: true)
class CreateProfileRequest {
  const CreateProfileRequest({
    required this.displayName,
    required this.gender,
    required this.birthDate,
    required this.cityId,
    required this.sports,
    this.bio,
  });

  factory CreateProfileRequest.fromEntity(NewProfile profile) => CreateProfileRequest(
    displayName: profile.displayName,
    gender: profile.gender.wire,
    birthDate: profile.birthDate,
    cityId: profile.cityId,
    bio: profile.bio,
    sports: [for (final s in profile.sports) SportProfileInputModel.fromDraft(s)],
  );

  final String displayName;
  final String gender;
  final String birthDate;
  final int cityId;
  final String? bio;
  final List<SportProfileInputModel> sports;

  Map<String, dynamic> toJson() => _$CreateProfileRequestToJson(this);
}

/// `PUT /profile`.
@JsonSerializable(createFactory: false)
class UpdateProfileRequest {
  const UpdateProfileRequest({required this.displayName, required this.gender, required this.cityId, this.bio});

  final String displayName;
  final String gender;
  final int cityId;
  final String? bio;

  Map<String, dynamic> toJson() => _$UpdateProfileRequestToJson(this);
}

/// `PUT /profile/home-venues`.
@JsonSerializable(createFactory: false)
class HomeVenuesRequest {
  const HomeVenuesRequest({required this.venueIds});

  final List<String> venueIds;

  Map<String, dynamic> toJson() => _$HomeVenuesRequestToJson(this);
}

/// `PUT /profile/visibility`.
@JsonSerializable(createFactory: false)
class VisibilityRequest {
  const VisibilityRequest({required this.visibility});

  final String visibility;

  Map<String, dynamic> toJson() => _$VisibilityRequestToJson(this);
}

/// The server writes a photo as a path (`/media/avatars/x.jpg`); it is loaded from the API's origin. An absolute URL
/// is kept as it is.
String? absolutePhotoUrl(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${ApiConfig.baseUrl}${value.startsWith('/') ? '' : '/'}$value';
}

String? _blankToNull(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
