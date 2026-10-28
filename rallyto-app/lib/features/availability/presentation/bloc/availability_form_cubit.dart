import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/utils/tehran_time.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/sport_rules.dart';
import '../../domain/availability_repository.dart';
import '../../domain/availability_rules.dart';
import '../../domain/entities/availability_window.dart';
import '../availability_labels.dart';

/// The parts of the form a message can be about.
enum AvailabilityField { sport, weekdays, date, time, venues, formats, note, validUntil }

/// Creating or editing an availability window. The server's rules are checked on the device first (30-minute steps,
/// at least 60 minutes, no crossing midnight, a one-off date today to 60 days ahead, 1–3 clubs, formats the sport
/// allows); what the server still refuses (`OVERLAPPING_WINDOW`, `TOO_MANY_WINDOWS`, …) is shown in its words.
@injectable
class AvailabilityFormCubit extends Cubit<AvailabilityFormState> {
  AvailabilityFormCubit(
    this._availability,
    this._profiles,
    this._catalog,
    @factoryParam AvailabilityWindow? existing, {
    @ignoreParam DateTime Function()? clock,
  }) : _existing = existing,
       _clock = clock ?? DateTime.now,
       super(AvailabilityFormState.from(existing));

  final AvailabilityRepository _availability;
  final ProfileRepository _profiles;
  final CatalogRepository _catalog;
  final AvailabilityWindow? _existing;
  final DateTime Function() _clock;

  bool get isEditing => _existing != null;

  /// Today on Tehran's calendar.
  Jalali get today => JalaliDateText.today(now: _clock());

  int get _nowMinute {
    final now = tehranWallClock(_clock());
    return now.hour * 60 + now.minute;
  }

  /// Loads the player's sports (only those may be offered) and city (where the clubs are searched).
  Future<void> load() async {
    emit(state.copyWith(loadStatus: ViewStatus.loading));
    final catalog = _catalog.getSports();
    final profile = await _profiles.getMyProfile();
    final sports = await catalog;
    if (isClosed) return;
    profile.fold((failure) => emit(state.copyWith(loadStatus: ViewStatus.error, loadError: failure.message)), (me) {
      final mine = {for (final s in me.sports) s.sportId};
      final offered = sports.fold(
        (_) => const <Sport>[],
        (all) => [
          for (final s in all)
            if (mine.contains(s.id)) s,
        ],
      );
      if (offered.isEmpty) {
        emit(state.copyWith(loadStatus: ViewStatus.empty));
        return;
      }
      final existing = _existing;
      emit(
        state.copyWith(
          loadStatus: ViewStatus.content,
          sports: offered,
          cityId: me.city.id,
          cityName: me.city.name,
          // A new window starts on the player's first sport, with its only format when it has one.
          sportId: existing?.sportId ?? (offered.length == 1 ? offered.single.id : null),
          formats: existing == null && offered.length == 1 ? _defaultFormats(offered.single) : null,
          venues: existing == null
              ? null
              : [
                  for (final v in existing.venues)
                    Venue(id: v.id, name: v.name, cityId: me.city.id, cityName: me.city.name),
                ],
        ),
      );
    });
  }

  /// A new sport resets the formats (to its only one, if so) and the clubs, which were picked for the old one.
  void sportSelected(String sportId) {
    if (sportId == state.sportId) return;
    final sport = state.sportById(sportId);
    emit(
      state.copyWith(
        sportId: sportId,
        formats: sport == null ? const {} : _defaultFormats(sport),
        venues: const [],
        fieldErrors: _without({AvailabilityField.sport, AvailabilityField.formats, AvailabilityField.venues}),
      ),
    );
  }

  void kindSelected(AvailabilityKind kind) => emit(
    state.copyWith(
      kind: kind,
      fieldErrors: _without({AvailabilityField.weekdays, AvailabilityField.date, AvailabilityField.validUntil}),
    ),
  );

  void weekdayToggled(Weekday day) {
    final days = state.weekdays.contains(day) ? ({...state.weekdays}..remove(day)) : {...state.weekdays, day};
    emit(state.copyWith(weekdays: days, fieldErrors: _without({AvailabilityField.weekdays})));
  }

  void dateSelected(Jalali date) =>
      emit(state.copyWith(date: () => date, fieldErrors: _without({AvailabilityField.date, AvailabilityField.time})));

  void startSelected(int minute) => emit(
    state.copyWith(startMinute: minute, fieldErrors: _without({AvailabilityField.time, AvailabilityField.date})),
  );

  void endSelected(int minute) =>
      emit(state.copyWith(endMinute: minute, fieldErrors: _without({AvailabilityField.time, AvailabilityField.date})));

  void venuesChanged(List<Venue> venues) =>
      emit(state.copyWith(venues: venues, fieldErrors: _without({AvailabilityField.venues})));

  void formatToggled(PlayFormat format) {
    final formats = state.formats.contains(format) ? ({...state.formats}..remove(format)) : {...state.formats, format};
    emit(state.copyWith(formats: formats, fieldErrors: _without({AvailabilityField.formats})));
  }

  void noteChanged(String note) => emit(state.copyWith(note: note, fieldErrors: _without({AvailabilityField.note})));

  void validUntilChanged(Jalali? date) =>
      emit(state.copyWith(validUntil: () => date, fieldErrors: _without({AvailabilityField.validUntil})));

  /// Every rule the form breaks, by field. Empty when it can be sent.
  Map<AvailabilityField, String> validate() {
    final errors = <AvailabilityField, String>{};
    final sport = state.sportById(state.sportId);
    if (sport == null) errors[AvailabilityField.sport] = AppStrings.sportRequired;

    final timeCode = AvailabilityRules.checkTime(state.startMinute, state.endMinute);
    if (timeCode != null) errors[AvailabilityField.time] = AvailabilityLabels.rule(timeCode);

    if (state.kind == AvailabilityKind.recurring) {
      if (state.weekdays.isEmpty) errors[AvailabilityField.weekdays] = AppStrings.weekdaysRequired;
      final until = state.validUntil;
      if (until != null && until.compareTo(today) < 0) {
        errors[AvailabilityField.validUntil] = AppStrings.validUntilInPast;
      }
    } else {
      final date = state.date;
      if (date == null) {
        errors[AvailabilityField.date] = AppStrings.dateRequired;
      } else {
        final code = AvailabilityRules.checkDate(date, state.endMinute, today: today, nowMinute: _nowMinute);
        if (code != null) errors[AvailabilityField.date] = AvailabilityLabels.rule(code);
      }
    }

    if (state.venues.isEmpty) {
      errors[AvailabilityField.venues] = AppStrings.venuesRequired;
    } else if (state.venues.length > AvailabilityRules.maxVenues) {
      errors[AvailabilityField.venues] = AppStrings.venuesTooMany(PersianDigits.fromInt(AvailabilityRules.maxVenues));
    }

    if (state.formats.isEmpty) {
      errors[AvailabilityField.formats] = AppStrings.formatsRequired;
    } else if (sport != null) {
      final allowed = SportRules.allowedFormats(sport);
      if (state.formats.any((f) => !allowed.contains(f))) {
        errors[AvailabilityField.formats] = AppStrings.formatNotAllowed;
      }
    }

    if (state.note.trim().length > AvailabilityRules.maxNoteLength) {
      errors[AvailabilityField.note] = AppStrings.noteTooLong(PersianDigits.fromInt(AvailabilityRules.maxNoteLength));
    }
    return errors;
  }

  /// Sends the window when the form is valid; otherwise marks what is wrong.
  Future<void> submit() async {
    if (state.submitting) return;
    final errors = validate();
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors, serverError: () => null));
      return;
    }
    emit(state.copyWith(submitting: true, fieldErrors: const {}, serverError: () => null));
    final draft = AvailabilityDraft(
      sportId: state.sportId!,
      venueIds: [for (final v in state.venues) v.id],
      kind: state.kind,
      weekdays: state.weekdays,
      date: state.date,
      startMinute: state.startMinute,
      endMinute: state.endMinute,
      formats: state.formats,
      note: state.note,
      validUntil: state.validUntil,
    );
    final existing = _existing;
    final result = existing == null
        ? await _availability.create(draft)
        : await _availability.update(existing.id, draft);
    if (isClosed) return;
    result.fold((failure) {
      final field = _fieldFor(failure.code);
      emit(
        state.copyWith(
          submitting: false,
          fieldErrors: field == null ? const {} : {field: failure.message},
          serverError: () => failure.message,
        ),
      );
    }, (window) => emit(state.copyWith(submitting: false, saved: () => window)));
  }

  static Set<PlayFormat> _defaultFormats(Sport sport) {
    final allowed = SportRules.allowedFormats(sport);
    return allowed.length == 1 ? {allowed.single} : const {};
  }

  Map<AvailabilityField, String> _without(Set<AvailabilityField> fields) => {
    for (final entry in state.fieldErrors.entries)
      if (!fields.contains(entry.key)) entry.key: entry.value,
  };

  /// The field a server error code is about, or null for one about the window as a whole (an overlap, the limit).
  static AvailabilityField? _fieldFor(String? code) => switch (code) {
    AvailabilityErrorCodes.windowTooShort ||
    AvailabilityErrorCodes.windowCrossesMidnight ||
    AvailabilityErrorCodes.invalidTimeStep ||
    AvailabilityErrorCodes.invalidTime => AvailabilityField.time,
    AvailabilityErrorCodes.dateTooFar || AvailabilityErrorCodes.windowInPast => AvailabilityField.date,
    AvailabilityErrorCodes.venuesInDifferentCities ||
    AvailabilityErrorCodes.venueDoesNotOfferSport => AvailabilityField.venues,
    AvailabilityErrorCodes.formatNotAllowed => AvailabilityField.formats,
    AvailabilityErrorCodes.noSportProfile => AvailabilityField.sport,
    _ => null,
  };
}

class AvailabilityFormState extends Equatable {
  const AvailabilityFormState({
    this.loadStatus = ViewStatus.loading,
    this.loadError,
    this.sports = const [],
    this.cityId,
    this.cityName = '',
    this.sportId,
    this.kind = AvailabilityKind.recurring,
    this.weekdays = const {},
    this.date,
    this.startMinute = defaultStart,
    this.endMinute = defaultEnd,
    this.venues = const [],
    this.formats = const {},
    this.note = '',
    this.validUntil,
    this.fieldErrors = const {},
    this.serverError,
    this.submitting = false,
    this.saved,
  });

  /// The form as [window] was, or empty for a new one.
  factory AvailabilityFormState.from(AvailabilityWindow? window) {
    if (window == null) return const AvailabilityFormState();
    return AvailabilityFormState(
      sportId: window.sportId,
      kind: window.kind,
      weekdays: window.weekdays.toSet(),
      date: JalaliDateText.tryParse(window.date),
      startMinute: TimeOfDayText.tryParse(window.startTime) ?? defaultStart,
      endMinute: TimeOfDayText.tryParse(window.endTime) ?? defaultEnd,
      formats: window.formats.toSet(),
      note: window.note ?? '',
      validUntil: JalaliDateText.tryParse(window.validUntil),
    );
  }

  /// A new window starts as 18:00–20:00.
  static const int defaultStart = 18 * 60;
  static const int defaultEnd = 20 * 60;

  /// [ViewStatus.empty]: the player has no sport profile to offer.
  final ViewStatus loadStatus;
  final String? loadError;

  /// The player's sports, from the catalog.
  final List<Sport> sports;
  final int? cityId;
  final String cityName;
  final String? sportId;
  final AvailabilityKind kind;
  final Set<Weekday> weekdays;
  final Jalali? date;
  final int startMinute;
  final int endMinute;
  final List<Venue> venues;
  final Set<PlayFormat> formats;
  final String note;
  final Jalali? validUntil;
  final Map<AvailabilityField, String> fieldErrors;

  /// The server's refusal, in its words.
  final String? serverError;
  final bool submitting;

  /// The window as the server saved it: the screen closes with it.
  final AvailabilityWindow? saved;

  Sport? sportById(String? id) {
    for (final sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Sport? get sport => sportById(sportId);

  AvailabilityFormState copyWith({
    ViewStatus? loadStatus,
    String? loadError,
    List<Sport>? sports,
    int? cityId,
    String? cityName,
    String? sportId,
    AvailabilityKind? kind,
    Set<Weekday>? weekdays,
    Jalali? Function()? date,
    int? startMinute,
    int? endMinute,
    List<Venue>? venues,
    Set<PlayFormat>? formats,
    String? note,
    Jalali? Function()? validUntil,
    Map<AvailabilityField, String>? fieldErrors,
    String? Function()? serverError,
    bool? submitting,
    AvailabilityWindow? Function()? saved,
  }) => AvailabilityFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    loadError: loadError ?? this.loadError,
    sports: sports ?? this.sports,
    cityId: cityId ?? this.cityId,
    cityName: cityName ?? this.cityName,
    sportId: sportId ?? this.sportId,
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    date: date == null ? this.date : date(),
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    venues: venues ?? this.venues,
    formats: formats ?? this.formats,
    note: note ?? this.note,
    validUntil: validUntil == null ? this.validUntil : validUntil(),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    serverError: serverError == null ? this.serverError : serverError(),
    submitting: submitting ?? this.submitting,
    saved: saved == null ? this.saved : saved(),
  );

  @override
  List<Object?> get props => [
    loadStatus,
    loadError,
    sports,
    cityId,
    cityName,
    sportId,
    kind,
    weekdays,
    date,
    startMinute,
    endMinute,
    venues,
    formats,
    note,
    validUntil,
    fieldErrors,
    serverError,
    submitting,
    saved,
  ];
}
