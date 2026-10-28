import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/tehran_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/report.dart';
import '../bloc/my_reports_cubit.dart';
import '../report_labels.dart';

/// «گزارش‌های من»: what this player reported and why, when, and whether it is still open, as rows with a status chip.
/// Never the action taken. Needs a loaded [MyReportsCubit] above it.
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  static Key reportKey(String id) => Key('myReports.report.$id');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MyReportsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myReportsTitle)),
      body: BlocBuilder<MyReportsCubit, MyReportsState>(
        builder: (context, state) => StateSwitcher(
          status: state.status,
          errorMessage: state.errorMessage,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines()),
          empty: const EmptyState(
            icon: Icons.flag_outlined,
            title: AppStrings.myReportsEmpty,
            subtitle: AppStrings.myReportsHint,
          ),
          contentBuilder: (context) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.xxs,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  AppStrings.myReportsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final report in state.reports) ...[
                  _ReportRow(report: report),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final type = report.targetType;
    final reason = report.reason;
    final createdAt = report.createdAt;
    final open = report.status == ReportStatus.open;
    return ListRow(
      key: MyReportsPage.reportKey(report.id),
      leading: const Icon(Icons.flag_outlined),
      title: [
        if (type != null) ReportLabels.targetType(type),
        if (reason != null) ReportLabels.reason(reason),
      ].joinDisplay(),
      subtitle: createdAt == null ? null : AppStrings.reportedOn(tehranWallClock(createdAt).formatPersianFull()),
      trailing: AppChip(
        label: ReportLabels.status(report.status),
        tone: open ? AppChipTone.orange : AppChipTone.green,
        icon: open ? Icons.schedule_rounded : Icons.check_circle_outline_rounded,
      ),
    );
  }
}
