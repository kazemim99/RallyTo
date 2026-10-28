import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../chat/domain/entities/chat.dart';
import '../../../chat/presentation/bloc/chat_badge_cubit.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/presentation/match_labels.dart';
import '../../../notifications/presentation/bloc/notification_badge_cubit.dart';
import '../bloc/home_cubit.dart';
import '../home_labels.dart';

/// Home for a signed-in, onboarded player: a greeting with the notification bell (and its unread badge), the way to
/// a partner, quick actions (search, post a game, availability with its active-window count), the next game, what
/// waits on them (invitations, join requests, attendance, ratings, unread messages) and the "still free?" reminder.
///
/// Needs a started [ChatBadgeCubit] and [NotificationBadgeCubit] above it. It builds its own [HomeCubit] from the app's
/// repositories unless one is provided above it.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Key availabilityKey = Key('home.availability');
  static const Key searchKey = Key('home.search');
  static const Key quickSearchKey = Key('home.quickSearch');
  static const Key postKey = Key('home.post');
  static const Key matchesKey = Key('home.matches');
  static const Key nextGameKey = Key('home.nextGame');
  static const Key chatKey = Key('home.chat');
  static const Key chatBadgeKey = Key('home.chatBadge');
  static const Key notificationsKey = Key('home.notifications');
  static const Key notificationsBadgeKey = Key('home.notificationsBadge');
  static const Key reconfirmKey = Key('home.reconfirm');

  static Key taskKey(HomeTask task) => Key('home.task.${task.kind.name}.${task.match.id}');

  /// The tabs [goTab] switches to, in the bar's order.
  static const int searchTab = 1;
  static const int matchesTab = 2;
  static const int chatTab = 3;

  @override
  Widget build(BuildContext context) {
    if (context.read<HomeCubit?>() != null) return const _HomeView();
    return BlocProvider(create: (_) => HomeCubit.fromLocator()..load(), child: const _HomeView());
  }

  /// Opens [location] on this tab, then re-reads the badges and home: the player may have read or changed things there.
  static Future<void> open(BuildContext context, String location) async {
    final chat = context.read<ChatBadgeCubit>();
    final notifications = context.read<NotificationBadgeCubit>();
    final home = context.read<HomeCubit>();
    await context.push(location);
    if (!chat.isClosed) unawaited(chat.refresh());
    if (!notifications.isClosed) unawaited(notifications.refresh());
    if (!home.isClosed) unawaited(home.load());
  }

  /// Switches to the tab [index] whose root is [location]. Outside the tab shell (a bare home), opens it instead.
  static void goTab(BuildContext context, int index, String location) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(index);
    } else {
      unawaited(open(context, location));
    }
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<HomeCubit, HomeState>(
          listenWhen: (previous, current) =>
              current.feedback != null && !identical(previous.feedback, current.feedback),
          listener: (context, state) {
            final feedback = state.feedback!;
            feedback.isError
                ? AppSnackbar.error(context, feedback.message)
                : AppSnackbar.success(context, feedback.message);
          },
          builder: (context, state) => RefreshIndicator(
            onRefresh: () async {
              unawaited(context.read<ChatBadgeCubit>().refresh());
              unawaited(context.read<NotificationBadgeCubit>().refresh());
              await cubit.load();
            },
            // A short, fixed page: built whole (not lazily), so every section and its badge exist at once.
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(name: state.name, now: cubit.now),
                  const SizedBox(height: AppSpacing.md),
                  HeroCard(
                    eyebrow: AppStrings.homeHeroEyebrow,
                    title: AppStrings.homeHeroTitle,
                    cta: AppButton.inverse(
                      key: HomePage.searchKey,
                      label: AppStrings.homeHeroCta,
                      onPressed: () => HomePage.goTab(context, HomePage.searchTab, Routes.search),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const SectionTitle(title: AppStrings.quickActionsTitle),
                  _QuickActions(activeWindows: state.activeWindowCount),
                  const SizedBox(height: AppSpacing.section),
                  _SectionHeader(
                    title: AppStrings.nextGameTitle,
                    actionKey: HomePage.matchesKey,
                    actionLabel: AppStrings.viewAll,
                    onAction: () => HomePage.goTab(context, HomePage.matchesTab, Routes.matches),
                  ),
                  _NextGame(state: state),
                  _Pending(tasks: state.tasks),
                  if (state.showReconfirm) ...[
                    const SizedBox(height: AppSpacing.section),
                    NoticeBanner(
                      key: HomePage.reconfirmKey,
                      icon: Icons.schedule_rounded,
                      title: HomeLabels.reconfirmTitle(state.reconfirmCandidates),
                      body: HomeLabels.reconfirmBody(state.reconfirmCandidates),
                      actionLabel: AppStrings.confirmStillAvailable,
                      onAction: state.reconfirming ? null : cubit.reconfirm,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The greeting for the time of day, the player's name, and the notification bell with its unread badge.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.now});

  final String? name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final unread = context.watch<NotificationBadgeCubit>().state;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(HomeLabels.greeting(now), style: theme.textTheme.labelMedium?.copyWith(color: palette.muted)),
              Semantics(header: true, child: Text(HomeLabels.headline(name), style: theme.textTheme.headlineSmall)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: palette.surface,
          shape: CircleBorder(side: BorderSide(color: palette.line)),
          child: IconButton(
            key: HomePage.notificationsKey,
            tooltip: AppStrings.notificationsTitle,
            icon: AppBadge(
              key: HomePage.notificationsBadgeKey,
              count: unread,
              child: Icon(Icons.notifications_outlined, color: palette.ink),
            ),
            onPressed: () => HomePage.open(context, Routes.notifications),
          ),
        ),
      ],
    );
  }
}

/// A section heading with its action link, the link keyed for tests.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionKey, required this.actionLabel, this.onAction});

  final String title;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: SectionTitle(title: title)),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxs),
          child: TextButton(
            key: actionKey,
            onPressed: onAction,
            style: TextButton.styleFrom(
              textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
            ),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.activeWindows});

  /// Null while unknown.
  final int? activeWindows;

  @override
  Widget build(BuildContext context) {
    final count = activeWindows;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: QuickActionTile(
              key: HomePage.quickSearchKey,
              icon: Icons.search_rounded,
              label: AppStrings.searchTitle,
              caption: AppStrings.quickSearchCaption,
              onTap: () => HomePage.goTab(context, HomePage.searchTab, Routes.search),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: QuickActionTile(
              key: HomePage.postKey,
              icon: Icons.add_rounded,
              label: AppStrings.quickPost,
              caption: AppStrings.quickPostCaption,
              tone: QuickActionTone.orange,
              onTap: () => HomePage.open(context, Routes.matchNew),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: QuickActionTile(
              key: HomePage.availabilityKey,
              icon: Icons.schedule_rounded,
              label: AppStrings.quickAvailability,
              caption: count != null && count > 0
                  ? AppStrings.activeWindows(PersianDigits.fromInt(count))
                  : AppStrings.quickAvailabilityCaption,
              tone: QuickActionTone.blue,
              onTap: () => HomePage.open(context, Routes.availability),
            ),
          ),
        ],
      ),
    );
  }
}

/// The next game: a skeleton while it loads, the game card, an invitation to find one, or the error with a retry.
class _NextGame extends StatelessWidget {
  const _NextGame({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return switch (state.gamesStatus) {
      ViewStatus.loading => const AppCard(child: SkeletonLines()),
      ViewStatus.error => NoticeBanner(
        tone: NoticeTone.error,
        body: state.gamesError ?? AppStrings.genericError,
        actionLabel: AppStrings.retry,
        onAction: context.read<HomeCubit>().load,
      ),
      ViewStatus.empty => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.nextGameEmptyTitle, style: theme.textTheme.titleMedium),
            Text(AppStrings.nextGameEmptySubtitle, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
            const SizedBox(height: AppSpacing.sm),
            DashedButton(label: AppStrings.quickPost, onPressed: () => HomePage.open(context, Routes.matchNew)),
          ],
        ),
      ),
      ViewStatus.content => _NextGameCard(match: state.nextGame!),
    };
  }
}

class _NextGameCard extends StatelessWidget {
  const _NextGameCard({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final players = match.players;
    final levels = MatchLabels.levelRange(match.minLevel, match.maxLevel);
    final code = match.sport.code;
    return AppCard(
      key: HomePage.nextGameKey,
      onTap: () => HomePage.open(context, Routes.matchPath(match.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SportBall(label: code.isEmpty ? '' : code.substring(0, 1).toUpperCase(), semanticLabel: match.sport.name),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(MatchLabels.title(match), style: theme.textTheme.titleMedium),
                    Text(MatchLabels.when(match), style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppChip(
                label: MatchLabels.status(match.status),
                tone: match.status == MatchStatus.confirmed ? AppChipTone.green : AppChipTone.orange,
              ),
            ],
          ),
          MetaRow(
            items: [
              MetaItem(match.venue.name, icon: Icons.place_outlined),
              if (levels.isNotEmpty) MetaItem(levels),
            ],
          ),
          if (players.isNotEmpty)
            AvatarStack(
              names: [for (final p in players) p.displayName],
              caption: players.map((p) => p.displayName).join('، '),
            ),
        ],
      ),
    );
  }
}

/// What waits on the player: unread messages, then the games' pending actions. Nothing when nothing waits.
class _Pending extends StatelessWidget {
  const _Pending({required this.tasks});

  final List<HomeTask> tasks;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatBadgeCubit>().state;
    if (chat.total <= 0 && tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        const SectionTitle(title: AppStrings.pendingTitle),
        if (chat.total > 0) _MessagesRow(unread: chat),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: ListRow(
              key: HomePage.taskKey(task),
              leading: Icon(_icon(task.kind)),
              title: HomeLabels.taskTitle(task),
              subtitle: HomeLabels.taskSubtitle(task),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => HomePage.open(context, Routes.matchPath(task.match.id)),
            ),
          ),
      ],
    );
  }

  static IconData _icon(HomeTaskKind kind) => switch (kind) {
    HomeTaskKind.invitation => Icons.mail_outline_rounded,
    HomeTaskKind.requests => Icons.group_add_outlined,
    HomeTaskKind.attendance => Icons.fact_check_outlined,
    HomeTaskKind.rating => Icons.star_outline_rounded,
  };
}

class _MessagesRow extends StatelessWidget {
  const _MessagesRow({required this.unread});

  final ChatUnreadCounts unread;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (unread.conversations > 0) AppStrings.unreadConversations(PersianDigits.fromInt(unread.conversations)),
      if (unread.requests > 0) AppStrings.unreadChatRequests(PersianDigits.fromInt(unread.requests)),
    ].joinDisplay();
    return ListRow(
      key: HomePage.chatKey,
      leading: const Icon(Icons.chat_bubble_outline_rounded),
      title: AppStrings.pendingMessages,
      subtitle: detail.isEmpty ? null : detail,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(key: HomePage.chatBadgeKey, count: unread.total),
          const SizedBox(width: AppSpacing.xxs),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => HomePage.goTab(context, HomePage.chatTab, Routes.chat),
    );
  }
}
