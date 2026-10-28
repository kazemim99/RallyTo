import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../availability/presentation/widgets/availability_window_card.dart';
import '../../../ratings/presentation/widgets/reputation_widgets.dart';
import '../../../reports/domain/entities/report.dart';
import '../../domain/entities/player_profile.dart';
import '../bloc/player_profile_cubit.dart';
import '../profile_labels.dart';
import '../widgets/profile_widgets.dart';

/// What the player page's overflow menu offers.
enum _PlayerAction { block, report, reportPhoto }

/// Another player's page: a centred hero (avatar, name, age range • city • last activity, member since, the
/// reliability badge), the bio, one card per sport with its level, facts and the public reputation, home clubs and
/// active availability windows, with message and invite pinned at the bottom. Block (behind a confirmation) and
/// reporting the player or their photo are in the overflow menu. Needs a loaded [PlayerProfileCubit] above it.
class PlayerProfilePage extends StatelessWidget {
  const PlayerProfilePage({super.key});

  static const Key blockKey = Key('playerProfile.block');
  static const Key confirmBlockKey = Key('playerProfile.confirmBlock');
  static const Key inviteKey = Key('playerProfile.invite');
  static const Key messageKey = Key('playerProfile.message');
  static const Key moreKey = Key('playerProfile.more');
  static const Key reportKey = Key('playerProfile.report');
  static const Key reportPhotoKey = Key('playerProfile.reportPhoto');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayerProfileCubit>();
    return BlocConsumer<PlayerProfileCubit, PlayerProfileState>(
      listenWhen: (previous, current) =>
          current.blocked != previous.blocked ||
          (current.player != null && current.errorMessage != null && current.errorMessage != previous.errorMessage),
      listener: (context, state) {
        if (state.blocked) {
          AppSnackbar.success(context, AppStrings.blocked(state.player?.displayName ?? ''));
          final navigator = Navigator.of(context);
          navigator.canPop() ? navigator.pop() : context.go(Routes.home);
        } else if (state.errorMessage != null) {
          AppSnackbar.error(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        final player = state.player;
        final showContent = player != null && state.status == ViewStatus.content;
        return Scaffold(
          extendBody: showContent,
          appBar: AppBar(
            title: const Text(AppStrings.playerTitle),
            actions: [
              if (player != null)
                PopupMenuButton<_PlayerAction>(
                  key: moreKey,
                  tooltip: AppStrings.moreActions,
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) => switch (action) {
                    _PlayerAction.block => _confirmBlock(context, player),
                    _PlayerAction.report => _report(
                      context,
                      ReportTarget.player(player.userId, playerName: player.displayName),
                    ),
                    _PlayerAction.reportPhoto => _report(
                      context,
                      ReportTarget.photo(player.userId, playerName: player.displayName),
                    ),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      key: blockKey,
                      value: _PlayerAction.block,
                      enabled: !state.blocking,
                      child: const _MenuRow(icon: Icons.block_rounded, label: AppStrings.block, destructive: true),
                    ),
                    const PopupMenuItem(
                      key: reportKey,
                      value: _PlayerAction.report,
                      child: _MenuRow(icon: Icons.flag_outlined, label: AppStrings.reportPlayer),
                    ),
                    if (player.photoUrl != null)
                      const PopupMenuItem(
                        key: reportPhotoKey,
                        value: _PlayerAction.reportPhoto,
                        child: _MenuRow(icon: Icons.image_not_supported_outlined, label: AppStrings.reportPhoto),
                      ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: showContent
              ? StickyActions(
                  secondary: AppButton.secondary(
                    key: messageKey,
                    label: AppStrings.messageAction,
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => context.push(Routes.playerChatPath(player.userId), extra: player.displayName),
                  ),
                  primary: AppButton(
                    key: inviteKey,
                    label: AppStrings.inviteToGame,
                    icon: Icons.sports_tennis_rounded,
                    onPressed: () => context.push(Routes.invitePlayerPath(player.userId), extra: player.displayName),
                  ),
                )
              : null,
          body: state.status == ViewStatus.error && state.notFound
              ? EmptyState(
                  icon: Icons.person_off_outlined,
                  title: AppStrings.playerNotFound,
                  ctaLabel: AppStrings.backToHome,
                  onCta: () => context.go(Routes.home),
                )
              : StateSwitcher(
                  status: state.status,
                  errorMessage: state.errorMessage,
                  onRetry: cubit.load,
                  loading: const Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.screen),
                    child: SkeletonLines(count: 6),
                  ),
                  contentBuilder: (context) => _Content(state: state),
                ),
        );
      },
    );
  }

  /// Opens the report form; when the player was blocked in the same step, the page leaves as after a block.
  Future<void> _report(BuildContext context, ReportTarget target) async {
    final cubit = context.read<PlayerProfileCubit>();
    final blocked = await context.push<bool>(Routes.report, extra: target);
    if (blocked == true && !cubit.isClosed) cubit.blockedByReport();
  }

  Future<void> _confirmBlock(BuildContext context, PlayerProfile player) async {
    final cubit = context.read<PlayerProfileCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.blockQuestion(player.displayName)),
        content: const Text(AppStrings.blockExplanation),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(
            key: confirmBlockKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.block),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.block();
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.destructive = false});

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = destructive ? palette.error : palette.ink;
    return Row(
      children: [
        Icon(icon, size: AppIconSize.action, color: destructive ? palette.error : palette.muted),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final PlayerProfileState state;

  @override
  Widget build(BuildContext context) {
    final player = state.player!;
    final theme = Theme.of(context);
    final palette = context.palette;
    final lastActive = player.lastActive;
    final since = player.memberSince;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        StickyActions.contentPadding,
      ),
      children: [
        ProfileHero(
          avatar: AppAvatar(name: player.displayName, photoUrl: player.photoUrl, size: AppAvatarSize.xlarge),
          name: player.displayName,
          lines: [
            [
              ProfileLabels.ageRange(player.ageRange),
              player.city.name,
              if (lastActive != null) ProfileLabels.lastActive(lastActive),
            ].joinDisplay(),
            if (since != null) AppStrings.memberSince(JalaliDateText.yearMonth(since)),
          ],
          badge: switch (player.reputation?.reliability) {
            final tier? => ReliabilityBadge(tier: tier),
            null => null,
          },
        ),
        if (player.bio case final bio?) ...[ProfileBio(text: bio), const SizedBox(height: AppSpacing.sm)],
        for (final sport in player.sports) ...[
          SportProfileCard(
            sport: sport,
            sportName: ProfileLabels.sportName(sport.sportCode, state.sportNames),
            footer: switch (player.reputation?.forSport(sport.sportId)) {
              final reputation? => SportReputationSummary(reputation: reputation),
              null => null,
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (player.homeVenues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section - AppSpacing.sm),
          const SectionTitle(title: AppStrings.favoriteClubsTitle),
          for (final venue in player.homeVenues) ...[HomeClubRow(venue: venue), const SizedBox(height: AppSpacing.xs)],
        ],
        const SizedBox(height: AppSpacing.section - AppSpacing.sm),
        const SectionTitle(title: AppStrings.playerAvailabilityTitle),
        if (state.windows.isEmpty)
          Text(AppStrings.playerAvailabilityEmpty, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted))
        else
          for (final window in state.windows) AvailabilityWindowCard(window: window, sportNames: state.sportNames),
      ],
    );
  }
}
