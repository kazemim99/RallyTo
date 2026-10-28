import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/tehran_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/blocked_players_cubit.dart';

/// The players this player blocked, as rows with an unblock action. Needs a loaded [BlockedPlayersCubit] above it.
class BlockedPlayersPage extends StatelessWidget {
  const BlockedPlayersPage({super.key});

  static Key unblockKey(String userId) => Key('blockedPlayers.unblock.$userId');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BlockedPlayersCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.blockedPlayersTitle)),
      body: BlocConsumer<BlockedPlayersCubit, BlockedPlayersState>(
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
            icon: Icons.block_rounded,
            title: AppStrings.blockedPlayersEmpty,
            subtitle: AppStrings.blockedPlayersSubtitle,
          ),
          contentBuilder: (context) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screen,
              AppSpacing.xxs,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            children: [
              Text(
                AppStrings.blockedPlayersSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final player in state.players) ...[
                ListRow(
                  leading: AppAvatar(name: player.displayName),
                  title: player.displayName,
                  subtitle: player.blockedAt == null
                      ? null
                      : AppStrings.blockedOn(tehranWallClock(player.blockedAt!).formatPersianFull()),
                  trailing: AppButton.ghost(
                    key: unblockKey(player.userId),
                    label: AppStrings.unblock,
                    compact: true,
                    loading: state.busyId == player.userId,
                    onPressed: state.busyId == null ? () => cubit.unblock(player) : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
