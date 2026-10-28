// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'availability_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AvailabilityViewModel _$AvailabilityViewModelFromJson(Map<String, dynamic> json) => AvailabilityViewModel(
  id: json['id'] as String,
  sportId: json['sportId'] as String,
  sportCode: json['sportCode'] as String,
  kind: json['kind'] as String,
  startTime: json['startTime'] as String,
  endTime: json['endTime'] as String,
  status: json['status'] as String,
  venues:
      (json['venues'] as List<dynamic>?)?.map((e) => NamedRefModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  weekdays: (json['weekdays'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  date: json['date'] as String?,
  formats: (json['formats'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  note: json['note'] as String?,
  validUntil: json['validUntil'] as String?,
  needsReconfirmation: json['needsReconfirmation'] as bool? ?? false,
  pausesOn: json['pausesOn'] as String?,
);

Map<String, dynamic> _$AvailabilityInputModelToJson(AvailabilityInputModel instance) => <String, dynamic>{
  'sportId': instance.sportId,
  'venueIds': instance.venueIds,
  'kind': instance.kind,
  'weekdays': ?instance.weekdays,
  'date': ?instance.date,
  'startTime': instance.startTime,
  'endTime': instance.endTime,
  'formats': instance.formats,
  'note': ?instance.note,
  'validUntil': ?instance.validUntil,
};
