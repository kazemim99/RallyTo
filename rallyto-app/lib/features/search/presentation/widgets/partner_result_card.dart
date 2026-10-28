import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../../ratings/presentation/widgets/reputation_widgets.dart';
import '../../domain/entities/search.dart';
import '../search_labels.dart';

/// A player found by the search: a large avatar, their name with the reliability chip, «age • level • experience»,
/// the star rating in the searched sport («۴٫۸ (۱۸ امتیاز)», or «بازیکن جدید») and last activity, the green
/// box with each matching window (the time it overlaps the search, the window, the shared clubs), then «پیام» and
/// «دعوت به بازی» side by side, 1 : 1.5. Tapping the card opens their profile; [onInvite] invites them to a game and
/// [onMessage] opens a conversation with them.
class PartnerResultCard extends StatelessWidget {
  const PartnerResultCard({super.key, required this.result, this.onTap, this.onInvite, this.onMessage});

  static Key inviteKey(String userId) => Key('partnerResult.invite.$userId');

  static Key messageKey(String userId) => Key('partnerResult.message.$userId');

  final PartnerResult result;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final muted = theme.textTheme.bodySmall?.copyWith(color: palette.muted);
    final lastActive = result.lastActive;
    final experience = result.experience;
    final facts = [
      if (result.ageRange.isNotEmpty) ProfileLabels.ageRange(result.ageRange),
      if (result.levelName.isNotEmpty) result.levelName,
      if (experience != null) ProfileLabels.experience(experience),
    ].joinDisplay();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        semanticLabel: AppStrings.viewProfile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppAvatar(name: result.displayName, photoUrl: result.photoUrl, size: AppAvatarSize.large),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(result.displayName, style: theme.textTheme.titleMedium)),
                          if (result.reliability case final tier?) ...[
                            const SizedBox(width: AppSpacing.xs),
                            ReliabilityBadge(tier: tier),
                          ],
                        ],
                      ),
                      if (facts.isNotEmpty) Text(facts, style: muted),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                        child: StarRatingLine(average: result.ratingAverage, count: result.ratingCount),
                      ),
                      if (lastActive != null) Text(ProfileLabels.lastActive(lastActive), style: muted),
                    ],
                  ),
                ),
              ],
            ),
            if (result.windows.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _OverlapBox(windows: result.windows),
            ],
            if (onMessage != null || onInvite != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (onMessage != null)
                    Expanded(
                      flex: 2,
                      child: AppButton.secondary(
                        key: messageKey(result.userId),
                        label: AppStrings.messageShort,
                        icon: Icons.chat_bubble_outline_rounded,
                        compact: true,
                        onPressed: onMessage,
                      ),
                    ),
                  if (onMessage != null && onInvite != null) const SizedBox(width: AppSpacing.xs),
                  if (onInvite != null)
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        key: inviteKey(result.userId),
                        label: AppStrings.inviteToGame,
                        icon: Icons.send_rounded,
                        compact: true,
                        onPressed: onInvite,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The design's `.overlap`: primarySoft, a clock, «هم‌پوشانی زمان آزاد», then per window its overlap, days and hours,
/// and the clubs it shares with the search.
class _OverlapBox extends StatelessWidget {
  const _OverlapBox({required this.windows});

  final List<MatchingWindow> windows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final body = theme.textTheme.bodySmall?.copyWith(color: palette.onPrimarySoft);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
      decoration: BoxDecoration(color: palette.primarySoft, borderRadius: BorderRadius.circular(AppRadius.tile)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.schedule_rounded, size: AppIconSize.action, color: palette.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.overlapBoxTitle,
                  style: theme.textTheme.titleSmall?.copyWith(color: palette.onPrimarySoft),
                ),
                for (final window in windows) ...[
                  Text(SearchLabels.overlap(window), style: body?.copyWith(fontWeight: FontWeight.w700)),
                  Text(SearchLabels.window(window), style: body),
                  if (window.venues.isNotEmpty) Text(window.venues.map((v) => v.name).join('، '), style: body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
