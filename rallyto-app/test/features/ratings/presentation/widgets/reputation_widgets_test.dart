import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_palette.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/presentation/rating_labels.dart';
import 'package:rallyto_app/features/ratings/presentation/widgets/reputation_widgets.dart';

import '../../../../helpers/app_shell.dart';

/// Reputation on a profile: «بازیکن جدید» below 3 ratings; otherwise the average to one decimal with the count in
/// Persian digits, the top tags and the level statement; the reliability tier as a badge, never a number.
void main() {
  Future<void> show(WidgetTester tester, Widget child) => pumpInShell(tester, Scaffold(body: Center(child: child)));

  testWidgets('fewer than 3 ratings: «بازیکن جدید», with no average, tags or statement', (tester) async {
    await show(
      tester,
      const SportReputationSummary(
        reputation: SportReputation(
          sportId: 's-tennis',
          isNew: true,
          ratingCount: 2,
          topTags: [RatingTag.onTime],
          levelStatement: LevelAccuracy.higher,
        ),
      ),
    );

    expect(find.text(AppStrings.reputationNewPlayer), findsOneWidget);
    expect(find.text(AppStrings.tagOnTime), findsNothing);
    expect(find.textContaining('بیشتر هم‌بازی‌ها'), findsNothing);
  });

  testWidgets('from 3 ratings: «۴٫۳ ستاره از ۳ امتیاز», the top tags and the level statement', (tester) async {
    await show(
      tester,
      const SportReputationSummary(
        reputation: SportReputation(
          sportId: 's-tennis',
          isNew: false,
          starAverage: 4.333,
          ratingCount: 3,
          topTags: [RatingTag.onTime, RatingTag.goodRally, RatingTag.friendly],
          levelStatement: LevelAccuracy.aboutRight,
        ),
      ),
    );

    expect(find.text('۴٫۳ ستاره از ۳ امتیاز'), findsOneWidget);
    final star = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
    expect(star.color, AppTheme.light.extension<AppPalette>()!.star, reason: "the palette's star, not amber");
    expect(find.text(AppStrings.tagOnTime), findsOneWidget);
    expect(find.text(AppStrings.tagGoodRally), findsOneWidget);
    expect(find.text(AppStrings.tagFriendly), findsOneWidget);
    expect(find.text('بیشتر هم‌بازی‌ها می‌گویند سطح اعلام‌شده درست است'), findsOneWidget);
  });

  testWidgets('no majority on the level: no statement', (tester) async {
    await show(
      tester,
      const SportReputationSummary(
        reputation: SportReputation(sportId: 's-tennis', isNew: false, starAverage: 5, ratingCount: 12),
      ),
    );

    expect(find.text('۵٫۰ ستاره از ۱۲ امتیاز'), findsOneWidget);
    expect(find.textContaining('بیشتر هم‌بازی‌ها'), findsNothing);
  });

  test('the level statements, in the spec\'s words', () {
    expect(RatingLabels.levelStatement(LevelAccuracy.aboutRight), 'بیشتر هم‌بازی‌ها می‌گویند سطح اعلام‌شده درست است');
    expect(
      RatingLabels.levelStatement(LevelAccuracy.higher),
      'بیشتر هم‌بازی‌ها می‌گویند بهتر از سطح اعلام‌شده بازی می‌کند',
    );
    expect(
      RatingLabels.levelStatement(LevelAccuracy.lower),
      'بیشتر هم‌بازی‌ها می‌گویند پایین‌تر از سطح اعلام‌شده بازی می‌کند',
    );
  });

  for (final (tier, label, tone) in [
    (ReliabilityTier.newPlayer, 'تازه‌وارد', AppChipTone.neutral),
    (ReliabilityTier.low, 'خوش‌قولی: کم', AppChipTone.orange),
    (ReliabilityTier.good, 'خوش‌قولی: خوب', AppChipTone.green),
    (ReliabilityTier.high, 'خوش‌قولی: عالی', AppChipTone.green),
  ]) {
    testWidgets('reliability ${tier.wire} is the ${tone.name} chip «$label», with no number', (tester) async {
      await show(tester, ReliabilityBadge(tier: tier));

      expect(find.byKey(ReliabilityBadge.badgeKey), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(tester.widget<AppChip>(find.byKey(ReliabilityBadge.badgeKey)).tone, tone);
      expect(find.textContaining(RegExp('[0-9۰-۹]')), findsNothing);
    });
  }
}
