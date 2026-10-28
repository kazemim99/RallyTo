import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../domain/entities/match.dart';
import '../match_labels.dart';

/// The design's game card (`.game-card`), shared by my games, the search's open posts and home's next game: the sport
/// ball, «تنیس در باشگاه انقلاب», the Jalali day and time, the status chip, a meta row with the club, the level range and
/// format (and the open spots while the game takes players), and who is in it as overlapping avatars («شما و …»).
/// A cancelled game shows the host's reason. [onTap] opens the game.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.sport, this.onTap, this.myId});

  final Match match;

  /// The game's sport from the catalog, for its level names.
  final Sport? sport;
  final VoidCallback? onTap;

  /// This player's user id, when known: names their partners exactly in the avatar caption.
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final levelAndFormat = MatchLabels.levelAndFormat(match, sport);
    final company = MatchLabels.company(match, myId: myId);
    final reason = match.cancelReason;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm - 2),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SportBall(label: MatchLabels.sportInitial(match.sport), semanticLabel: match.sport.name),
                const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(MatchLabels.cardTitle(match), style: theme.textTheme.titleSmall),
                      Text(MatchLabels.when(match), style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                MatchStatusChip(status: match.status),
              ],
            ),
            MetaRow(
              items: [
                MetaItem(match.venue.name, icon: Icons.place_outlined),
                if (levelAndFormat.isNotEmpty) MetaItem(levelAndFormat),
                if (match.status.isActive) MetaItem(MatchLabels.spots(match), icon: Icons.group_outlined),
              ],
            ),
            AvatarStack(names: company.names, caption: company.caption, size: AppAvatarSize.small),
            if (match.status == MatchStatus.cancelled && reason != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(AppStrings.cancelReason(reason), style: theme.textTheme.bodySmall?.copyWith(color: palette.error)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A game's status as the design's chip: green once confirmed or played, orange while it waits for players, red when
/// cancelled or disputed, neutral otherwise.
class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({super.key, required this.status});

  final MatchStatus status;

  static AppChipTone toneOf(MatchStatus status) => switch (status) {
    MatchStatus.confirmed || MatchStatus.completed => AppChipTone.green,
    MatchStatus.open || MatchStatus.pending => AppChipTone.orange,
    MatchStatus.cancelled || MatchStatus.disputed => AppChipTone.red,
    MatchStatus.expired || MatchStatus.unconfirmed => AppChipTone.neutral,
  };

  @override
  Widget build(BuildContext context) => AppChip(label: MatchLabels.status(status), tone: toneOf(status));
}
