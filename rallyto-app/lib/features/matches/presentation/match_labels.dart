import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/display_join.dart';
import '../../../core/utils/jalali_date_text.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/persian_digits.dart';
import '../../availability/domain/availability_rules.dart';
import '../../catalog/domain/entities/sport.dart';
import '../../profile/presentation/profile_labels.dart';
import '../domain/entities/match.dart';
import '../domain/match_rules.dart';

/// Persian labels for games, and the messages for the server's match error codes.
class MatchLabels {
  MatchLabels._();

  static String status(MatchStatus status) => switch (status) {
    MatchStatus.open => AppStrings.matchStatusOpen,
    MatchStatus.pending => AppStrings.matchStatusPending,
    MatchStatus.confirmed => AppStrings.matchStatusConfirmed,
    MatchStatus.completed => AppStrings.matchStatusCompleted,
    MatchStatus.disputed => AppStrings.matchStatusDisputed,
    MatchStatus.unconfirmed => AppStrings.matchStatusUnconfirmed,
    MatchStatus.cancelled => AppStrings.matchStatusCancelled,
    MatchStatus.expired => AppStrings.matchStatusExpired,
  };

  static String participant(ParticipantState state) => switch (state) {
    ParticipantState.host => AppStrings.participantHost,
    ParticipantState.invited => AppStrings.participantInvited,
    ParticipantState.requested => AppStrings.participantRequested,
    ParticipantState.accepted => AppStrings.participantAccepted,
    ParticipantState.declined => AppStrings.participantDeclined,
    ParticipantState.withdrawn => AppStrings.participantWithdrawn,
    ParticipantState.left => AppStrings.participantLeft,
    ParticipantState.removed => AppStrings.participantRemoved,
    ParticipantState.expired => AppStrings.participantExpired,
  };

  /// What this player's place in the game means for them, or null when there is nothing to say.
  static String? myState(ParticipantState? state) => switch (state) {
    ParticipantState.host => AppStrings.myStateHost,
    ParticipantState.invited => AppStrings.myStateInvited,
    ParticipantState.requested => AppStrings.myStateRequested,
    ParticipantState.accepted => AppStrings.myStateAccepted,
    ParticipantState.declined => AppStrings.myStateDeclined,
    ParticipantState.withdrawn => AppStrings.myStateWithdrawn,
    ParticipantState.left => AppStrings.myStateLeft,
    ParticipantState.removed => AppStrings.myStateRemoved,
    ParticipantState.expired => AppStrings.myStateExpired,
    null => null,
  };

  static String answer(AttendanceAnswer answer) => switch (answer) {
    AttendanceAnswer.played => AppStrings.attendancePlayed,
    AttendanceAnswer.didNotHappen => AppStrings.attendanceDidNotHappen,
  };

  static String outcome(AttendanceOutcome outcome) => switch (outcome) {
    AttendanceOutcome.played => AppStrings.outcomePlayed,
    AttendanceOutcome.noShow => AppStrings.outcomeNoShow,
    AttendanceOutcome.contested => AppStrings.outcomeContested,
  };

  /// What a resolved game's status means for its players, or null while it is not resolved.
  static String? resolution(MatchStatus status) => switch (status) {
    MatchStatus.completed => AppStrings.resolutionCompleted,
    MatchStatus.disputed => AppStrings.resolutionDisputed,
    MatchStatus.unconfirmed => AppStrings.resolutionUnconfirmed,
    _ => null,
  };

  /// «پذیرفته‌شده • بازی کرد»: a participant's place, and their attendance once the game was resolved.
  static String participantLine(MatchParticipant p) {
    final outcome = p.outcome;
    return outcome == null ? participant(p.state) : [participant(p.state), MatchLabels.outcome(outcome)].joinDisplay();
  }

  /// The share sheet's text: the game, the club, the day and time, and the link.
  static String shareText(Match match) =>
      AppStrings.shareText(title(match), match.venue.name, when(match), match.shareUrl ?? '');

  static String partnerGender(PartnerGender gender) => switch (gender) {
    PartnerGender.any => AppStrings.partnerGenderAny,
    PartnerGender.male => AppStrings.partnerGenderMale,
    PartnerGender.female => AppStrings.partnerGenderFemale,
  };

  static String visibility(MatchVisibility visibility) => switch (visibility) {
    MatchVisibility.public => AppStrings.matchPublic,
    MatchVisibility.private => AppStrings.matchPrivate,
  };

  /// [tier] in [sport]'s own words when it is known, else the shared tier name.
  static String level(LevelTier tier, [Sport? sport]) {
    for (final level in sport?.levels ?? const <SportLevel>[]) {
      if (level.tier == tier) return level.name;
    }
    return switch (tier) {
      LevelTier.beginner => AppStrings.tierBeginner,
      LevelTier.lowerIntermediate => AppStrings.tierLowerIntermediate,
      LevelTier.intermediate => AppStrings.tierIntermediate,
      LevelTier.advanced => AppStrings.tierAdvanced,
      LevelTier.professional => AppStrings.tierProfessional,
    };
  }

  /// «متوسط تا پیشرفته», or one name when both ends are the same.
  static String levelRange(LevelTier? min, LevelTier? max, [Sport? sport]) {
    if (min == null || max == null) return '';
    if (min == max) return level(min, sport);
    return AppStrings.levelRange(level(min, sport), level(max, sport));
  }

  /// «تنیس • انفرادی».
  static String title(Match match) {
    final format = match.format;
    return format == null ? match.sport.name : [match.sport.name, ProfileLabels.format(format)].joinDisplay();
  }

  /// «تنیس در باشگاه انقلاب».
  static String cardTitle(Match match) => AppStrings.matchCardTitle(match.sport.name, match.venue.name);

  /// «متوسط تا پیشرفته • انفرادی»: the level range and the format, whichever the game has.
  static String levelAndFormat(Match match, [Sport? sport]) {
    final format = match.format;
    return [
      levelRange(match.minLevel, match.maxLevel, sport),
      if (format != null) ProfileLabels.format(format),
    ].where((part) => part.isNotEmpty).joinDisplay();
  }

  /// The sport ball's letter: the initial of the sport's code («T» for tennis), else of its name.
  static String sportInitial(SportRef sport) {
    final source = sport.code.isNotEmpty ? sport.code : sport.name;
    return source.isEmpty ? '' : source.substring(0, 1).toUpperCase();
  }

  /// «بازی عصر شنبه»: the part of the day the game starts in, and its weekday.
  static String coverTitle(Match match) {
    final minute = TimeOfDayText.tryParse(match.startTime);
    final date = match.jalaliDate;
    return AppStrings.matchCoverTitle(
      minute == null ? '' : dayPart(minute),
      date == null ? '' : JalaliFormatter.weekdayNames[date.weekDay - 1],
    );
  }

  /// صبح before 11:00, ظهر before 14:00, عصر before 20:00, then شب.
  static String dayPart(int minute) {
    if (minute < 11 * 60) return AppStrings.dayPartMorning;
    if (minute < 14 * 60) return AppStrings.dayPartNoon;
    if (minute < 20 * 60) return AppStrings.dayPartAfternoon;
    return AppStrings.dayPartNight;
  }

  /// Who is in [match], for its card: the names behind the avatars (this player first, as «شما») and a caption such
  /// as «شما و سارا». [myId] tells this player apart among the participants; without it an accepted player's
  /// partners are counted rather than named when that is ambiguous. A player who is not in the game sees the host.
  static ({List<String> names, String caption}) company(Match match, {String? myId}) {
    final mine = match.myState;
    final host = match.host.displayName;
    if (mine == null) return (names: [host], caption: AppStrings.hostedBy(host));
    if (!mine.plays) return (names: [host], caption: myState(mine)!);
    final participants = match.participants;
    if (participants == null) {
      return (names: [AppStrings.you, if (mine != ParticipantState.host) host], caption: myState(mine)!);
    }
    final players = match.players;
    final accepted = players.where((p) => p.state == ParticipantState.accepted).length;
    final List<String>? others = switch (myId) {
      final id? => [
        for (final p in players)
          if (p.userId != id) p.displayName,
      ],
      null when mine == ParticipantState.host => [
        for (final p in players)
          if (p.state != ParticipantState.host) p.displayName,
      ],
      // An accepted player who is the only accepted one: the others are the host.
      null when accepted == 1 => [
        for (final p in players)
          if (p.state == ParticipantState.host) p.displayName,
      ],
      _ => null,
    };
    final count = players.length - 1 + match.playersBrought;
    final names = [AppStrings.you, ...?others];
    if (count <= 0) return (names: names, caption: AppStrings.justYou);
    if (others != null && match.playersBrought == 0 && others.length <= 2) {
      return (names: names, caption: AppStrings.youAnd(others.join(AppStrings.nameSeparator)));
    }
    return (names: names, caption: AppStrings.youAndOthers(PersianDigits.fromInt(count)));
  }

  /// «شنبه ۲ آبان ۱۴۰۵ • ۱۹:۰۰ تا ۲۰:۳۰».
  static String when(Match match) {
    final date = match.jalaliDate;
    final day = date == null
        ? JalaliDateText.display(match.date)
        : PersianDigits.toPersian(
            '${JalaliFormatter.weekdayNames[date.weekDay - 1]} ${date.day} '
            '${JalaliFormatter.monthNames[date.month - 1]} ${date.year}',
          );
    final time = AppStrings.timeRange(
      TimeOfDayText.displayText(match.startTime),
      TimeOfDayText.displayText(match.endTime),
    );
    return [day, time].joinDisplay();
  }

  /// «۱ جای خالی از ۲».
  static String spots(Match match) =>
      AppStrings.openSpots(PersianDigits.fromInt(match.openSpots), PersianDigits.fromInt(match.capacity));

  /// «۹۰ دقیقه».
  static String duration(int minutes) => AppStrings.durationMinutes(PersianDigits.fromInt(minutes));

  /// The player-facing message for a failed match action: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by the server's code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    MatchErrorCodes.matchNotFound: AppStrings.matchNotAvailable,
    MatchErrorCodes.matchNotAvailable: AppStrings.matchNotAvailable,
    MatchErrorCodes.shareLinkInvalid: AppStrings.shareLinkInvalid,
    MatchErrorCodes.scheduleConflict: AppStrings.scheduleConflict,
    MatchErrorCodes.noOpenSpot: AppStrings.noOpenSpot,
    MatchErrorCodes.matchClosed: AppStrings.matchClosed,
    MatchErrorCodes.matchStarted: AppStrings.matchStarted,
    MatchErrorCodes.matchFinished: AppStrings.matchFinished,
    MatchErrorCodes.alreadyInMatch: AppStrings.alreadyInMatch,
    MatchErrorCodes.notAPost: AppStrings.notAPost,
    MatchErrorCodes.notTheHost: AppStrings.notTheHost,
    MatchErrorCodes.notAParticipant: AppStrings.notAParticipant,
    MatchErrorCodes.notEnoughPlayers: AppStrings.notEnoughPlayers,
    MatchErrorCodes.invalidParticipantState: AppStrings.invalidParticipantState,
    MatchErrorCodes.tooManyOpenPosts: AppStrings.tooManyOpenPosts,
    MatchErrorCodes.tooManyPendingRequests: AppStrings.tooManyPendingRequests,
    MatchErrorCodes.tooManyInvitees: AppStrings.tooManyInvitees,
    MatchErrorCodes.inviteeDoesNotPlay: AppStrings.inviteeDoesNotPlay,
    MatchErrorCodes.playerNotFound: AppStrings.playerNotFound,
    MatchErrorCodes.noSportProfile: AppStrings.noSportProfileForMatch,
    MatchErrorCodes.unknownSport: AppStrings.unknownSport,
    MatchErrorCodes.unknownVenue: AppStrings.unknownVenue,
    MatchErrorCodes.venueDoesNotOfferSport: AppStrings.venueDoesNotOfferSport,
    MatchErrorCodes.formatNotAllowed: AppStrings.formatNotAllowed,
    MatchErrorCodes.invalidDate: AppStrings.invalidDate,
    MatchErrorCodes.invalidTime: AppStrings.invalidTime,
    MatchErrorCodes.invalidDuration: AppStrings.invalidDuration,
    MatchErrorCodes.startTooSoon: AppStrings.startTooSoon,
    MatchErrorCodes.startTooFar: AppStrings.startTooFar,
    MatchErrorCodes.invalidPlayersBrought: AppStrings.invalidPlayersBrought,
    MatchErrorCodes.messageTooLong: AppStrings.messageTooLong,
    MatchErrorCodes.costNoteTooLong: AppStrings.costNoteTooLong,
    MatchErrorCodes.descriptionTooLong: AppStrings.descriptionTooLong,
    MatchErrorCodes.tooManyRequests: AppStrings.tooManyRequestsError,
    MatchErrorCodes.attendanceNotOpen: AppStrings.attendanceNotOpen,
    MatchErrorCodes.attendanceClosed: AppStrings.attendanceClosed,
    MatchErrorCodes.alreadyAnswered: AppStrings.alreadyAnswered,
    MatchErrorCodes.invalidNoShow: AppStrings.invalidNoShow,
  };
}
