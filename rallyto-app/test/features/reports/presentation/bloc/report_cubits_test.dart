import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';
import 'package:rallyto_app/features/reports/domain/report_rules.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/my_reports_cubit.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/report_form_cubit.dart';

import '../../../../helpers/fake_reports.dart';

/// Filing a report (reason, details, block in the same step) with each refusal in the app's words; and «گزارش‌های
/// من», newest first.
void main() {
  late FakeReportRepository reports;

  setUp(() => reports = FakeReportRepository());

  group('the report form', () {
    ReportFormCubit open([ReportTarget target = const ReportTarget.player('u-2', playerName: 'علی')]) {
      final cubit = ReportFormCubit(reports, target);
      addTearDown(cubit.close);
      return cubit;
    }

    test('starts with no reason, no details and no block', () {
      final cubit = open();

      expect(cubit.state.reason, isNull);
      expect(cubit.state.details, '');
      expect(cubit.state.block, isFalse);
      expect(cubit.state.done, isFalse);
    });

    test('without a reason nothing is sent', () async {
      final cubit = open();

      await cubit.submit();

      expect(cubit.state.feedback?.code, ReportErrorCodes.reasonRequired);
      expect(cubit.state.feedback?.message, AppStrings.reportReasonRequired);
      expect(reports.filed, isEmpty);
    });

    test('details over 1000 characters are refused before sending (DETAILS_TOO_LONG)', () async {
      final cubit = open()
        ..setReason(ReportReason.spam)
        ..setDetails('ا' * 1001);

      await cubit.submit();

      expect(cubit.state.feedback?.code, ReportErrorCodes.detailsTooLong);
      expect(cubit.state.feedback?.message, AppStrings.reportDetailsTooLong);
      expect(reports.filed, isEmpty);
    });

    test('a report is filed once, and closes the form', () async {
      final cubit = open(const ReportTarget.message('msg-1', senderName: 'علی'))
        ..setReason(ReportReason.harassment)
        ..setDetails('پیام توهین‌آمیز');

      await cubit.submit();

      expect(reports.filed, [
        const ReportDraft(
          target: ReportTarget.message('msg-1', senderName: 'علی'),
          reason: ReportReason.harassment,
          details: 'پیام توهین‌آمیز',
        ),
      ]);
      expect(cubit.state.done, isTrue);
      expect(cubit.state.block, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.reportSent);

      await cubit.submit();
      expect(reports.filed, hasLength(1));
    });

    test('with "block this player too", the block goes in the same step and is said', () async {
      final cubit = open()
        ..setReason(ReportReason.unsafeBehaviour)
        ..setBlock(true);

      await cubit.submit();

      expect(reports.filed.single.block, isTrue);
      expect(cubit.state.done, isTrue);
      expect(cubit.state.block, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.reportSentAndBlocked);
    });

    const cases = {
      ReportErrorCodes.alreadyReported: AppStrings.alreadyReported,
      ReportErrorCodes.messageNotFound: AppStrings.reportMessageNotFound,
      ReportErrorCodes.photoNotFound: AppStrings.reportPhotoNotFound,
      ReportErrorCodes.playerNotFound: AppStrings.playerNotFound,
      ReportErrorCodes.matchNotFound: AppStrings.reportPostNotFound,
      ReportErrorCodes.cannotReportSelf: AppStrings.cannotReportSelf,
      ReportErrorCodes.detailsTooLong: AppStrings.reportDetailsTooLong,
      ReportErrorCodes.tooManyRequests: AppStrings.reportTooManyRequests,
    };
    for (final MapEntry(key: code, value: message) in cases.entries) {
      test('$code is said in the app\'s words, and the form stays', () async {
        reports.failure = ServerFailure('server words', code: code, statusCode: 409);
        final cubit = open()..setReason(ReportReason.other);

        await cubit.submit();

        expect(cubit.state.done, isFalse);
        expect(cubit.state.submitting, isFalse);
        expect(cubit.state.feedback?.message, message);
        expect(cubit.state.feedback?.isError, isTrue);
        expect(cubit.state.feedback?.code, code);
      });
    }
  });

  group('my reports', () {
    MyReportsCubit open() {
      final cubit = MyReportsCubit(reports);
      addTearDown(cubit.close);
      return cubit;
    }

    test('newest first, each open or resolved', () async {
      final cubit = open();

      await cubit.load();

      expect(cubit.state.status, ViewStatus.content);
      expect(cubit.state.reports.map((r) => r.id), ['rp-2', 'rp-1']);
      expect(cubit.state.reports.map((r) => r.status), [ReportStatus.resolved, ReportStatus.open]);
    });

    test('none is empty', () async {
      reports.mine = [];
      final cubit = open();

      await cubit.load();

      expect(cubit.state.status, ViewStatus.empty);
    });

    test('a failure is an error to retry', () async {
      reports.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = open();

      await cubit.load();

      expect(cubit.state.status, ViewStatus.error);
      expect(cubit.state.errorMessage, AppStrings.offlineActionError);
    });
  });
}
