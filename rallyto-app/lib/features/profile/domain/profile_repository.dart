import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/player_profile.dart';
import 'entities/profile_enums.dart';

/// The server's `error.code`s the profile screens react to.
class ProfileErrorCodes {
  ProfileErrorCodes._();

  static const String under18 = 'UNDER_18';
  static const String invalidDisplayName = 'INVALID_DISPLAY_NAME';
  static const String invalidBirthDate = 'INVALID_BIRTH_DATE';
  static const String formatNotAllowed = 'FORMAT_NOT_ALLOWED';
  static const String formatRequired = 'FORMAT_REQUIRED';
  static const String goalRequired = 'GOAL_REQUIRED';
  static const String sportProfileRequired = 'SPORT_PROFILE_REQUIRED';
  static const String unknownCity = 'UNKNOWN_CITY';
  static const String profileExists = 'PROFILE_EXISTS';
  static const String profileRequired = 'PROFILE_REQUIRED';
  static const String bioTooLong = 'BIO_TOO_LONG';
  static const String genderLocked = 'GENDER_LOCKED';
  static const String lastSportProfile = 'LAST_SPORT_PROFILE';
  static const String tooManyHomeVenues = 'TOO_MANY_HOME_VENUES';
  static const String photoTooLarge = 'PHOTO_TOO_LARGE';
  static const String photoTypeNotAllowed = 'PHOTO_TYPE_NOT_ALLOWED';
  static const String photoInvalid = 'PHOTO_INVALID';
  static const String playerNotFound = 'PLAYER_NOT_FOUND';
}

/// The player's own profile, other players' profiles, and blocks. Nothing is cached: every call asks the server, and
/// every change answers with the whole updated profile.
abstract class ProfileRepository {
  /// Creates the profile (onboarding). 201 with the profile; `UNDER_18`, `INVALID_DISPLAY_NAME`, … otherwise.
  Future<Either<Failure, MyProfile>> createProfile(NewProfile profile);

  Future<Either<Failure, MyProfile>> getMyProfile();

  /// Name, city and bio. [gender] must be the current one: it cannot change (`GENDER_LOCKED`).
  Future<Either<Failure, MyProfile>> updateProfile({
    required String displayName,
    required Gender gender,
    required int cityId,
    String? bio,
  });

  /// Adds the sport, or replaces its profile.
  Future<Either<Failure, MyProfile>> setSportProfile(SportProfileDraft sport);

  /// 409 `LAST_SPORT_PROFILE` for the only one left.
  Future<Either<Failure, MyProfile>> removeSportProfile(String sportId);

  /// At most 5 (`TOO_MANY_HOME_VENUES`); an empty list clears them.
  Future<Either<Failure, MyProfile>> setHomeVenues(List<String> venueIds);

  Future<Either<Failure, MyProfile>> setVisibility(ProfileVisibility visibility);

  /// jpeg, png or webp, at most 5 MB.
  Future<Either<Failure, MyProfile>> uploadPhoto(ProfilePhoto photo);

  Future<Either<Failure, MyProfile>> removePhoto();

  /// Another player's profile; a `NotFoundFailure` when they blocked this player, are hidden, or do not exist (the
  /// server answers all three alike).
  Future<Either<Failure, PlayerProfile>> getPlayer(String userId);

  Future<Either<Failure, List<BlockedPlayer>>> getBlockedPlayers();

  Future<Either<Failure, Unit>> blockPlayer(String userId);

  Future<Either<Failure, Unit>> unblockPlayer(String userId);
}
