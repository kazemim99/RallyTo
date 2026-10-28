part of 'onboarding_cubit.dart';

/// The six steps, in order.
enum OnboardingStep { name, gender, birthDate, city, sports, homeVenues }

enum OnboardingStatus {
  /// Filling in a step, or back after an error.
  editing,

  /// Waiting on the server.
  submitting,

  /// The profile exists and the session says so: the router moves on to home.
  completed,
}

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = OnboardingStep.name,
    this.status = OnboardingStatus.editing,
    this.displayName = '',
    this.gender,
    this.birthDate,
    this.city,
    this.sportsStatus = CatalogLoadStatus.loading,
    this.sports = const [],
    this.drafts = const [],
    this.homeVenues = const [],
    this.error,
    this.profileCreated = false,
  });

  final OnboardingStep step;
  final OnboardingStatus status;

  /// As typed.
  final String displayName;
  final Gender? gender;
  final Jalali? birthDate;
  final CitySelection? city;

  /// The catalog's sports, to choose from.
  final CatalogLoadStatus sportsStatus;
  final List<Sport> sports;

  /// One per chosen sport, in the order chosen.
  final List<SportProfileDraft> drafts;
  final List<Venue> homeVenues;

  /// The current step's message: a rule it breaks, or the server's refusal (`UNDER_18`, …), shown inline.
  final String? error;

  /// `POST /profile` already answered 201: a retry only saves the home clubs.
  final bool profileCreated;

  int get stepNumber => step.index + 1;

  static int get stepCount => OnboardingStep.values.length;

  bool get isLastStep => step == OnboardingStep.values.last;

  bool get isSubmitting => status == OnboardingStatus.submitting;

  /// Whether [sport] is chosen.
  bool isChosen(String sportId) => drafts.any((d) => d.sportId == sportId);

  /// The catalog sport of [draft], or null when the catalog no longer has it.
  Sport? sportOf(SportProfileDraft draft) {
    for (final sport in sports) {
      if (sport.id == draft.sportId) return sport;
    }
    return null;
  }

  OnboardingState copyWith({
    OnboardingStep? step,
    OnboardingStatus? status,
    String? displayName,
    Gender? gender,
    Jalali? Function()? birthDate,
    CitySelection? city,
    CatalogLoadStatus? sportsStatus,
    List<Sport>? sports,
    List<SportProfileDraft>? drafts,
    List<Venue>? homeVenues,
    String? Function()? error,
    bool? profileCreated,
  }) => OnboardingState(
    step: step ?? this.step,
    status: status ?? this.status,
    displayName: displayName ?? this.displayName,
    gender: gender ?? this.gender,
    birthDate: birthDate == null ? this.birthDate : birthDate(),
    city: city ?? this.city,
    sportsStatus: sportsStatus ?? this.sportsStatus,
    sports: sports ?? this.sports,
    drafts: drafts ?? this.drafts,
    homeVenues: homeVenues ?? this.homeVenues,
    error: error == null ? this.error : error(),
    profileCreated: profileCreated ?? this.profileCreated,
  );

  @override
  List<Object?> get props => [
    step,
    status,
    displayName,
    gender,
    birthDate,
    city,
    sportsStatus,
    sports,
    drafts,
    homeVenues,
    error,
    profileCreated,
  ];
}
