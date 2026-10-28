import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/reports/data/report_api.dart';
import 'package:rallyto_app/features/reports/data/report_repository_impl.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';

import '../../../helpers/fake_server.dart';

/// Reports over the real client stack, against the backend's contract (ReportsController, ReportRequest,
/// ReportReceiptView, MyReportView; TrustSafetyTests, SafetyApi): string enums, 201 with `{id, status}`, the server's
/// codes.
void main() {
  late FakeServer server;
  late ReportRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = ReportRepositoryImpl(ReportApi(server.dio()));
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);

  test('each target goes with its type and id, the reason, trimmed details and the block choice', () async {
    server.routes['POST /api/v1/reports'] = (_) => okBody({'id': 'rp-1', 'status': 'Open'}, status: 201);

    final receipt = valueOf(
      await repository.file(
        const ReportDraft(
          target: ReportTarget.message('msg-1', senderName: 'علی'),
          reason: ReportReason.harassment,
          details: '  پیام توهین‌آمیز ',
          block: true,
        ),
      ),
    );

    expect(receipt, const ReportReceipt(id: 'rp-1', status: ReportStatus.open));
    expect(server.calls.last, 'POST /api/v1/reports');
    expect(server.lastJson, {
      'targetType': 'Message',
      'targetId': 'msg-1',
      'reason': 'Harassment',
      'details': 'پیام توهین‌آمیز',
      'block': true,
    });

    for (final (target, type) in [
      (const ReportTarget.player('u-2'), 'Player'),
      (const ReportTarget.post('m-1'), 'Post'),
      (const ReportTarget.photo('u-2'), 'Photo'),
    ]) {
      await repository.file(ReportDraft(target: target, reason: ReportReason.other, details: ' '));
      expect(server.lastJson, {'targetType': type, 'targetId': target.targetId, 'reason': 'Other', 'block': false});
    }
  });

  test('every reason goes by its wire name', () async {
    server.routes['POST /api/v1/reports'] = (_) => okBody({'id': 'rp-1', 'status': 'Open'}, status: 201);
    final sent = <Object?>[];
    for (final reason in ReportReason.values) {
      await repository.file(ReportDraft(target: const ReportTarget.player('u-2'), reason: reason));
      sent.add(server.lastJson['reason']);
    }

    expect(sent, ['Harassment', 'InappropriateContent', 'FakeProfile', 'Spam', 'UnsafeBehaviour', 'Underage', 'Other']);
  });

  test('every report refusal keeps its code, the 429 included', () async {
    for (final (status, code) in [
      (409, 'ALREADY_REPORTED'),
      (404, 'MESSAGE_NOT_FOUND'),
      (404, 'PHOTO_NOT_FOUND'),
      (404, 'PLAYER_NOT_FOUND'),
      (404, 'MATCH_NOT_FOUND'),
      (422, 'CANNOT_REPORT_SELF'),
      (422, 'DETAILS_TOO_LONG'),
      (429, 'TOO_MANY_REQUESTS'),
    ]) {
      server.routes['POST /api/v1/reports'] = (_) => errorBody(status, code, 'x');
      final failure = (await repository.file(
        const ReportDraft(target: ReportTarget.player('u-2'), reason: ReportReason.spam),
      )).fold((f) => f, (_) => fail('expected a refusal'));
      expect(failure.code, code);
    }
  });

  test('my reports: type, reason, Open or Resolved, and when; nothing about the action taken', () async {
    server.routes['GET /api/v1/reports/mine'] = (_) => okBody([
      {
        'id': 'rp-1',
        'targetType': 'Player',
        'reason': 'FakeProfile',
        'status': 'Resolved',
        'createdAt': '2026-10-20T08:00:00Z',
      },
      {'id': 'rp-2', 'targetType': 'Post', 'reason': 'Spam', 'status': 'Open', 'createdAt': '2026-10-22T08:00:00'},
      {'id': 'rp-3', 'targetType': 'SomethingNew', 'reason': 'SomethingNew', 'status': 'Open', 'createdAt': null},
    ]);

    final reports = valueOf(await repository.getMine());

    expect(reports, [
      MyReport(
        id: 'rp-1',
        targetType: ReportTargetType.player,
        reason: ReportReason.fakeProfile,
        status: ReportStatus.resolved,
        createdAt: DateTime.utc(2026, 10, 20, 8),
      ),
      MyReport(
        id: 'rp-2',
        targetType: ReportTargetType.post,
        reason: ReportReason.spam,
        status: ReportStatus.open,
        createdAt: DateTime.utc(2026, 10, 22, 8),
      ),
      const MyReport(id: 'rp-3', status: ReportStatus.open, createdAt: null),
    ]);
  });
}
