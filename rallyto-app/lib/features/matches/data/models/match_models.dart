import 'package:json_annotation/json_annotation.dart';

import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/utils/server_time.dart';
import '../../../availability/domain/availability_rules.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/data/models/profile_models.dart';
import '../../domain/entities/match.dart';

part 'match_models.g.dart';

/// `SportRef`.
@JsonSerializable(createToJson: false)
class SportRefModel {
  const SportRefModel({required this.id, this.code = '', this.name = ''});

  factory SportRefModel.fromJson(Map<String, dynamic> json) => _$SportRefModelFromJson(json);

  final String id;
  final String code;
  final String name;

  SportRef toEntity() => SportRef(id: id, code: code, name: name);
}

/// `HostRef`.
@JsonSerializable(createToJson: false)
class HostRefModel {
  const HostRefModel({required this.userId, this.displayName = '', this.level});

  factory HostRefModel.fromJson(Map<String, dynamic> json) => _$HostRefModelFromJson(json);

  final String userId;
  final String displayName;
  final String? level;

  HostRef toEntity() => HostRef(userId: userId, displayName: displayName, level: LevelTier.tryParse(level));
}

/// `ParticipantView`.
@JsonSerializable(createToJson: false)
class ParticipantModel {
  const ParticipantModel({
    required this.userId,
    required this.state,
    this.displayName = '',
    this.outOfRange = false,
    this.message,
    this.outcome,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => _$ParticipantModelFromJson(json);

  final String userId;
  final String displayName;
  final String state;
  final bool outOfRange;
  final String? message;
  final String? outcome;

  /// Null for a state this app does not know: such a participant is dropped.
  MatchParticipant? toEntity() {
    final parsed = ParticipantState.tryParse(state);
    if (parsed == null) return null;
    final text = message?.trim();
    return MatchParticipant(
      userId: userId,
      displayName: displayName,
      state: parsed,
      outOfRange: outOfRange,
      message: text == null || text.isEmpty ? null : text,
      outcome: AttendanceOutcome.tryParse(outcome),
    );
  }
}

/// `MatchAttendanceView`.
@JsonSerializable(createToJson: false)
class MatchAttendanceModel {
  const MatchAttendanceModel({
    required this.closesAt,
    this.open = false,
    this.myAnswer,
    this.myOutcome,
    this.resolvedAt,
    this.canRate = const [],
  });

  factory MatchAttendanceModel.fromJson(Map<String, dynamic> json) => _$MatchAttendanceModelFromJson(json);

  final bool open;
  final String closesAt;
  final String? myAnswer;
  final String? myOutcome;
  final String? resolvedAt;
  final List<String> canRate;

  MatchAttendance toEntity() => MatchAttendance(
    open: open,
    closesAt: parseServerInstant(closesAt) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    myAnswer: AttendanceAnswer.tryParse(myAnswer),
    myOutcome: AttendanceOutcome.tryParse(myOutcome),
    resolvedAt: parseServerInstant(resolvedAt),
    canRate: canRate,
  );
}

/// `MatchView`. Enums arrive as strings.
@JsonSerializable(createToJson: false)
class MatchViewModel {
  const MatchViewModel({
    required this.id,
    required this.visibility,
    required this.status,
    required this.sport,
    required this.venue,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startsAt,
    required this.host,
    this.format,
    this.capacity = 0,
    this.openSpots = 0,
    this.durationMinutes = 0,
    this.minLevel,
    this.maxLevel,
    this.partnerGender,
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

  factory MatchViewModel.fromJson(Map<String, dynamic> json) => _$MatchViewModelFromJson(json);

  final String id;
  final String visibility;
  final String status;
  final SportRefModel sport;
  final String? format;
  final int capacity;
  final int openSpots;
  final NamedRefModel venue;
  final String date;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String startsAt;
  final HostRefModel host;
  final String? minLevel;
  final String? maxLevel;
  final String? partnerGender;
  final bool courtBooked;
  final String? costNote;
  final String? description;
  final int playersBrought;
  final String? shareUrl;
  final List<ParticipantModel>? participants;
  final String? myState;

  /// The host's reason, on a cancelled game.
  final String? cancelReason;

  /// The viewer's attendance and rating state, once the game has ended.
  final MatchAttendanceModel? attendance;

  Match toEntity() => Match(
    id: id,
    visibility: MatchVisibility.tryParse(visibility) ?? MatchVisibility.private,
    status: MatchStatus.tryParse(status) ?? MatchStatus.expired,
    sport: sport.toEntity(),
    format: PlayFormat.tryParse(format),
    capacity: capacity,
    openSpots: openSpots,
    venue: venue.toEntity(),
    date: date,
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    startsAt: (DateTime.tryParse(startsAt) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)).toUtc(),
    host: host.toEntity(),
    minLevel: LevelTier.tryParse(minLevel),
    maxLevel: LevelTier.tryParse(maxLevel),
    partnerGender: PartnerGender.tryParse(partnerGender) ?? PartnerGender.any,
    courtBooked: courtBooked,
    costNote: _blankToNull(costNote),
    description: _blankToNull(description),
    playersBrought: playersBrought,
    shareUrl: _blankToNull(shareUrl),
    participants: participants == null ? null : [for (final p in participants!) ?p.toEntity()],
    myState: ParticipantState.tryParse(myState),
    cancelReason: _blankToNull(cancelReason),
    attendance: attendance?.toEntity(),
  );
}

/// `MatchInput`. Levels left null take the server's default (the host's level ± 1).
@JsonSerializable(createFactory: false, includeIfNull: false)
class MatchInputModel {
  const MatchInputModel({
    required this.sportId,
    required this.venueId,
    required this.format,
    required this.date,
    required this.startTime,
    required this.playersBrought,
    required this.partnerGender,
    required this.courtBooked,
    this.durationMinutes,
    this.minLevel,
    this.maxLevel,
    this.costNote,
    this.description,
  });

  factory MatchInputModel.fromDraft(MatchDraft draft) => MatchInputModel(
    sportId: draft.sportId,
    venueId: draft.venueId,
    format: draft.format.wire,
    date: JalaliDateText.toApi(draft.date),
    startTime: TimeOfDayText.toApi(draft.startMinute),
    durationMinutes: draft.durationMinutes,
    playersBrought: draft.playersBrought,
    minLevel: draft.minLevel?.wire,
    maxLevel: draft.maxLevel?.wire,
    partnerGender: draft.partnerGender.wire,
    courtBooked: draft.courtBooked,
    costNote: _blankToNull(draft.costNote),
    description: _blankToNull(draft.description),
  );

  final String sportId;
  final String venueId;
  final String format;
  final String date;
  final String startTime;
  final int? durationMinutes;
  final int playersBrought;
  final String? minLevel;
  final String? maxLevel;
  final String partnerGender;
  final bool courtBooked;
  final String? costNote;
  final String? description;

  Map<String, dynamic> toJson() => _$MatchInputModelToJson(this);
}

/// `InvitationInput`.
@JsonSerializable(createFactory: false, includeIfNull: false)
class InvitationInputModel {
  const InvitationInputModel({
    required this.sportId,
    required this.venueId,
    required this.format,
    required this.date,
    required this.startTime,
    required this.playersBrought,
    required this.invitees,
    this.durationMinutes,
    this.message,
  });

  factory InvitationInputModel.fromDraft(InvitationDraft draft) => InvitationInputModel(
    sportId: draft.sportId,
    venueId: draft.venueId,
    format: draft.format.wire,
    date: JalaliDateText.toApi(draft.date),
    startTime: TimeOfDayText.toApi(draft.startMinute),
    durationMinutes: draft.durationMinutes,
    playersBrought: draft.playersBrought,
    invitees: draft.invitees,
    message: _blankToNull(draft.message),
  );

  final String sportId;
  final String venueId;
  final String format;
  final String date;
  final String startTime;
  final int? durationMinutes;
  final int playersBrought;
  final List<String> invitees;
  final String? message;

  Map<String, dynamic> toJson() => _$InvitationInputModelToJson(this);
}

/// `JoinRequest {message}`: the body is always sent, the message only when there is one.
@JsonSerializable(createFactory: false, includeIfNull: false)
class JoinRequestModel {
  const JoinRequestModel({this.message});

  final String? message;

  Map<String, dynamic> toJson() => _$JoinRequestModelToJson(this);
}

/// `CancelRequest {reason}`.
@JsonSerializable(createFactory: false, includeIfNull: false)
class CancelRequestModel {
  const CancelRequestModel({this.reason});

  final String? reason;

  Map<String, dynamic> toJson() => _$CancelRequestModelToJson(this);
}

/// `AttendanceRequest {answer, noShowPlayerIds}`.
@JsonSerializable(createFactory: false)
class AttendanceRequestModel {
  const AttendanceRequestModel({required this.answer, this.noShowPlayerIds = const []});

  final String answer;
  final List<String> noShowPlayerIds;

  Map<String, dynamic> toJson() => _$AttendanceRequestModelToJson(this);
}

/// `InviteRequest {playerIds}`.
@JsonSerializable(createFactory: false)
class InviteRequestModel {
  const InviteRequestModel({required this.playerIds});

  final List<String> playerIds;

  Map<String, dynamic> toJson() => _$InviteRequestModelToJson(this);
}

String? _blankToNull(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
