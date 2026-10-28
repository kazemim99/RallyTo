import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/place.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../catalog/presentation/bloc/catalog_load_status.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/sport_rules.dart';

part 'onboarding_state.dart';

/// Profile creation in six steps: display name, gender (set once), birth date (18+), city, sports with level,
/// experience, formats and goals, and optional home clubs. Each step is checked on the device before moving on; what
/// the server refuses (`UNDER_18`, …) is shown inline on the step it is about. After the 201, the home clubs are
/// saved, then the session is told the profile exists, which takes the router to home.
@injectable
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._profiles, this._catalog, this._session, {@ignoreParam DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const OnboardingState());

  final ProfileRepository _profiles;
  final CatalogRepository _catalog;
  final AuthSessionCubit _session;
  final DateTime Function() _clock;

  /// The youngest a player may be.
  static const int minimumAge = 18;

  /// The oldest birth year offered is this many years back.
  static const int oldestAge = 100;

  /// At most this many home clubs.
  static const int maxHomeVenues = 5;

  static final RegExp _displayNamePattern = RegExp(r'^[\p{L}\p{Mn}\p{Nd}‌ ]{2,30}$', unicode: true);

  Jalali get today => JalaliDateText.today(now: _clock());

  /// The inline message for [name], or null when the server will take it: 2–30 letters, digits, spaces and
  /// zero-width non-joiners.
  static String? validateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return AppStrings.displayNameRequired;
    return _displayNamePattern.hasMatch(trimmed) ? null : AppStrings.displayNameInvalid;
  }

  /// The inline message for [birthDate] on [today], or null when the player is 18 or older.
  static String? validateBirthDate(Jalali? birthDate, Jalali today) {
    if (birthDate == null) return AppStrings.birthDateRequired;
    if (birthDate.compareTo(today) > 0) return AppStrings.birthDateRequired;
    return JalaliDateText.ageOn(birthDate, today) < minimumAge ? AppStrings.under18 : null;
  }

  /// Loads the sports to choose from. Called once when the screen opens.
  Future<void> start() async {
    emit(state.copyWith(sportsStatus: CatalogLoadStatus.loading));
    final result = await _catalog.getSports();
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(sportsStatus: CatalogLoadStatus.failure)),
      (sports) => emit(
        state.copyWith(
          sportsStatus: CatalogLoadStatus.ready,
          sports: [
            for (final s in sports)
              if (s.isActive) s,
          ],
        ),
      ),
    );
  }

  /// Once a message is showing, it follows the typing, so it goes away as soon as the name is right.
  void displayNameChanged(String name) {
    final error = state.error == null ? null : validateDisplayName(name);
    emit(state.copyWith(displayName: name, error: () => error));
  }

  void genderSelected(Gender gender) => emit(state.copyWith(gender: gender, error: () => null));

  void birthDateChanged(Jalali? date) => emit(state.copyWith(birthDate: () => date, error: () => null));

  /// A new city clears the home clubs, which were in the old one.
  void citySelected(CitySelection city) {
    final moved = state.city?.cityId != city.cityId;
    emit(state.copyWith(city: city, homeVenues: moved ? const [] : null, error: () => null));
  }

  /// Chooses [sport], or drops it when chosen. A sport with one allowed format starts with it chosen.
  void toggleSport(Sport sport) {
    final drafts = state.isChosen(sport.id)
        ? [...state.drafts.where((d) => d.sportId != sport.id)]
        : [...state.drafts, SportRules.newDraft(sport)];
    emit(state.copyWith(drafts: drafts, error: () => null));
  }

  void sportChanged(SportProfileDraft draft) {
    emit(
      state.copyWith(drafts: [for (final d in state.drafts) d.sportId == draft.sportId ? draft : d], error: () => null),
    );
  }

  void homeVenuesChanged(List<Venue> venues) =>
      emit(state.copyWith(homeVenues: venues.take(maxHomeVenues).toList(growable: false), error: () => null));

  /// The message for [step] as it stands, or null when it is complete.
  String? validateStep(OnboardingStep step) => switch (step) {
    OnboardingStep.name => validateDisplayName(state.displayName),
    OnboardingStep.gender => state.gender == null ? AppStrings.genderRequired : null,
    OnboardingStep.birthDate => validateBirthDate(state.birthDate, today),
    OnboardingStep.city => state.city == null ? AppStrings.cityRequired : null,
    OnboardingStep.sports => _validateSports(),
    OnboardingStep.homeVenues => null,
  };

  /// Moves on when the current step is complete; otherwise says what is missing. On the last step it submits.
  Future<void> next() async {
    if (state.isSubmitting) return;
    final error = validateStep(state.step);
    if (error != null) {
      emit(state.copyWith(error: () => error));
      return;
    }
    if (state.isLastStep) return submit();
    emit(state.copyWith(step: OnboardingStep.values[state.step.index + 1], error: () => null));
  }

  void back() {
    if (state.isSubmitting || state.step.index == 0) return;
    emit(state.copyWith(step: OnboardingStep.values[state.step.index - 1], error: () => null));
  }

  /// Creates the profile (once), saves the home clubs if any, then tells the session.
  Future<void> submit() async {
    if (state.isSubmitting || state.status == OnboardingStatus.completed) return;
    for (final step in OnboardingStep.values) {
      final error = validateStep(step);
      if (error != null) {
        emit(state.copyWith(step: step, error: () => error));
        return;
      }
    }

    emit(state.copyWith(status: OnboardingStatus.submitting, error: () => null));
    if (!state.profileCreated) {
      final created = await _profiles.createProfile(_newProfile());
      if (isClosed) return;
      final failure = created.fold<Failure?>((f) => f, (_) => null);
      // A profile already there is one an earlier attempt created before its answer was lost.
      if (failure != null && failure.code != ProfileErrorCodes.profileExists) {
        emit(
          state.copyWith(
            status: OnboardingStatus.editing,
            step: _stepFor(failure.code) ?? state.step,
            error: () => failure.message,
          ),
        );
        return;
      }
      emit(state.copyWith(profileCreated: true));
    }

    if (state.homeVenues.isNotEmpty) {
      final saved = await _profiles.setHomeVenues([for (final v in state.homeVenues) v.id]);
      if (isClosed) return;
      final failure = saved.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        emit(
          state.copyWith(
            status: OnboardingStatus.editing,
            step: OnboardingStep.homeVenues,
            error: () => '${AppStrings.homeVenuesFailed}\n${failure.message}',
          ),
        );
        return;
      }
    }
    await _complete();
  }

  /// After the profile exists, finishes without home clubs: they can be set from the profile later.
  Future<void> skipHomeVenues() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(homeVenues: const [], error: () => null));
    if (state.profileCreated) {
      emit(state.copyWith(status: OnboardingStatus.submitting));
      await _complete();
    } else {
      await submit();
    }
  }

  Future<void> _complete() async {
    await _session.markProfileCompleted();
    if (isClosed) return;
    emit(state.copyWith(status: OnboardingStatus.completed, error: () => null));
  }

  String? _validateSports() {
    if (state.drafts.isEmpty) return AppStrings.sportsRequired;
    for (final draft in state.drafts) {
      final sport = state.sportOf(draft);
      if (sport == null) return AppStrings.sportsRequired;
      final error = SportRules.validate(draft, sport);
      if (error != null) return error;
    }
    return null;
  }

  NewProfile _newProfile() => NewProfile(
    displayName: state.displayName.trim(),
    gender: state.gender!,
    birthDate: JalaliDateText.toApi(state.birthDate!),
    cityId: state.city!.cityId,
    sports: state.drafts,
  );

  /// The step a server error code is about, or null for one about none in particular (offline, …).
  static OnboardingStep? _stepFor(String? code) => switch (code) {
    ProfileErrorCodes.invalidDisplayName => OnboardingStep.name,
    ProfileErrorCodes.under18 || ProfileErrorCodes.invalidBirthDate => OnboardingStep.birthDate,
    ProfileErrorCodes.unknownCity => OnboardingStep.city,
    ProfileErrorCodes.formatNotAllowed ||
    ProfileErrorCodes.formatRequired ||
    ProfileErrorCodes.goalRequired ||
    ProfileErrorCodes.sportProfileRequired => OnboardingStep.sports,
    _ => null,
  };
}
