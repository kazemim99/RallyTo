// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SportRefModel _$SportRefModelFromJson(Map<String, dynamic> json) =>
    SportRefModel(id: json['id'] as String, code: json['code'] as String? ?? '', name: json['name'] as String? ?? '');

HostRefModel _$HostRefModelFromJson(Map<String, dynamic> json) => HostRefModel(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String? ?? '',
  level: json['level'] as String?,
);

ParticipantModel _$ParticipantModelFromJson(Map<String, dynamic> json) => ParticipantModel(
  userId: json['userId'] as String,
  state: json['state'] as String,
  displayName: json['displayName'] as String? ?? '',
  outOfRange: json['outOfRange'] as bool? ?? false,
  message: json['message'] as String?,
  outcome: json['outcome'] as String?,
);

MatchAttendanceModel _$MatchAttendanceModelFromJson(Map<String, dynamic> json) => MatchAttendanceModel(
  closesAt: json['closesAt'] as String,
  open: json['open'] as bool? ?? false,
  myAnswer: json['myAnswer'] as String?,
  myOutcome: json['myOutcome'] as String?,
  resolvedAt: json['resolvedAt'] as String?,
  canRate: (json['canRate'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);

MatchViewModel _$MatchViewModelFromJson(Map<String, dynamic> json) => MatchViewModel(
  id: json['id'] as String,
  visibility: json['visibility'] as String,
  status: json['status'] as String,
  sport: SportRefModel.fromJson(json['sport'] as Map<String, dynamic>),
  venue: NamedRefModel.fromJson(json['venue'] as Map<String, dynamic>),
  date: json['date'] as String,
  startTime: json['startTime'] as String,
  endTime: json['endTime'] as String,
  startsAt: json['startsAt'] as String,
  host: HostRefModel.fromJson(json['host'] as Map<String, dynamic>),
  format: json['format'] as String?,
  capacity: (json['capacity'] as num?)?.toInt() ?? 0,
  openSpots: (json['openSpots'] as num?)?.toInt() ?? 0,
  durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
  minLevel: json['minLevel'] as String?,
  maxLevel: json['maxLevel'] as String?,
  partnerGender: json['partnerGender'] as String?,
  courtBooked: json['courtBooked'] as bool? ?? false,
  costNote: json['costNote'] as String?,
  description: json['description'] as String?,
  playersBrought: (json['playersBrought'] as num?)?.toInt() ?? 0,
  shareUrl: json['shareUrl'] as String?,
  participants: (json['participants'] as List<dynamic>?)
      ?.map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  myState: json['myState'] as String?,
  cancelReason: json['cancelReason'] as String?,
  attendance: json['attendance'] == null
      ? null
      : MatchAttendanceModel.fromJson(json['attendance'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MatchInputModelToJson(MatchInputModel instance) => <String, dynamic>{
  'sportId': instance.sportId,
  'venueId': instance.venueId,
  'format': instance.format,
  'date': instance.date,
  'startTime': instance.startTime,
  'durationMinutes': ?instance.durationMinutes,
  'playersBrought': instance.playersBrought,
  'minLevel': ?instance.minLevel,
  'maxLevel': ?instance.maxLevel,
  'partnerGender': instance.partnerGender,
  'courtBooked': instance.courtBooked,
  'costNote': ?instance.costNote,
  'description': ?instance.description,
};

Map<String, dynamic> _$InvitationInputModelToJson(InvitationInputModel instance) => <String, dynamic>{
  'sportId': instance.sportId,
  'venueId': instance.venueId,
  'format': instance.format,
  'date': instance.date,
  'startTime': instance.startTime,
  'durationMinutes': ?instance.durationMinutes,
  'playersBrought': instance.playersBrought,
  'invitees': instance.invitees,
  'message': ?instance.message,
};

Map<String, dynamic> _$JoinRequestModelToJson(JoinRequestModel instance) => <String, dynamic>{
  'message': ?instance.message,
};

Map<String, dynamic> _$CancelRequestModelToJson(CancelRequestModel instance) => <String, dynamic>{
  'reason': ?instance.reason,
};

Map<String, dynamic> _$AttendanceRequestModelToJson(AttendanceRequestModel instance) => <String, dynamic>{
  'answer': instance.answer,
  'noShowPlayerIds': instance.noShowPlayerIds,
};

Map<String, dynamic> _$InviteRequestModelToJson(InviteRequestModel instance) => <String, dynamic>{
  'playerIds': instance.playerIds,
};
