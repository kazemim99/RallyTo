import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/rating.dart';
import '../rating_labels.dart';

/// A player's reliability tier as the design's chip: «تازه‌وارد» (neutral), or «خوش‌قولی: خوب» (green for good and
/// high, orange for low). Never the score.
class ReliabilityBadge extends StatelessWidget {
  const ReliabilityBadge({super.key, required this.tier});

  static const Key badgeKey = Key('reputation.reliability');

  final ReliabilityTier tier;

  static AppChipTone toneOf(ReliabilityTier tier) => switch (tier) {
    ReliabilityTier.newPlayer => AppChipTone.neutral,
    ReliabilityTier.low => AppChipTone.orange,
    ReliabilityTier.good || ReliabilityTier.high => AppChipTone.green,
  };

  @override
  Widget build(BuildContext context) {
    final icon = switch (tier) {
      ReliabilityTier.newPlayer => Icons.eco_outlined,
      ReliabilityTier.low => Icons.schedule_outlined,
      ReliabilityTier.good || ReliabilityTier.high => Icons.verified_user_outlined,
    };
    return AppChip(key: badgeKey, label: RatingLabels.reliability(tier), tone: toneOf(tier), icon: icon);
  }
}

/// The design's `.rating` on a player card: a gold star, the average «۴٫۸» and a muted «(۱۸ امتیاز)»; or «بازیکن جدید»
/// when [average] is null (below 3 revealed ratings).
class StarRatingLine extends StatelessWidget {
  const StarRatingLine({super.key, required this.average, required this.count});

  static const Key lineKey = Key('reputation.starLine');

  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final value = average;
    if (value == null) {
      return Row(
        key: lineKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.eco_outlined, size: AppIconSize.meta, color: palette.muted),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              AppStrings.reputationNewPlayer,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
        ],
      );
    }
    final averageText = RatingLabels.decimal(value);
    final countText = PersianDigits.fromInt(count);
    return Semantics(
      key: lineKey,
      label: AppStrings.ratingSemantics(averageText, countText),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: AppIconSize.meta, color: palette.star),
          const SizedBox(width: AppSpacing.xxs),
          Text(averageText, style: theme.textTheme.titleSmall?.copyWith(color: palette.rating)),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              AppStrings.ratingCountShort(countText),
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A player's reputation in one sport: «بازیکن جدید», or the star average with the count, the top tags as chips and
/// the level statement.
class SportReputationSummary extends StatelessWidget {
  const SportReputationSummary({super.key, required this.reputation});

  static Key summaryKey(String sportId) => Key('reputation.sport.$sportId');

  final SportReputation reputation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final level = reputation.levelStatement;
    final rated = !reputation.isNew && reputation.starAverage != null;
    return Padding(
      key: summaryKey(reputation.sportId),
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  rated ? Icons.star_rounded : Icons.eco_outlined,
                  size: AppIconSize.action,
                  color: rated ? palette.star : palette.muted,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  RatingLabels.stars(reputation),
                  style: rated
                      ? theme.textTheme.titleSmall?.copyWith(color: palette.rating)
                      : theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
          if (rated && reputation.topTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs - 2,
              runSpacing: AppSpacing.xs - 2,
              children: [for (final tag in reputation.topTags) AppChip(label: RatingLabels.tag(tag))],
            ),
          ],
          if (rated && level != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Icon(Icons.insights_rounded, size: AppIconSize.sm, color: palette.muted),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    RatingLabels.levelStatement(level),
                    style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
