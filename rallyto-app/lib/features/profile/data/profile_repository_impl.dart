import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/player_profile.dart';
import '../domain/entities/profile_enums.dart';
import '../domain/profile_repository.dart';
import 'models/profile_models.dart';
import 'profile_api.dart';

/// [ProfileRepository] over [ProfileApi]. Nothing is cached: a profile changes with every edit, and each edit
/// answers with the whole updated profile.
@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ProfileApi _api;

  @override
  Future<Either<Failure, MyProfile>> createProfile(NewProfile profile) =>
      _profile(() => _api.createProfile(CreateProfileRequest.fromEntity(profile)));

  @override
  Future<Either<Failure, MyProfile>> getMyProfile() => _profile(_api.me);

  @override
  Future<Either<Failure, MyProfile>> updateProfile({
    required String displayName,
    required Gender gender,
    required int cityId,
    String? bio,
  }) => _profile(
    () => _api.updateProfile(
      UpdateProfileRequest(displayName: displayName.trim(), gender: gender.wire, cityId: cityId, bio: _trimmed(bio)),
    ),
  );

  @override
  Future<Either<Failure, MyProfile>> setSportProfile(SportProfileDraft sport) =>
      _profile(() => _api.setSport(sport.sportId, SportProfileInputModel.fromDraft(sport)));

  @override
  Future<Either<Failure, MyProfile>> removeSportProfile(String sportId) => _profile(() => _api.removeSport(sportId));

  @override
  Future<Either<Failure, MyProfile>> setHomeVenues(List<String> venueIds) =>
      _profile(() => _api.setHomeVenues(HomeVenuesRequest(venueIds: venueIds)));

  @override
  Future<Either<Failure, MyProfile>> setVisibility(ProfileVisibility visibility) =>
      _profile(() => _api.setVisibility(VisibilityRequest(visibility: visibility.wire)));

  @override
  Future<Either<Failure, MyProfile>> uploadPhoto(ProfilePhoto photo) => _profile(
    () => _api.uploadPhoto(
      MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.fileName,
        contentType: DioMediaType.parse(photo.contentType ?? contentTypeFor(photo.fileName)),
      ),
    ),
  );

  @override
  Future<Either<Failure, MyProfile>> removePhoto() => _profile(_api.removePhoto);

  @override
  Future<Either<Failure, PlayerProfile>> getPlayer(String userId) async {
    final result = await safeApiCall(() => _api.player(userId));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, List<BlockedPlayer>>> getBlockedPlayers() async {
    final result = await safeApiCall(_api.blocks);
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  @override
  Future<Either<Failure, Unit>> blockPlayer(String userId) => safeNoContentCall(() => _api.block(userId));

  @override
  Future<Either<Failure, Unit>> unblockPlayer(String userId) => safeNoContentCall(() => _api.unblock(userId));

  Future<Either<Failure, MyProfile>> _profile(Future<ApiResponse<MyProfileModel>> Function() request) async {
    final result = await safeApiCall(request);
    return result.map((model) => model.toEntity());
  }

  /// The photo's media type from its file name; jpeg unless it says png or webp (the picker writes jpeg).
  static String contentTypeFor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String? _trimmed(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
