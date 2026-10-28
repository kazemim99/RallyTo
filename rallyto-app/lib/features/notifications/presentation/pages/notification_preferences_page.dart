import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/notification_rules.dart';
import '../bloc/notification_preferences_cubit.dart';
import '../notification_labels.dart';

/// Push switches per category in one card (account notifications always on, shown disabled with why) and the quiet
/// hours in another, in 30-minute steps on Tehran's clock; the window may run past midnight. Needs a loaded
/// [NotificationPreferencesCubit] above it.
class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  static const Key matchesKey = Key('notificationPreferences.matches');
  static const Key chatKey = Key('notificationPreferences.chat');
  static const Key ratingsKey = Key('notificationPreferences.ratings');
  static const Key savedSearchesKey = Key('notificationPreferences.savedSearches');
  static const Key accountKey = Key('notificationPreferences.account');
  static const Key quietKey = Key('notificationPreferences.quiet');
  static const Key quietStartKey = Key('notificationPreferences.quietStart');
  static const Key quietEndKey = Key('notificationPreferences.quietEnd');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationPreferencesCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notificationSettingsTitle)),
      body: BlocConsumer<NotificationPreferencesCubit, NotificationPreferencesState>(
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
          contentBuilder: (context) => _Content(state: state),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final NotificationPreferencesState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationPreferencesCubit>();
    final p = state.preferences;
    final enabled = !state.saving;
    const divider = Divider(height: 1);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
      children: [
        const SectionTitle(title: AppStrings.pushSectionTitle, subtitle: AppStrings.pushSectionHint),
        AppCard(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
          child: Column(
            children: [
              AppSwitchRow(
                key: NotificationPreferencesPage.matchesKey,
                title: AppStrings.pushMatches,
                value: p.pushMatches,
                onChanged: enabled ? cubit.setPushMatches : null,
              ),
              divider,
              AppSwitchRow(
                key: NotificationPreferencesPage.chatKey,
                title: AppStrings.pushChat,
                value: p.pushChat,
                onChanged: enabled ? cubit.setPushChat : null,
              ),
              divider,
              AppSwitchRow(
                key: NotificationPreferencesPage.ratingsKey,
                title: AppStrings.pushRatings,
                value: p.pushRatings,
                onChanged: enabled ? cubit.setPushRatings : null,
              ),
              divider,
              AppSwitchRow(
                key: NotificationPreferencesPage.savedSearchesKey,
                title: AppStrings.pushSavedSearches,
                value: p.pushSavedSearches,
                onChanged: enabled ? cubit.setPushSavedSearches : null,
              ),
              divider,
              // Always delivered: shown on, and disabled, with the reason.
              const AppSwitchRow(
                key: NotificationPreferencesPage.accountKey,
                title: AppStrings.pushAccount,
                subtitle: AppStrings.pushAccountHint,
                value: true,
                onChanged: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSwitchRow(
                key: NotificationPreferencesPage.quietKey,
                title: AppStrings.quietHoursTitle,
                subtitle: AppStrings.quietHoursHint,
                value: p.quietHoursEnabled,
                onChanged: enabled ? cubit.setQuietHoursEnabled : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      key: NotificationPreferencesPage.quietStartKey,
                      label: AppStrings.quietStart,
                      minute: p.quietStartMinute,
                      onChanged: enabled && p.quietHoursEnabled ? cubit.setQuietStart : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TimeField(
                      key: NotificationPreferencesPage.quietEndKey,
                      label: AppStrings.quietEnd,
                      minute: p.quietEndMinute,
                      onChanged: enabled && p.quietHoursEnabled ? cubit.setQuietEnd : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A quiet-hours boundary, picked from 00:00 to 23:30 in 30-minute steps.
class _TimeField extends StatelessWidget {
  const _TimeField({super.key, required this.label, required this.minute, required this.onChanged});

  final String label;
  final int minute;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      // Rebuilt for every value, so a change the server refused shows the saved time again.
      key: ValueKey(minute),
      initialValue: minute,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in QuietHoursRules.options)
          DropdownMenuItem(value: option, child: Text(NotificationLabels.minute(option))),
      ],
      onChanged: onChanged == null ? null : (value) => value == null ? null : onChanged!(value),
    );
  }
}
