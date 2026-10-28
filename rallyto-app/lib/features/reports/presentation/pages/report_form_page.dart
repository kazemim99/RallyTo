import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/report.dart';
import '../../domain/report_rules.dart';
import '../bloc/report_form_cubit.dart';
import '../report_labels.dart';

/// Reporting a player, a message, a play post or a profile photo: a reason (one choice of a list of cards), optional
/// details with a counter, "block this player too", and the submit button pinned at the bottom. Closes once filed with
/// whether the player was blocked (`true`), so the screen behind can leave or refresh. Needs a [ReportFormCubit] above
/// it.
class ReportFormPage extends StatelessWidget {
  const ReportFormPage({super.key});

  static const Key detailsKey = Key('reportForm.details');
  static const Key blockKey = Key('reportForm.block');
  static const Key submitKey = Key('reportForm.submit');

  static Key reasonKey(ReportReason reason) => Key('reportForm.reason.${reason.wire}');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportFormCubit>();
    final type = cubit.state.target.type;
    return BlocConsumer<ReportFormCubit, ReportFormState>(
      listenWhen: (previous, current) =>
          (current.feedback != null && !identical(previous.feedback, current.feedback)) ||
          (current.done && !previous.done),
      listener: (context, state) {
        final feedback = state.feedback;
        if (feedback != null) {
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        }
        if (state.done) {
          final navigator = Navigator.of(context);
          navigator.canPop() ? navigator.pop(state.block) : context.go(Routes.home);
        }
      },
      builder: (context, state) => Scaffold(
        extendBody: true,
        appBar: AppBar(title: Text(ReportLabels.formTitle(type))),
        bottomNavigationBar: StickyActions(
          primary: AppButton(
            key: submitKey,
            label: AppStrings.submitReport,
            icon: Icons.flag_outlined,
            loading: state.submitting,
            onPressed: state.done ? null : cubit.submit,
          ),
        ),
        body: _Form(state: state),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final ReportFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportFormCubit>();
    final theme = Theme.of(context);
    final palette = context.palette;
    final label = theme.textTheme.labelMedium;
    final name = state.target.playerName?.trim();
    final enabled = !state.submitting;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        StickyActions.contentPadding,
      ),
      children: [
        Semantics(header: true, child: Text(AppStrings.reportReasonLabel, style: label)),
        const SizedBox(height: AppSpacing.xs),
        for (final reason in ReportReason.values) ...[
          RadioCard(
            key: ReportFormPage.reasonKey(reason),
            title: ReportLabels.reason(reason),
            selected: state.reason == reason,
            onTap: enabled ? () => cubit.setReason(reason) : null,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.reportDetailsLabel, style: label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: ReportFormPage.detailsKey,
          maxLength: ReportRules.maxDetailsLength,
          minLines: 3,
          maxLines: 6,
          enabled: enabled,
          onChanged: cubit.setDetails,
          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => Text(
            AppStrings.reportDetailsCount(
              PersianDigits.fromInt(currentLength),
              PersianDigits.fromInt(maxLength ?? ReportRules.maxDetailsLength),
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
          child: AppSwitchRow(
            key: ReportFormPage.blockKey,
            title: name == null || name.isEmpty ? AppStrings.reportBlockLabel : AppStrings.reportBlockNamed(name),
            subtitle: AppStrings.reportBlockHint,
            value: state.block,
            onChanged: enabled ? cubit.setBlock : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(tone: NoticeTone.info, icon: Icons.info_outline_rounded, body: AppStrings.reportReviewHint),
      ],
    );
  }
}
