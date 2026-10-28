import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../core/utils/tehran_time.dart';
import '../../catalog/domain/entities/sport.dart';
import 'entities/match.dart';

/// The server's `error.code`s for play posts, invitations and matches.
class MatchErrorCodes {
  MatchErrorCodes._();

  static const String matchNotFound = 'MATCH_NOT_FOUND';
  static const String matchNotAvailable = 'MATCH_NOT_AVAILABLE';
  static const String shareLinkInvalid = 'SHARE_LINK_INVALID';
  static const String scheduleConflict = 'SCHEDULE_CONFLICT';
  static const String noOpenSpot = 'NO_OPEN_SPOT';
  static const String matchClosed = 'MATCH_CLOSED';
  static const String matchStarted = 'MATCH_STARTED';
  static const String matchFinished = 'MATCH_FINISHED';
  static const String alreadyInMatch = 'ALREADY_IN_MATCH';
  static const String notAPost = 'NOT_A_POST';
  static const String notTheHost = 'NOT_THE_HOST';
  static const String notAParticipant = 'NOT_A_PARTICIPANT';
  static const String notEnoughPlayers = 'NOT_ENOUGH_PLAYERS';
  static const String invalidParticipantState = 'INVALID_PARTICIPANT_STATE';
  static const String tooManyOpenPosts = 'TOO_MANY_OPEN_POSTS';
  static const String tooManyPendingRequests = 'TOO_MANY_PENDING_REQUESTS';
  static const String tooManyInvitees = 'TOO_MANY_INVITEES';
  static const String inviteeDoesNotPlay = 'INVITEE_DOES_NOT_PLAY';
  static const String playerNotFound = 'PLAYER_NOT_FOUND';
  static const String noSportProfile = 'NO_SPORT_PROFILE';
  static const String unknownSport = 'UNKNOWN_SPORT';
  static const String unknownVenue = 'UNKNOWN_VENUE';
  static const String venueDoesNotOfferSport = 'VENUE_DOES_NOT_OFFER_SPORT';
  static const String formatNotAllowed = 'FORMAT_NOT_ALLOWED';
  static const String invalidDate = 'INVALID_DATE';
  static const String invalidTime = 'INVALID_TIME';
  static const String invalidDuration = 'INVALID_DURATION';
  static const String startTooSoon = 'START_TOO_SOON';
  static const String startTooFar = 'START_TOO_FAR';
  static const String invalidPlayersBrought = 'INVALID_PLAYERS_BROUGHT';
  static const String messageTooLong = 'MESSAGE_TOO_LONG';
  static const String costNoteTooLong = 'COST_NOTE_TOO_LONG';
  static const String descriptionTooLong = 'DESCRIPTION_TOO_LONG';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String attendanceNotOpen = 'ATTENDANCE_NOT_OPEN';
  static const String attendanceClosed = 'ATTENDANCE_CLOSED';
  static const String alreadyAnswered = 'ALREADY_ANSWERED';
  static const String invalidNoShow = 'INVALID_NO_SHOW';
}

/// The server's rules for a game, mirrored so the player hears about them before sending.
class MatchRules {
  MatchRules._();

  static const int step = 30;
  static const int minDuration = 60;
  static const int maxDuration = 240;

  /// A game starts at least this many minutes from now…
  static const int minLeadMinutes = 30;

  /// …and at most this many days ahead.
  static const int maxDaysAhead = 30;

  static const int maxMessageLength = 200;
  static const int maxCostNoteLength = 200;
  static const int maxDescriptionLength = 500;

  /// Leaving or cancelling a confirmed game closer to its start than this is recorded as a late cancellation.
  static const Duration lateCancellationWindow = Duration(hours: 12);

  static const int _endOfDay = 24 * 60;

  /// 00:00 to 23:30.
  static List<int> get startOptions => [for (var m = 0; m < _endOfDay; m += step) m];

  /// 60 to 240 minutes, in 30-minute steps.
  static List<int> get durationOptions => [for (var m = minDuration; m <= maxDuration; m += step) m];

  /// Players in a full game of [format] in [sport]: from the catalog, else 2 for singles and 4 for doubles.
  static int capacityOf(Sport? sport, PlayFormat format) {
    for (final f in sport?.formats ?? const <SportFormat>[]) {
      if (f.format == format) return f.capacity;
    }
    return format == PlayFormat.singles ? 2 : 4;
  }

  /// The host may bring 0 up to capacity − 2 players.
  static int maxPlayersBrought(int capacity) => capacity - 2 < 0 ? 0 : capacity - 2;

  /// The spots left for others: capacity − 1 − players brought.
  static int openSpots(int capacity, int playersBrought) => capacity - 1 - playersBrought;

  /// The sport's session length, kept on the duration grid.
  static int defaultDuration(Sport? sport) {
    final minutes = sport?.defaultSessionMinutes ?? 90;
    if (minutes < minDuration) return minDuration;
    if (minutes > maxDuration) return maxDuration;
    return minutes - minutes % step;
  }

  /// The instant Tehran's clock reads [minute] on [date].
  static DateTime startInstant(Jalali date, int minute) {
    final day = date.toGregorian();
    return fromTehranWallClock(DateTime.utc(day.year, day.month, day.day).add(Duration(minutes: minute)));
  }

  /// A start between 30 minutes and 30 days from [now]: the server's code when it is not, or null.
  static String? checkStart(Jalali date, int minute, DateTime now) {
    final start = startInstant(date, minute);
    if (start.isBefore(now.add(const Duration(minutes: minLeadMinutes)))) return MatchErrorCodes.startTooSoon;
    if (start.isAfter(now.add(const Duration(days: maxDaysAhead)))) return MatchErrorCodes.startTooFar;
    return null;
  }

  /// Whether leaving or cancelling [match] now is recorded as a late cancellation: it is confirmed and starts within
  /// 12 hours.
  static bool isLateCancellation(Match match, DateTime now) =>
      match.status == MatchStatus.confirmed &&
      !match.hasStarted(now) &&
      match.startsAt.difference(now) < lateCancellationWindow;
}

/// Share links: `{PublicBaseUrl}/m/{token}`.
class ShareLinks {
  ShareLinks._();

  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{6,64}$');

  /// The token in [input]: a whole share link, a path `/m/{token}`, or the bare token. Null when there is none.
  static String? tokenOf(String input) {
    var text = input.trim();
    final index = text.lastIndexOf('/m/');
    if (index >= 0) text = text.substring(index + 3);
    text = text.split(RegExp(r'[/?#]')).first;
    return _token.hasMatch(text) ? text : null;
  }
}
