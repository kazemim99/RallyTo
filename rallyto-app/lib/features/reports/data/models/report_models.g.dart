// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ReportInputModelToJson(ReportInputModel instance) => <String, dynamic>{
  'targetType': instance.targetType,
  'targetId': instance.targetId,
  'reason': instance.reason,
  'details': ?instance.details,
  'block': instance.block,
};

ReportReceiptModel _$ReportReceiptModelFromJson(Map<String, dynamic> json) =>
    ReportReceiptModel(id: json['id'] as String, status: json['status'] as String?);

MyReportModel _$MyReportModelFromJson(Map<String, dynamic> json) => MyReportModel(
  id: json['id'] as String,
  targetType: json['targetType'] as String?,
  reason: json['reason'] as String?,
  status: json['status'] as String?,
  createdAt: json['createdAt'] as String?,
);
