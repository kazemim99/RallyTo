import 'package:equatable/equatable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../core/utils/jalali_date_text.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';

/// A public play post (open to requests) or a private invitation.
enum MatchVisibility {
  public('Public'),
  private('Private');

  const MatchVisibility(this.wire);

  final String wire;

  static MatchVisibility? tryParse(String? value) => parseWire(values, value, (v) => v.wire);
}

/// Where a game is in its lifecycle (spec match-lifecycle › Match states).
enum MatchStatus {
  open('Open'),
  pending('Pending'),
  confirmed('Confirmed'),
  completed('Completed'),
  disputed('Disputed'),
  unconfirmed('Unconfirmed'),
  cancelled('Cancelled'),
  expired('Expired');

  const MatchStatus(this.wire);

  final String wire;

  /// Still ahead: open, waiting for invitees, or confirmed.
  bool get isActive => this == open || this == pending || this == confirmed;

  static MatchStatus? tryParse(String? value) => parseWire(values, value, (s) => s.wire);
}

/// One player's place in a game.
enum ParticipantState {
  host('Host'),
  invited('Invited'),
  requested('Requested'),
  accepted('Accepted'),
  declined('Declined'),
  withdrawn('Withdrawn'),
  left('Left'),
  removed('Removed'),
  expired('Expired');

  const ParticipantState(this.wire);

  final String wire;

  /// Holds a place in the game: the host or an accepted player.
  bool get plays => this == host || this == accepted;

  /// Still in the game or waiting on an answer: what the host can remove.
  bool get isRemovable => this == accepted || this == invited || this == requested;

  static ParticipantState? tryParse(String? value) => parseWire(values, value, (s) => s.wire);
}

/// A player's answer to "was the game played?" once it ended.
enum AttendanceAnswer {
  played('Played'),
  didNotHappen('DidNotHappen');

  const AttendanceAnswer(this.wire);

  final String wire;

  static AttendanceAnswer? tryParse(String? value) => parseWire(values, value, (a) => a.wire);
}

/// What a participant's attendance counted as in a Completed game. Disputed and Unconfirmed games have none.
enum AttendanceOutcome {
  played('Played'),
  noShow('NoShow'),
  contested('Contested');

  const AttendanceOutcome(this.wire);

  final String wire;

  static AttendanceOutcome? tryParse(String? value) => parseWire(values, value, (o) => o.wire);
}

/// Who a post is open to.
enum PartnerGender {
  any('Any'),
  male('Male'),
  female('Female');

  const PartnerGender(this.wire);

  final String wire;

  /// The setting that admits only [gender].
  static PartnerGender of(Gender gender) => gender == Gender.male ? male : female;

  static PartnerGender? tryParse(String? value) => parseWire(values, value, (g) => g.wire);
}

/// The sport of a game, as the match view names it.
class SportRef extends Equatable {
  const SportRef({required this.id, required this.code, required this.name});

  final String id;
  final String code;

  /// Persian.
  final String name;

  @override
  List<Object?> get props => [id, code, name];
}

/// The host of a game, with their level in its sport.
class HostRef extends Equatable {
  const HostRef({required this.userId, required this.displayName, this.level});

  final String userId;
  final String displayName;
  final LevelTier? level;

  @override
  List<Object?> get props => [userId, displayName, level];
}

/// One player in a game, as the host and the players involved see it.
class MatchParticipant extends Equatable {
  const MatchParticipant({
    required this.userId,
    required this.displayName,
    required this.state,
    this.outOfRange = false,
    this.message,
    this.outcome,
  });

  final String userId;
  final String displayName;
  final ParticipantState state;

  /// A join request from a player whose level is outside the post's range.
  final bool outOfRange;

  /// The join request's or the invitation's message.
  final String? message;

  /// What their attendance counted as, once a Completed game was resolved.
  final AttendanceOutcome? outcome;

  @override
  List<Object?> get props => [userId, displayName, state, outOfRange, message, outcome];
}

/// This player's attendance and rating state, once the game has ended (`MatchAttendanceView`).
class MatchAttendance extends Equatable {
  const MatchAttendance({
    required this.open,
    required this.closesAt,
    this.myAnswer,
    this.myOutcome,
    this.resolvedAt,
    this.canRate = const [],
  });

  /// The 72-hour question is open: the game is still Confirmed and ended less than 72 hours ago.
  final bool open;
  final DateTime closesAt;

  /// This player's answer, once given.
  final AttendanceAnswer? myAnswer;

  /// What this player's attendance counted as, once a Completed game was resolved.
  final AttendanceOutcome? myOutcome;
  final DateTime? resolvedAt;

  /// The players this player may still rate for this game (user ids).
  final List<String> canRate;

  @override
  List<Object?> get props => [open, closesAt, myAnswer, myOutcome, resolvedAt, canRate];
}

/// A game, as the server returns it (`MatchView`). [participants] and [myState] are there only for the host and the
/// players involved; everyone else sees the public summary.
class Match extends Equatable {
  const Match({
    required this.id,
    required this.visibility,
    required this.status,
    required this.sport,
    required this.capacity,
    required this.openSpots,
    required this.venue,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.startsAt,
    required this.host,
    required this.partnerGender,
    this.format,
    this.minLevel,
    this.maxLevel,
    this.courtBooked = false,
    this.costNote,
    this.description,
    this.playersBrought = 0,
    this.shareUrl,
    this.participants,
    this.myState,
    this.cancelReason,
    this.attendance,
  });

  final String id;
  final MatchVisibility visibility;
  final MatchStatus status;
  final SportRef sport;
  final PlayFormat? format;
  final int capacity;
  final int openSpots;
  final NamedRef venue;

  /// Jalali «1405/08/02», on Tehran's calendar.
  final String date;

  /// «HH:mm» on Tehran's clock; [endTime] may be «24:00».
  final String startTime;
  final String endTime;
  final int durationMinutes;

  /// The start as an instant (UTC).
  final DateTime startsAt;
  final HostRef host;
  final LevelTier? minLevel;
  final LevelTier? maxLevel;
  final PartnerGender partnerGender;
  final bool courtBooked;
  final String? costNote;
  final String? description;
  final int playersBrought;

  /// `{PublicBaseUrl}/m/{token}`, for public posts only.
  final String? shareUrl;

  /// Null for a player who is not involved.
  final List<MatchParticipant>? participants;

  /// This player's place in the game, or null when not involved.
  final ParticipantState? myState;

  /// Why the host cancelled, on a cancelled game that has a reason; null otherwise.
  final String? cancelReason;

  /// This player's attendance and rating state once the game ended; null before, and for a player who did not play.
  final MatchAttendance? attendance;

  /// The share token at the end of [shareUrl], or null for a private game.
  String? get shareToken {
    final url = shareUrl;
    if (url == null) return null;
    final index = url.lastIndexOf('/m/');
    if (index < 0) return null;
    final token = url.substring(index + 3).split(RegExp(r'[/?#]')).first;
    return token.isEmpty ? null : token;
  }

  /// The date as a Jalali value, or null when it cannot be read.
  Jalali? get jalaliDate => JalaliDateText.tryParse(date);

  bool get isHost => myState == ParticipantState.host;
  bool get isPublic => visibility == MatchVisibility.public;

  List<MatchParticipant> _inState(ParticipantState state) => [
    for (final p in participants ?? const <MatchParticipant>[])
      if (p.state == state) p,
  ];

  /// The players who hold a place, host first.
  List<MatchParticipant> get players => [..._inState(ParticipantState.host), ..._inState(ParticipantState.accepted)];
  List<MatchParticipant> get pendingRequests => _inState(ParticipantState.requested);
  List<MatchParticipant> get invited => _inState(ParticipantState.invited);

  /// The host, players they bring and accepted players.
  int get playerCount => capacity - openSpots;

  bool hasStarted(DateTime now) => !now.isBefore(startsAt);

  /// Still taking players: open or waiting for invitees, and not started.
  bool acceptsPlayers(DateTime now) =>
      (status == MatchStatus.open || status == MatchStatus.pending) && !hasStarted(now);

  /// A player who is not in the game (or left it, or was declined) may ask to join an open public post with a spot.
  bool canJoin(DateTime now) =>
      isPublic &&
      status == MatchStatus.open &&
      openSpots > 0 &&
      !hasStarted(now) &&
      !const {
        ParticipantState.host,
        ParticipantState.accepted,
        ParticipantState.requested,
        ParticipantState.invited,
      }.contains(myState);

  bool get canWithdraw => myState == ParticipantState.requested;

  bool canAnswerInvitation(DateTime now) => myState == ParticipantState.invited && acceptsPlayers(now);

  bool canLeave(DateTime now) => myState == ParticipantState.accepted && status.isActive && !hasStarted(now);

  bool canAnswerRequests(DateTime now) => isHost && acceptsPlayers(now);

  /// The host confirms before capacity is reached, with at least 2 players including the host.
  bool canConfirmEarly(DateTime now) => isHost && acceptsPlayers(now) && playerCount >= 2;

  bool canCancel(DateTime now) => isHost && status.isActive && !hasStarted(now);

  bool canRemove(MatchParticipant participant, DateTime now) =>
      isHost && participant.state.isRemovable && status.isActive && !hasStarted(now);

  /// The host can invite while spots remain beyond the outstanding invitations.
  bool canInvite(DateTime now) => isHost && acceptsPlayers(now) && openSpots > invited.length;

  bool get canShare => isHost && shareUrl != null;

  /// Anyone may pass on a public post's link while it takes players; the host always can.
  bool canShareLink(DateTime now) => shareUrl != null && (isHost || acceptsPlayers(now));

  /// Another player may report a public post (its description and cost note).
  bool get canReportPost => isPublic && !isHost;

  /// The attendance question is open and this player has not answered it yet.
  bool get canAnswerAttendance => (attendance?.open ?? false) && attendance?.myAnswer == null;

  /// The players other than [myId] who held a place: who this player may flag as a no-show.
  List<MatchParticipant> otherPlayers(String? myId) => [
    for (final p in players)
      if (p.userId != myId) p,
  ];

  /// The players this player may still rate, in roster order.
  List<MatchParticipant> get rateablePlayers {
    final ids = attendance?.canRate ?? const <String>[];
    return [
      for (final p in participants ?? const <MatchParticipant>[])
        if (ids.contains(p.userId)) p,
    ];
  }

  @override
  List<Object?> get props => [
    id,
    visibility,
    status,
    sport,
    format,
    capacity,
    openSpots,
    venue,
    date,
    startTime,
    endTime,
    durationMinutes,
    startsAt,
    host,
    minLevel,
    maxLevel,
    partnerGender,
    courtBooked,
    costNote,
    description,
    playersBrought,
    shareUrl,
    participants,
    myState,
    cancelReason,
    attendance,
  ];
}

/// A play post as the host fills it in, sent as `MatchInput`. [startMinute] is minutes from midnight on Tehran's
/// clock.
class MatchDraft extends Equatable {
  const MatchDraft({
    required this.sportId,
    required this.venueId,
    required this.format,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    required this.playersBrought,
    required this.partnerGender,
    this.minLevel,
    this.maxLevel,
    this.courtBooked = false,
    this.costNote,
    this.description,
  });

  final String sportId;
  final String venueId;
  final PlayFormat format;
  final Jalali date;
  final int startMinute;
  final int? durationMinutes;
  final int playersBrought;
  final LevelTier? minLevel;
  final LevelTier? maxLevel;
  final PartnerGender partnerGender;
  final bool courtBooked;
  final String? costNote;
  final String? description;

  @override
  List<Object?> get props => [
    sportId,
    venueId,
    format,
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
  ];
}

/// A private game and the players invited to it, sent as `InvitationInput`.
class InvitationDraft extends Equatable {
  const InvitationDraft({
    required this.sportId,
    required this.venueId,
    required this.format,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    required this.playersBrought,
    required this.invitees,
    this.message,
  });

  final String sportId;
  final String venueId;
  final PlayFormat format;
  final Jalali date;
  final int startMinute;
  final int? durationMinutes;
  final int playersBrought;
  final List<String> invitees;
  final String? message;

  @override
  List<Object?> get props => [
    sportId,
    venueId,
    format,
    date,
    startMinute,
    durationMinutes,
    playersBrought,
    invitees,
    message,
  ];
}
