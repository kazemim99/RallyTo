import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../onboarding/presentation/bloc/onboarding_cubit.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/entities/profile_enums.dart';
import '../../domain/profile_repository.dart';
import '../../domain/sport_rules.dart';

/// The player's own profile: shown, and edited one part at a time (name/city/bio, a sport, home clubs, visibility,
/// photo). Each edit answers with the whole updated profile, which replaces the one shown. Every edit ends in
/// feedback: [MyProfileState.feedback] changes, and the screen shows it.
@injectable
class MyProfileCubit extends Cubit<MyProfileState> {
  MyProfileCubit(this._profiles, this._catalog) : super(const MyProfileState());

  final ProfileRepository _profiles;
  final CatalogRepository _catalog;

  /// The longest bio the server takes.
  static const int maxBioLength = 300;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final sports = _catalog.getSports();
    final result = await _profiles.getMyProfile();
    // Sports only name and describe: without them a sport shows its code and cannot be edited.
    final catalog = (await sports).fold((_) => const <Sport>[], (s) => s);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: ViewStatus.error, errorMessage: failure.message)),
      (profile) => emit(state.copyWith(status: ViewStatus.content, profile: profile, sports: catalog)),
    );
  }

  /// Saves name, city and bio. The message for what is wrong with them, or null once saved.
  Future<String?> updateBasics({required String displayName, required int cityId, String? bio}) async {
    final profile = state.profile;
    final gender = profile?.gender;
    if (profile == null || gender == null) return AppStrings.genericError;
    final nameError = OnboardingCubit.validateDisplayName(displayName);
    if (nameError != null) return nameError;
    if ((bio?.trim().length ?? 0) > maxBioLength) return AppStrings.bioTooLong;
    final failure = await _run(
      () => _profiles.updateProfile(displayName: displayName, gender: gender, cityId: cityId, bio: bio),
    );
    return failure?.message;
  }

  /// Adds or replaces a sport's profile. The message for what is missing, or null once saved.
  Future<String?> saveSport(SportProfileDraft draft) async {
    final sport = sportById(draft.sportId);
    if (sport == null) return AppStrings.genericError;
    final error = SportRules.validate(draft, sport);
    if (error != null) return error;
    final failure = await _run(() => _profiles.setSportProfile(draft));
    return failure?.message;
  }

  /// Removes a sport. The server refuses the last one (`LAST_SPORT_PROFILE`); that is said as feedback.
  Future<void> removeSport(String sportId) async {
    await _run(() => _profiles.removeSportProfile(sportId), fallbackMessages: _lastSportFallback);
  }

  Future<void> setHomeVenues(List<Venue> venues) async {
    await _run(() => _profiles.setHomeVenues([for (final v in venues) v.id]));
  }

  Future<void> setSameGenderOnly(bool sameGenderOnly) async {
    await _run(
      () => _profiles.setVisibility(sameGenderOnly ? ProfileVisibility.sameGender : ProfileVisibility.everyone),
    );
  }

  Future<void> uploadPhoto(ProfilePhoto photo) async {
    await _run(() => _profiles.uploadPhoto(photo));
  }

  Future<void> removePhoto() async {
    await _run(_profiles.removePhoto);
  }

  /// The catalog sport with [id], or null when it is not loaded.
  Sport? sportById(String id) {
    for (final sport in state.sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  static const Map<String, String> _lastSportFallback = {
    ProfileErrorCodes.lastSportProfile: AppStrings.lastSportProfile,
  };

  /// Runs an edit; on success shows the updated profile and says «saved». Returns the failure, if any, after
  /// reporting it as feedback.
  Future<Failure?> _run(
    Future<Either<Failure, MyProfile>> Function() edit, {
    Map<String, String> fallbackMessages = const {},
  }) async {
    // One edit at a time: a second tap while one is out is not sent.
    if (state.busy) return const ServerFailure(AppStrings.genericError);
    emit(state.copyWith(busy: true));
    final result = await edit();
    if (isClosed) return const ServerFailure(AppStrings.genericError);
    return result.fold(
      (failure) {
        final message = failure.message.isNotEmpty ? failure.message : (fallbackMessages[failure.code] ?? '');
        emit(
          state.copyWith(
            busy: false,
            feedback: ProfileFeedback(
              message.isEmpty ? AppStrings.genericError : message,
              isError: true,
              code: failure.code,
            ),
          ),
        );
        return failure;
      },
      (profile) {
        emit(state.copyWith(busy: false, profile: profile, feedback: const ProfileFeedback(AppStrings.saved)));
        return null;
      },
    );
  }
}

/// A message for the player after an edit. A new instance each time (compared by identity), so the same message
/// twice is shown twice.
class ProfileFeedback {
  const ProfileFeedback(this.message, {this.isError = false, this.code});

  final String message;
  final bool isError;

  /// The server's error code, when it refused.
  final String? code;
}

class MyProfileState extends Equatable {
  const MyProfileState({
    this.status = ViewStatus.loading,
    this.profile,
    this.sports = const [],
    this.busy = false,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;
  final MyProfile? profile;

  /// The catalog's sports: names, levels and formats for the editors.
  final List<Sport> sports;

  /// An edit is on its way; another is not started until it answers.
  final bool busy;

  /// Why the profile could not be loaded.
  final String? errorMessage;

  /// The latest edit's outcome.
  final ProfileFeedback? feedback;

  /// Persian names by sport code.
  Map<String, String> get sportNames => {for (final s in sports) s.code: s.nameFa};

  /// Catalog sports not yet in the profile.
  List<Sport> get addableSports {
    final have = {for (final s in profile?.sports ?? const <SportProfile>[]) s.sportId};
    return [
      for (final s in sports)
        if (s.isActive && !have.contains(s.id)) s,
    ];
  }

  MyProfileState copyWith({
    ViewStatus? status,
    MyProfile? profile,
    List<Sport>? sports,
    bool? busy,
    String? errorMessage,
    ProfileFeedback? feedback,
  }) => MyProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    sports: sports ?? this.sports,
    busy: busy ?? this.busy,
    errorMessage: errorMessage ?? this.errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, profile, sports, busy, errorMessage, feedback];
}
