import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/presentation/match_labels.dart';

/// An open play post in the search results, as the design's `.open-post`: an orange chip with the open spots and
/// «تنیس • دونفره», the club, the day and time and the level range, then the host and «درخواست پیوستن» when this player
/// may still ask to join. The whole card opens the game, where joining happens.
class OpenPostCard extends StatelessWidget {
  const OpenPostCard({super.key, required this.match, required this.now, this.sport, this.onTap});

  final Match match;

  /// For whether the player may still ask to join.
  final DateTime now;

  /// The sport, for its own level names.
  final Sport? sport;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final levels = MatchLabels.levelRange(match.minLevel, match.maxLevel, sport);
    final mine = MatchLabels.myState(match.myState);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppChip(
                  label: AppStrings.openSpotsShort(PersianDigits.fromInt(match.openSpots)),
                  tone: AppChipTone.orange,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(MatchLabels.title(match), textAlign: TextAlign.end, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(match.venue.name, style: theme.textTheme.titleMedium),
            MetaRow(
              items: [
                MetaItem(MatchLabels.when(match), icon: Icons.schedule_rounded),
                if (levels.isNotEmpty) MetaItem(levels),
              ],
            ),
            Row(
              children: [
                AppAvatar(name: match.host.displayName, size: AppAvatarSize.small),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    AppStrings.postHost(match.host.displayName),
                    style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
                if (match.canJoin(now))
                  Text(
                    AppStrings.join,
                    style: theme.textTheme.labelMedium?.copyWith(color: palette.primary, fontWeight: FontWeight.w700),
                  )
                else if (mine != null)
                  AppChip(label: mine, tone: AppChipTone.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
