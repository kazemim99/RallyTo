import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';
import 'package:rallyto_app/features/reports/domain/report_repository.dart';

/// A [ReportRepository] answering from what the test set, recording what it was asked.
class FakeReportRepository implements ReportRepository {
  List<MyReport> mine = [
    MyReport(
      id: 'rp-1',
      targetType: ReportTargetType.player,
      reason: ReportReason.harassment,
      status: ReportStatus.open,
      createdAt: DateTime.utc(2026, 10, 20, 8),
    ),
    MyReport(
      id: 'rp-2',
      targetType: ReportTargetType.message,
      reason: ReportReason.spam,
      status: ReportStatus.resolved,
      createdAt: DateTime.utc(2026, 10, 22, 8),
    ),
  ];

  /// When set, the next report answers with it instead of succeeding.
  Failure? failure;

  /// When set, the list answers with it.
  Failure? loadFailure;

  final List<ReportDraft> filed = [];

  @override
  Future<Either<Failure, ReportReceipt>> file(ReportDraft draft) async {
    filed.add(draft);
    final failure = this.failure;
    return failure == null ? const Right(ReportReceipt(id: 'rp-9', status: ReportStatus.open)) : Left(failure);
  }

  @override
  Future<Either<Failure, List<MyReport>>> getMine() async {
    final failure = loadFailure;
    return failure == null ? Right(mine) : Left(failure);
  }
}
