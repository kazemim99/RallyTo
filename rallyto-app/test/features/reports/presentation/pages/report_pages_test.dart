import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/utils/persian_digits.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/my_reports_cubit.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/report_form_cubit.dart';
import 'package:rallyto_app/features/reports/presentation/pages/my_reports_page.dart';
import 'package:rallyto_app/features/reports/presentation/pages/report_form_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_reports.dart';
import '../../../../helpers/router_shell.dart';

/// The report form (reason, details, "block this player too") closing with whether the player was blocked, and
/// «گزارش‌های من» showing each report open or resolved, never the action taken.
void main() {
  late FakeReportRepository reports;

  setUp(() => reports = FakeReportRepository());

  group('the report form', () {
    late List<Object?> closedWith;

    setUp(() => closedWith = []);

    Future<void> show(WidgetTester tester, ReportTarget target) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpRouter(tester, [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async => closedWith.add(await context.push<bool>('/report')),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/report',
          builder: (context, state) =>
              BlocProvider(create: (_) => ReportFormCubit(reports, target), child: const ReportFormPage()),
        ),
      ]);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('every reason in Persian, details, and blocking the named player', (tester) async {
      await show(tester, const ReportTarget.player('u-2', playerName: 'علی'));

      expect(find.text(AppStrings.reportPlayerTitle), findsOneWidget);
      for (final reason in [
        AppStrings.reasonHarassment,
        AppStrings.reasonInappropriateContent,
        AppStrings.reasonFakeProfile,
        AppStrings.reasonSpam,
        AppStrings.reasonUnsafeBehaviour,
        AppStrings.reasonUnderage,
        AppStrings.reasonOther,
      ]) {
        expect(find.text(reason), findsOneWidget);
      }
      expect(find.text(AppStrings.reportBlockNamed('علی')), findsOneWidget);
    });

    for (final (target, title) in [
      (const ReportTarget.message('msg-1'), AppStrings.reportMessageTitle),
      (const ReportTarget.post('m-1'), AppStrings.reportPostTitle),
      (const ReportTarget.photo('u-2'), AppStrings.reportPhotoTitle),
    ]) {
      testWidgets('a ${target.type.wire} report is titled «$title»', (tester) async {
        await show(tester, target);

        expect(find.text(title), findsOneWidget);
        expect(find.text(AppStrings.reportBlockLabel), findsOneWidget, reason: 'no name: "this player"');
      });
    }

    testWidgets('a report with "block this player too" is filed, and the form closes with true', (tester) async {
      await show(tester, const ReportTarget.message('msg-1', senderName: 'علی'));

      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.harassment)));
      await tester.enterText(find.byKey(ReportFormPage.detailsKey), 'پیام توهین‌آمیز');
      await tester.tap(find.byKey(ReportFormPage.blockKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(reports.filed, [
        const ReportDraft(
          target: ReportTarget.message('msg-1', senderName: 'علی'),
          reason: ReportReason.harassment,
          details: 'پیام توهین‌آمیز',
          block: true,
        ),
      ]);
      expect(find.byType(ReportFormPage), findsNothing);
      expect(closedWith, [true]);
      expect(find.text(AppStrings.reportSentAndBlocked), findsOneWidget);
    });

    testWidgets('without blocking, the form closes with false', (tester) async {
      await show(tester, const ReportTarget.post('m-1'));

      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.spam)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(closedWith, [false]);
      expect(find.text(AppStrings.reportSent), findsOneWidget);
    });

    testWidgets('the reasons are single-choice cards, and the details count up in Persian digits', (tester) async {
      await show(tester, const ReportTarget.player('u-2'));

      expect(find.text(AppStrings.reportDetailsCount('۰', PersianDigits.fromInt(1000))), findsOneWidget);
      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.spam)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.harassment)));
      await tester.enterText(find.byKey(ReportFormPage.detailsKey), 'سلام');
      await tester.pumpAndSettle();

      expect(tester.widget<RadioCard>(find.byKey(ReportFormPage.reasonKey(ReportReason.harassment))).selected, isTrue);
      expect(tester.widget<RadioCard>(find.byKey(ReportFormPage.reasonKey(ReportReason.spam))).selected, isFalse);
      expect(find.text(AppStrings.reportDetailsCount('۴', PersianDigits.fromInt(1000))), findsOneWidget);
      expect(find.byType(StickyActions), findsOneWidget, reason: 'submit is pinned at the bottom');
    });

    testWidgets('no reason is said before sending', (tester) async {
      await show(tester, const ReportTarget.player('u-2'));

      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportReasonRequired), findsOneWidget);
      expect(reports.filed, isEmpty);
    });

    testWidgets('ALREADY_REPORTED is said and the form stays', (tester) async {
      reports.failure = const ServerFailure('x', code: 'ALREADY_REPORTED', statusCode: 409);
      await show(tester, const ReportTarget.player('u-2'));

      await tester.tap(find.byKey(ReportFormPage.reasonKey(ReportReason.fakeProfile)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReportFormPage.submitKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.alreadyReported), findsOneWidget);
      expect(find.byType(ReportFormPage), findsOneWidget);
      expect(closedWith, isEmpty);
    });
  });

  group('my reports', () {
    Future<void> show(WidgetTester tester) async {
      final cubit = MyReportsCubit(reports);
      addTearDown(cubit.close);
      await cubit.load();
      await pumpInShell(tester, BlocProvider.value(value: cubit, child: const MyReportsPage()));
    }

    testWidgets('each report: what, why, when, and open or resolved; never the action taken', (tester) async {
      await show(tester);

      expect(find.text(AppStrings.myReportsHint), findsOneWidget);
      expect(find.text('${AppStrings.reportTargetMessage} ‏•‏ ${AppStrings.reasonSpam}'), findsOneWidget);
      expect(find.text('${AppStrings.reportTargetPlayer} ‏•‏ ${AppStrings.reasonHarassment}'), findsOneWidget);
      expect(find.text(AppStrings.reportStatusResolved), findsOneWidget);
      expect(find.text(AppStrings.reportStatusOpen), findsOneWidget);
      expect(find.textContaining('مهر ۱۴۰۵'), findsNWidgets(2), reason: 'Jalali dates');
      final first = tester.getTopLeft(find.byKey(MyReportsPage.reportKey('rp-2'))).dy;
      final second = tester.getTopLeft(find.byKey(MyReportsPage.reportKey('rp-1'))).dy;
      expect(first, lessThan(second), reason: 'newest first');
    });

    testWidgets('none: says so', (tester) async {
      reports.mine = [];
      await show(tester);

      expect(find.text(AppStrings.myReportsEmpty), findsOneWidget);
    });

    testWidgets('a failure can be retried', (tester) async {
      reports.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      await show(tester);
      expect(find.text(AppStrings.offlineActionError), findsOneWidget);

      reports.loadFailure = null;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportStatusOpen), findsOneWidget);
    });
  });
}
