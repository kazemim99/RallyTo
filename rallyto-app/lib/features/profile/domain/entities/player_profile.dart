import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/sport.dart';
import '../../../ratings/domain/entities/rating.dart';
import 'profile_enums.dart';

/// An id and a Persian name: a venue, a home club.
class NamedRef extends Equatable {
  const NamedRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// The player's city.
class CityRef extends Equatable {
  const CityRef({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// How the player plays one sport, as the server returns it.
class SportProfile extends Equatable {
  const SportProfile({
    required this.sportId,
    required this.sportCode,
    required this.level,
    required this.levelName,
    this.levelDescription,
    this.experience,
    this.formats = const [],
    this.goals = const [],
  });

  final String sportId;
  final String sportCode;
  final LevelTier? level;

  /// The server's Persian name for [level] in this sport, e.g. «متوسط».
  final String levelName;
  final String? levelDescription;
  final ExperienceBand? experience;
  final List<PlayFormat> formats;
  final List<PlayGoal> goals;

  /// This profile as an editable draft.
  SportProfileDraft toDraft() => SportProfileDraft(
    sportId: sportId,
    level: level,
    experience: experience,
    formats: formats.toSet(),
    goals: goals.toSet(),
  );

  @override
  List<Object?> get props => [sportId, sportCode, level, levelName, levelDescription, experience, formats, goals];
}

/// One sport's profile as the player fills it in: during onboarding, or when adding or editing a sport. What is sent
/// as `SportProfileInput`.
class SportProfileDraft extends Equatable {
  const SportProfileDraft({
    required this.sportId,
    this.level,
    this.experience,
    this.formats = const {},
    this.goals = const {},
  });

  final String sportId;
  final LevelTier? level;
  final ExperienceBand? experience;
  final Set<PlayFormat> formats;
  final Set<PlayGoal> goals;

  SportProfileDraft copyWith({
    LevelTier? level,
    ExperienceBand? experience,
    Set<PlayFormat>? formats,
    Set<PlayGoal>? goals,
  }) => SportProfileDraft(
    sportId: sportId,
    level: level ?? this.level,
    experience: experience ?? this.experience,
    formats: formats ?? this.formats,
    goals: goals ?? this.goals,
  );

  @override
  List<Object?> get props => [sportId, level, experience, formats, goals];
}

/// The player's own profile: everything another player sees, plus the birth date and visibility.
class MyProfile extends Equatable {
  const MyProfile({
    required this.userId,
    required this.displayName,
    required this.gender,
    required this.ageRange,
    required this.city,
    required this.visibility,
    this.photoUrl,
    this.birthDate,
    this.bio,
    this.status,
    this.sports = const [],
    this.homeVenues = const [],
    this.reputation,
  });

  final String userId;
  final String displayName;

  /// Absolute, ready to load; null without a photo.
  final String? photoUrl;
  final Gender? gender;

  /// Jalali, as the API writes it: «1375/05/10».
  final String? birthDate;

  /// «25-34».
  final String ageRange;
  final CityRef city;
  final String? bio;
  final ProfileVisibility visibility;

  /// `Active`, `Hidden` or `Deleted`, as the server writes it.
  final String? status;
  final List<SportProfile> sports;
  final List<NamedRef> homeVenues;

  /// Public aggregates only; null from a server that does not send it.
  final Reputation? reputation;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    gender,
    birthDate,
    ageRange,
    city,
    bio,
    visibility,
    status,
    sports,
    homeVenues,
    reputation,
  ];
}

/// Another player's profile: no phone number and no birth date, only an age range.
class PlayerProfile extends Equatable {
  const PlayerProfile({
    required this.userId,
    required this.displayName,
    required this.ageRange,
    required this.city,
    this.photoUrl,
    this.gender,
    this.bio,
    this.sports = const [],
    this.homeVenues = const [],
    this.memberSince,
    this.lastActive,
    this.reputation,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final Gender? gender;
  final String ageRange;
  final CityRef city;
  final String? bio;
  final List<SportProfile> sports;
  final List<NamedRef> homeVenues;

  /// Jalali year and month, «1405/08».
  final String? memberSince;
  final LastActive? lastActive;

  /// Public aggregates only; null from a server that does not send it.
  final Reputation? reputation;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    gender,
    ageRange,
    city,
    bio,
    sports,
    homeVenues,
    memberSince,
    lastActive,
    reputation,
  ];
}

/// A player this player blocked.
class BlockedPlayer extends Equatable {
  const BlockedPlayer({required this.userId, required this.displayName, required this.blockedAt});

  final String userId;
  final String displayName;
  final DateTime? blockedAt;

  @override
  List<Object?> get props => [userId, displayName, blockedAt];
}

/// What onboarding sends to create the profile.
class NewProfile extends Equatable {
  const NewProfile({
    required this.displayName,
    required this.gender,
    required this.birthDate,
    required this.cityId,
    required this.sports,
    this.bio,
  });

  final String displayName;
  final Gender gender;

  /// Jalali, «1375/05/10».
  final String birthDate;
  final int cityId;
  final String? bio;
  final List<SportProfileDraft> sports;

  @override
  List<Object?> get props => [displayName, gender, birthDate, cityId, bio, sports];
}

/// A photo picked for the profile, already downscaled on the device.
class ProfilePhoto extends Equatable {
  const ProfilePhoto({required this.bytes, required this.fileName, this.contentType});

  final List<int> bytes;
  final String fileName;

  /// `image/jpeg`, `image/png` or `image/webp`; worked out from [fileName] when null.
  final String? contentType;

  @override
  List<Object?> get props => [bytes.length, fileName, contentType];
}
