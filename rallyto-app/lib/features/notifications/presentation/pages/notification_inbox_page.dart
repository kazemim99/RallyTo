import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/notification.dart';
import '../bloc/notification_inbox_cubit.dart';
import '../notification_labels.dart';

/// The notification inbox: newest first, unread ones marked, more on request; tapping one marks it read and opens
/// what it is about. Needs a loaded [NotificationInboxCubit] above it.
class NotificationInboxPage extends StatelessWidget {
  const NotificationInboxPage({super.key, this.clock});

  /// Now, for the entries' times (tests pass one).
  final DateTime Function()? clock;

  static const Key markAllReadKey = Key('notificationInbox.markAllRead');
  static const Key settingsKey = Key('notificationInbox.settings');
  static const Key loadMoreKey = Key('notificationInbox.loadMore');

  static Key itemKey(String id) => Key('notificationInbox.item.$id');

  static Key unreadDotKey(String id) => Key('notificationInbox.unread.$id');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationInboxCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notificationsTitle),
        actions: [
          BlocSelector<NotificationInboxCubit, NotificationInboxState, (bool, bool)>(
            selector: (state) => (state.hasUnread, state.busy),
            builder: (context, value) => TextButton(
              key: markAllReadKey,
              onPressed: value.$1 && !value.$2 ? cubit.markAllRead : null,
              child: const Text(AppStrings.markAllRead),
            ),
          ),
          IconButton(
            key: settingsKey,
            tooltip: AppStrings.notificationSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.notificationSettings),
          ),
        ],
      ),
      body: BlocConsumer<NotificationInboxCubit, NotificationInboxState>(
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
          empty: const EmptyState(
            icon: Icons.notifications_none_outlined,
            title: AppStrings.notificationsEmptyTitle,
            subtitle: AppStrings.notificationsEmptySubtitle,
          ),
          contentBuilder: (context) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
              children: [
                for (final notification in state.items)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
                    child: _NotificationTile(notification: notification, now: (clock ?? DateTime.now)()),
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                    child: AppButton.secondary(
                      key: loadMoreKey,
                      label: AppStrings.loadMore,
                      loading: state.loadingMore,
                      onPressed: cubit.loadMore,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry, as the design's `.list-row`: the category's icon in its tinted circle, the title (bold while unread), the
/// body and the time, and an unread dot. Unread entries sit on primarySoft with a green border.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.now});

  final AppNotification notification;
  final DateTime now;

  static IconData _icon(NotificationCategory category) => switch (category) {
    NotificationCategory.matches => Icons.sports_tennis,
    NotificationCategory.chat => Icons.chat_bubble_outline_rounded,
    NotificationCategory.ratings => Icons.star_outline_rounded,
    NotificationCategory.savedSearches => Icons.bookmarks_outlined,
    NotificationCategory.account => Icons.shield_outlined,
  };

  /// The icon's colour and its circle's fill.
  static (Color, Color) _colors(NotificationCategory category, AppPalette palette) => switch (category) {
    NotificationCategory.matches => (palette.primary, palette.primarySoft),
    NotificationCategory.chat => (palette.blue, palette.blueSoft),
    NotificationCategory.ratings => (palette.warning, palette.accentSoft),
    NotificationCategory.savedSearches => (palette.primary, palette.primarySoft),
    NotificationCategory.account => (palette.info, palette.infoSoft),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final unread = !notification.isRead;
    final (iconColor, iconFill) = _colors(notification.category, palette);
    return Material(
      key: NotificationInboxPage.itemKey(notification.id),
      color: unread ? palette.primarySoft : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: unread ? palette.primarySoftBorder : palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final location = await context.read<NotificationInboxCubit>().open(notification);
          if (location != null && context.mounted) await context.push(location);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: AppTouchTarget.min - AppSpacing.xs,
                    height: AppTouchTarget.min - AppSpacing.xs,
                    decoration: BoxDecoration(color: iconFill, shape: BoxShape.circle),
                    child: Icon(_icon(notification.category), size: AppIconSize.action, color: iconColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(notification.body, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        NotificationLabels.when(notification.createdAt, now: now),
                        style: theme.textTheme.labelSmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                    child: Semantics(
                      label: AppStrings.unreadNotification,
                      child: Container(
                        key: NotificationInboxPage.unreadDotKey(notification.id),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
