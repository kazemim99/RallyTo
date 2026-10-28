import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/sport_rules.dart';
import '../../../search/domain/search_rules.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_repository.dart';
import '../../domain/match_rules.dart';
import '../match_labels.dart';

/// The player a direct invitation is for.
class InviteeRef extends Equatable {
  const InviteeRef({required this.userId, this.displayName = ''});

  final String userId;
  final String displayName;

  @override
  List<Object?> get props => [userId, displayName];
}

/// What the form creates: a public play post, or a private game inviting [invitee].
class MatchFormArgs extends Equatable {
  const MatchFormArgs.post() : invitee = null;

  const MatchFormArgs.invitation(InviteeRef this.invitee);

  final InviteeRef? invitee;

  bool get isInvitation => invitee != null;

  @override
  List<Object?> get props => [invitee];
}

/// The parts of the form a message can be about.
enum MatchField { sport, format, venue, date, time, duration, playersBrought, costNote, description, message }

/// Creating a play post (spec play-posts › Create a play post) or a direct invitation (spec match-lifecycle › Direct
/// invitation). The server's rules are checked on the device first (a start 30 minutes to 30 days ahead, 60–240
/// minutes in 30-minute steps, players brought within capacity, text lengths); what the server still refuses is shown
/// in the app's words for its code. An invitation can also go into one of the host's open posts instead.
@injectable
class MatchFormCubit extends Cubit<MatchFormState> {
  MatchFormCubit(
    this._matches,
    this._profiles,
    this._catalog,
    @factoryParam MatchFormArgs args, {
    @ignoreParam DateTime Function()? clock,
  }) : _args = args,
       _clock = clock ?? DateTime.now,
       super(MatchFormState(invitee: args.invitee));

  final MatchRepository _matches;
  final ProfileRepository _profiles;
  final CatalogRepository _catalog;
  final MatchFormArgs _args;
  final DateTime Function() _clock;

  bool get isInvitation => _args.isInvitation;

  DateTime get _now => _clock().toUtc();

  /// Today on Tehran's calendar.
  Jalali get today => JalaliDateText.today(now: _clock());

  /// The dates offered: today to 30 days ahead.
  List<Jalali> get dateOptions => [for (var i = 0; i <= MatchRules.maxDaysAhead; i++) today.addDays(i)];

  /// Loads the player's sports (only those may be played), level, city and visibility; for an invitation also the
  /// host's open posts the invitee could be invited into.
  Future<void> load() async {
    emit(state.copyWith(loadStatus: ViewStatus.loading));
    final catalog = _catalog.getSports();
    final upcoming = isInvitation ? _matches.getMine(upcoming: true) : null;
    final profile = await _profiles.getMyProfile();
    final sports = await catalog;
    final mine = upcoming == null ? null : await upcoming;
    if (isClosed) return;
    profile.fold((failure) => emit(state.copyWith(loadStatus: ViewStatus.error, loadError: failure.message)), (me) {
      final have = {for (final s in me.sports) s.sportId};
      final offered = sports.fold(
        (_) => const <Sport>[],
        (all) => [
          for (final s in all)
            if (have.contains(s.id) && s.isActive) s,
        ],
      );
      if (offered.isEmpty) {
        emit(state.copyWith(loadStatus: ViewStatus.empty));
        return;
      }
      final now = _now;
      final posts = mine?.fold(
        (_) => const <Match>[],
        (all) => [
          for (final m in all)
            if (m.canInvite(now) && m.isPublic) m,
        ],
      );
      final locked = SearchRules.lockedGender(me);
      emit(
        _withSport(
          state.copyWith(
            loadStatus: ViewStatus.content,
            sports: offered,
            profile: me,
            cityId: me.city.id,
            cityName: me.city.name,
            partnerGender: locked == null ? PartnerGender.any : PartnerGender.of(locked),
            invitablePosts: posts ?? const [],
          ),
          offered.first,
        ),
      );
    });
  }

  /// A new sport resets what depends on it: the format, the club, the duration, the level range and players brought.
  void sportSelected(String sportId) {
    if (sportId == state.sportId) return;
    final sport = state.sportById(sportId);
    if (sport == null) return;
    emit(_withSport(state.copyWith(fieldErrors: _without(MatchField.values.toSet())), sport));
  }

  void formatSelected(PlayFormat format) {
    final capacity = MatchRules.capacityOf(state.sport, format);
    final max = MatchRules.maxPlayersBrought(capacity);
    emit(
      state.copyWith(
        format: format,
        playersBrought: state.playersBrought > max ? max : state.playersBrought,
        fieldErrors: _without({MatchField.format, MatchField.playersBrought}),
      ),
    );
  }

  void venueSelected(Venue? venue) =>
      emit(state.copyWith(venue: () => venue, fieldErrors: _without({MatchField.venue})));

  void dateSelected(Jalali date) =>
      emit(state.copyWith(date: () => date, fieldErrors: _without({MatchField.date, MatchField.time})));

  void startSelected(int minute) =>
      emit(state.copyWith(startMinute: minute, fieldErrors: _without({MatchField.time, MatchField.date})));

  void durationSelected(int minutes) =>
      emit(state.copyWith(durationMinutes: minutes, fieldErrors: _without({MatchField.duration})));

  void playersBroughtSelected(int count) =>
      emit(state.copyWith(playersBrought: count, fieldErrors: _without({MatchField.playersBrought})));

  void minLevelSelected(LevelTier tier) {
    final max = state.maxLevel;
    emit(state.copyWith(minLevel: tier, maxLevel: max != null && max.index < tier.index ? tier : max));
  }

  void maxLevelSelected(LevelTier tier) {
    final min = state.minLevel;
    emit(state.copyWith(maxLevel: tier, minLevel: min != null && min.index > tier.index ? tier : min));
  }

  /// Ignored for a same-gender-only host: the server forces their own gender anyway.
  void partnerGenderSelected(PartnerGender gender) {
    if (state.genderLocked) return;
    emit(state.copyWith(partnerGender: gender));
  }

  void courtBookedChanged(bool booked) => emit(state.copyWith(courtBooked: booked));

  void costNoteChanged(String text) =>
      emit(state.copyWith(costNote: text, fieldErrors: _without({MatchField.costNote})));

  void descriptionChanged(String text) =>
      emit(state.copyWith(description: text, fieldErrors: _without({MatchField.description})));

  void messageChanged(String text) => emit(state.copyWith(message: text, fieldErrors: _without({MatchField.message})));

  /// Every rule the form breaks, by field. Empty when it can be sent.
  Map<MatchField, String> validate() {
    final errors = <MatchField, String>{};
    final sport = state.sport;
    if (sport == null) errors[MatchField.sport] = AppStrings.sportRequired;
    final format = state.format;
    if (format == null) {
      errors[MatchField.format] = AppStrings.formatsRequired;
    } else if (sport != null && !SportRules.allowedFormats(sport).contains(format)) {
      errors[MatchField.format] = AppStrings.formatNotAllowed;
    }
    if (state.venue == null) errors[MatchField.venue] = AppStrings.venueRequired;
    final date = state.date;
    if (date == null) {
      errors[MatchField.date] = AppStrings.dateRequired;
    } else {
      final code = MatchRules.checkStart(date, state.startMinute, _now);
      if (code != null) errors[MatchField.time] = MatchLabels.rule(code);
    }
    if (!MatchRules.durationOptions.contains(state.durationMinutes)) {
      errors[MatchField.duration] = MatchLabels.rule(MatchErrorCodes.invalidDuration);
    }
    if (state.playersBrought < 0 || state.playersBrought > state.maxPlayersBrought) {
      errors[MatchField.playersBrought] = MatchLabels.rule(MatchErrorCodes.invalidPlayersBrought);
    }
    if (isInvitation) {
      if (state.message.trim().length > MatchRules.maxMessageLength) {
        errors[MatchField.message] = MatchLabels.rule(MatchErrorCodes.messageTooLong);
      }
    } else {
      if (state.costNote.trim().length > MatchRules.maxCostNoteLength) {
        errors[MatchField.costNote] = MatchLabels.rule(MatchErrorCodes.costNoteTooLong);
      }
      if (state.description.trim().length > MatchRules.maxDescriptionLength) {
        errors[MatchField.description] = MatchLabels.rule(MatchErrorCodes.descriptionTooLong);
      }
    }
    return errors;
  }

  /// Sends the post or the invitation when the form is valid; otherwise marks what is wrong.
  Future<void> submit() async {
    if (state.submitting) return;
    final errors = validate();
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors, serverError: () => null));
      return;
    }
    emit(state.copyWith(submitting: true, fieldErrors: const {}, serverError: () => null));
    final invitee = state.invitee;
    final result = invitee != null
        ? await _matches.createInvitation(
            InvitationDraft(
              sportId: state.sportId!,
              venueId: state.venue!.id,
              format: state.format!,
              date: state.date!,
              startMinute: state.startMinute,
              durationMinutes: state.durationMinutes,
              playersBrought: state.playersBrought,
              invitees: [invitee.userId],
              message: state.message,
            ),
          )
        : await _matches.createPost(
            MatchDraft(
              sportId: state.sportId!,
              venueId: state.venue!.id,
              format: state.format!,
              date: state.date!,
              startMinute: state.startMinute,
              durationMinutes: state.durationMinutes,
              playersBrought: state.playersBrought,
              minLevel: state.minLevel,
              maxLevel: state.maxLevel,
              partnerGender: state.partnerGender,
              courtBooked: state.courtBooked,
              costNote: state.costNote,
              description: state.description,
            ),
          );
    if (isClosed) return;
    result.fold((failure) {
      final message = MatchLabels.error(failure);
      final field = _fieldFor(failure.code);
      emit(
        state.copyWith(
          submitting: false,
          fieldErrors: field == null ? const {} : {field: message},
          serverError: () => message,
        ),
      );
    }, (match) => emit(state.copyWith(submitting: false, saved: () => match)));
  }

  /// Invites the invitee into one of the host's open posts instead of a new game.
  Future<void> inviteInto(Match post) async {
    final invitee = state.invitee;
    if (invitee == null || state.submitting) return;
    emit(state.copyWith(submitting: true, serverError: () => null));
    final result = await _matches.invite(post.id, [invitee.userId]);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(submitting: false, serverError: () => MatchLabels.error(failure))),
      (match) => emit(state.copyWith(submitting: false, saved: () => match)),
    );
  }

  MatchFormState _withSport(MatchFormState base, Sport sport) {
    final formats = SportRules.allowedFormats(sport);
    final (min, max) = SearchRules.levelRange(_levelIn(base.profile, sport.id));
    return base.copyWith(
      sportId: sport.id,
      format: formats.first,
      venue: () => null,
      durationMinutes: MatchRules.defaultDuration(sport),
      playersBrought: 0,
      minLevel: min,
      maxLevel: max,
    );
  }

  static LevelTier? _levelIn(MyProfile? profile, String sportId) =>
      profile == null ? null : SearchRules.levelIn(profile, sportId);

  Map<MatchField, String> _without(Set<MatchField> fields) => {
    for (final entry in state.fieldErrors.entries)
      if (!fields.contains(entry.key)) entry.key: entry.value,
  };

  /// The field a server error code is about, or null for one about the game as a whole.
  static MatchField? _fieldFor(String? code) => switch (code) {
    MatchErrorCodes.noSportProfile || MatchErrorCodes.unknownSport => MatchField.sport,
    MatchErrorCodes.formatNotAllowed => MatchField.format,
    MatchErrorCodes.unknownVenue || MatchErrorCodes.venueDoesNotOfferSport => MatchField.venue,
    MatchErrorCodes.invalidDate => MatchField.date,
    MatchErrorCodes.invalidTime || MatchErrorCodes.startTooSoon || MatchErrorCodes.startTooFar => MatchField.time,
    MatchErrorCodes.invalidDuration => MatchField.duration,
    MatchErrorCodes.invalidPlayersBrought || MatchErrorCodes.tooManyInvitees => MatchField.playersBrought,
    MatchErrorCodes.costNoteTooLong => MatchField.costNote,
    MatchErrorCodes.descriptionTooLong => MatchField.description,
    MatchErrorCodes.messageTooLong => MatchField.message,
    _ => null,
  };
}

class MatchFormState extends Equatable {
  const MatchFormState({
    this.loadStatus = ViewStatus.loading,
    this.loadError,
    this.sports = const [],
    this.profile,
    this.cityId,
    this.cityName = '',
    this.invitee,
    this.invitablePosts = const [],
    this.sportId,
    this.format,
    this.venue,
    this.date,
    this.startMinute = defaultStart,
    this.durationMinutes = 90,
    this.playersBrought = 0,
    this.minLevel,
    this.maxLevel,
    this.partnerGender = PartnerGender.any,
    this.courtBooked = false,
    this.costNote = '',
    this.description = '',
    this.message = '',
    this.fieldErrors = const {},
    this.serverError,
    this.submitting = false,
    this.saved,
  });

  /// A new game starts at 18:00.
  static const int defaultStart = 18 * 60;

  /// [ViewStatus.empty]: the player has no sport profile to play.
  final ViewStatus loadStatus;
  final String? loadError;

  /// The player's sports, from the catalog.
  final List<Sport> sports;
  final MyProfile? profile;
  final int? cityId;
  final String cityName;

  /// Set for a direct invitation.
  final InviteeRef? invitee;

  /// The host's open posts with room for another invitation (an invitation only).
  final List<Match> invitablePosts;
  final String? sportId;
  final PlayFormat? format;
  final Venue? venue;
  final Jalali? date;
  final int startMinute;
  final int durationMinutes;
  final int playersBrought;
  final LevelTier? minLevel;
  final LevelTier? maxLevel;
  final PartnerGender partnerGender;
  final bool courtBooked;
  final String costNote;
  final String description;
  final String message;
  final Map<MatchField, String> fieldErrors;

  /// The server's refusal, in the app's words.
  final String? serverError;
  final bool submitting;

  /// The game as the server saved it: the screen moves on to it.
  final Match? saved;

  Sport? sportById(String? id) {
    for (final sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Sport? get sport => sportById(sportId);

  /// A same-gender-only host's posts are for their own gender only.
  bool get genderLocked => profile != null && SearchRules.lockedGender(profile!) != null;

  int get capacity => format == null ? 2 : MatchRules.capacityOf(sport, format!);

  int get maxPlayersBrought => MatchRules.maxPlayersBrought(capacity);

  /// The spots left for others once the host and the players they bring are counted.
  int get openSpots => MatchRules.openSpots(capacity, playersBrought);

  MatchFormState copyWith({
    ViewStatus? loadStatus,
    String? loadError,
    List<Sport>? sports,
    MyProfile? profile,
    int? cityId,
    String? cityName,
    List<Match>? invitablePosts,
    String? sportId,
    PlayFormat? format,
    Venue? Function()? venue,
    Jalali? Function()? date,
    int? startMinute,
    int? durationMinutes,
    int? playersBrought,
    LevelTier? minLevel,
    LevelTier? maxLevel,
    PartnerGender? partnerGender,
    bool? courtBooked,
    String? costNote,
    String? description,
    String? message,
    Map<MatchField, String>? fieldErrors,
    String? Function()? serverError,
    bool? submitting,
    Match? Function()? saved,
  }) => MatchFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    loadError: loadError ?? this.loadError,
    sports: sports ?? this.sports,
    profile: profile ?? this.profile,
    cityId: cityId ?? this.cityId,
    cityName: cityName ?? this.cityName,
    invitee: invitee,
    invitablePosts: invitablePosts ?? this.invitablePosts,
    sportId: sportId ?? this.sportId,
    format: format ?? this.format,
    venue: venue == null ? this.venue : venue(),
    date: date == null ? this.date : date(),
    startMinute: startMinute ?? this.startMinute,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    playersBrought: playersBrought ?? this.playersBrought,
    minLevel: minLevel ?? this.minLevel,
    maxLevel: maxLevel ?? this.maxLevel,
    partnerGender: partnerGender ?? this.partnerGender,
    courtBooked: courtBooked ?? this.courtBooked,
    costNote: costNote ?? this.costNote,
    description: description ?? this.description,
    message: message ?? this.message,
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
    profile,
    cityId,
    cityName,
    invitee,
    invitablePosts,
    sportId,
    format,
    venue,
    date,
    startMinute,
    durationMinutes,
    playersBrought,
    minLevel,
    maxLevel,
    partnerGender,
    courtBooked,
    costNote,
    description,
    message,
    fieldErrors,
    serverError,
    submitting,
    saved,
  ];
}
