import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/availability_window.dart';
import '../availability_labels.dart';
import '../bloc/availability_list_cubit.dart';
import '../widgets/availability_window_card.dart';

/// The player's availability windows grouped by status (active, paused, expired), each a card with its status chip and
/// actions; a dashed button to add one. Active weekly cards show the day they pause themselves; a window the server
/// says needs reconfirming gets a warning chip and a prominent «هنوز آزادم», and a reminder above the list names the
/// first pause day. Needs a loaded [AvailabilityListCubit] above it.
class AvailabilityListPage extends StatelessWidget {
  const AvailabilityListPage({super.key});

  static const Key addKey = Key('availability.add');
  static const Key reconfirmNoticeKey = Key('availability.reconfirmNotice');

  static Key sectionKey(AvailabilityStatus status) => Key('availability.section.${status.name}');

  static Key windowKey(String id) => Key('availability.window.$id');

  static Key pauseKey(String id) => Key('availability.pause.$id');

  static Key resumeKey(String id) => Key('availability.resume.$id');

  static Key confirmKey(String id) => Key('availability.confirm.$id');

  static Key editKey(String id) => Key('availability.edit.$id');

  static Key deleteKey(String id) => Key('availability.delete.$id');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvailabilityListCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.availabilityTitle)),
      body: BlocConsumer<AvailabilityListCubit, AvailabilityListState>(
        listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
        listener: (context, state) {
          final feedback = state.feedback!;
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        },
        builder: (context, state) => StateSwitcher(
          status: state.status,
          errorMessage: state.errorMessage,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines()),
          empty: EmptyState(
            icon: Icons.event_available_outlined,
            title: AppStrings.availabilityEmptyTitle,
            subtitle: AppStrings.availabilityEmptySubtitle,
            ctaLabel: AppStrings.availabilityAdd,
            onCta: () => _openForm(context, null),
          ),
          contentBuilder: (context) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
            children: [
              DashedButton(key: addKey, label: AppStrings.availabilityAdd, onPressed: () => _openForm(context, null)),
              if (_needingReconfirmation(state.windows) case final due when due.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                NoticeBanner(
                  key: reconfirmNoticeKey,
                  tone: NoticeTone.warning,
                  icon: Icons.schedule_rounded,
                  title: AppStrings.reconfirmTitle,
                  body: AvailabilityLabels.pauseNotice(due),
                ),
              ],
              for (final MapEntry(key: status, value: windows) in state.byStatus.entries) ...[
                const SizedBox(height: AppSpacing.section),
                SectionTitle(
                  key: sectionKey(status),
                  title: '${AvailabilityLabels.status(status)} (${PersianDigits.fromInt(windows.length)})',
                ),
                for (final window in windows)
                  AvailabilityWindowCard(
                    key: windowKey(window.id),
                    window: window,
                    sportNames: state.sportNames,
                    showPauseDay: true,
                    actions: _actions(context, window, busy: state.busyId != null),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, AvailabilityWindow window, {required bool busy}) {
    final cubit = context.read<AvailabilityListCubit>();
    final id = window.id;
    return [
      // Only where it matters now: the windows the server says pause themselves soon unless confirmed.
      if (window.needsReconfirmation && window.status == AvailabilityStatus.active)
        AppButton(
          key: confirmKey(id),
          label: AppStrings.confirmStillAvailable,
          icon: Icons.check_rounded,
          compact: true,
          expanded: false,
          onPressed: busy ? null : () => cubit.confirm(window),
        ),
      if (window.status == AvailabilityStatus.active)
        AppButton.ghost(
          key: pauseKey(id),
          label: AppStrings.pause,
          icon: Icons.pause_rounded,
          compact: true,
          expanded: false,
          onPressed: busy ? null : () => cubit.pause(window),
        ),
      if (window.status == AvailabilityStatus.paused)
        AppButton.secondary(
          key: resumeKey(id),
          label: AppStrings.resume,
          icon: Icons.play_arrow_rounded,
          compact: true,
          expanded: false,
          onPressed: busy ? null : () => cubit.resume(window),
        ),
      IconButton(
        key: editKey(id),
        tooltip: AppStrings.editProfile,
        icon: const Icon(Icons.edit_outlined),
        onPressed: busy ? null : () => _openForm(context, window),
      ),
      IconButton(
        key: deleteKey(id),
        tooltip: AppStrings.remove,
        icon: Icon(Icons.delete_outline_rounded, color: context.palette.error),
        onPressed: busy ? null : () => _confirmDelete(context, window),
      ),
    ];
  }

  static List<AvailabilityWindow> _needingReconfirmation(List<AvailabilityWindow> windows) => [
    for (final w in windows)
      if (w.needsReconfirmation && w.status == AvailabilityStatus.active) w,
  ];

  Future<void> _openForm(BuildContext context, AvailabilityWindow? window) async {
    final cubit = context.read<AvailabilityListCubit>();
    final saved = window == null
        ? await context.push<AvailabilityWindow>(Routes.availabilityNew)
        : await context.push<AvailabilityWindow>(Routes.availabilityEdit, extra: window);
    if (saved != null) cubit.saved(saved);
  }

  Future<void> _confirmDelete(BuildContext context, AvailabilityWindow window) async {
    final cubit = context.read<AvailabilityListCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(AppStrings.availabilityDeleteQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text(AppStrings.remove)),
        ],
      ),
    );
    if (confirmed == true) await cubit.delete(window);
  }
}
