import 'package:json_annotation/json_annotation.dart';

import '../../../../core/utils/server_time.dart';
import '../../domain/entities/report.dart';

part 'report_models.g.dart';

/// `ReportRequest`. Enums go as strings.
@JsonSerializable(createFactory: false, includeIfNull: false)
class ReportInputModel {
  const ReportInputModel({
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.block,
    this.details,
  });

  factory ReportInputModel.fromDraft(ReportDraft draft) {
    final details = draft.details?.trim();
    return ReportInputModel(
      targetType: draft.target.type.wire,
      targetId: draft.target.targetId,
      reason: draft.reason.wire,
      details: details == null || details.isEmpty ? null : details,
      block: draft.block,
    );
  }

  final String targetType;
  final String targetId;
  final String reason;
  final String? details;
  final bool block;

  Map<String, dynamic> toJson() => _$ReportInputModelToJson(this);
}

/// `ReportReceiptView`.
@JsonSerializable(createToJson: false)
class ReportReceiptModel {
  const ReportReceiptModel({required this.id, this.status});

  factory ReportReceiptModel.fromJson(Map<String, dynamic> json) => _$ReportReceiptModelFromJson(json);

  final String id;
  final String? status;

  ReportReceipt toEntity() => ReportReceipt(id: id, status: ReportStatus.tryParse(status) ?? ReportStatus.open);
}

/// `MyReportView`.
@JsonSerializable(createToJson: false)
class MyReportModel {
  const MyReportModel({required this.id, this.targetType, this.reason, this.status, this.createdAt});

  factory MyReportModel.fromJson(Map<String, dynamic> json) => _$MyReportModelFromJson(json);

  final String id;
  final String? targetType;
  final String? reason;
  final String? status;
  final String? createdAt;

  MyReport toEntity() => MyReport(
    id: id,
    targetType: ReportTargetType.tryParse(targetType),
    reason: ReportReason.tryParse(reason),
    status: ReportStatus.tryParse(status) ?? ReportStatus.open,
    createdAt: parseServerInstant(createdAt),
  );
}
