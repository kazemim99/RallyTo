import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_palette.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/presentation/widgets/reputation_widgets.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/presentation/widgets/partner_result_card.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_search.dart';

/// A search player card carries the player's reputation as the design's player card does: the reliability chip beside
/// the name (the same chip as on profiles) and the star rating in the searched sport, or «بازیکن جدید».
void main() {
  Future<void> show(WidgetTester tester, PartnerResult result) => pumpInShell(
    tester,
    Scaffold(
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [PartnerResultCard(result: result, onInvite: () {}, onMessage: () {})],
      ),
    ),
  );

  testWidgets('a rated player: the reliability chip beside the name, then «۴٫۸ (۱۸ امتیاز)» in gold', (tester) async {
    await show(tester, testPartner(reliability: ReliabilityTier.high, ratingAverage: 4.8, ratingCount: 18));

    final chip = find.byKey(ReliabilityBadge.badgeKey);
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text(AppStrings.reliability(AppStrings.reliabilityHigh))),
      findsOneWidget,
    );
    expect(find.text('۴٫۸'), findsOneWidget);
    expect(find.text('(۱۸ امتیاز)'), findsOneWidget);
    expect(find.text(AppStrings.reputationNewPlayer), findsNothing);
    final palette = tester.element(chip).palette;
    final star = tester.widget<Icon>(
      find.descendant(of: find.byKey(StarRatingLine.lineKey), matching: find.byIcon(Icons.star_rounded)),
    );
    expect(star.color, palette.star);
    // Read out as one phrase (the card merges it into its own button label).
    expect(tester.widget<Semantics>(find.byKey(StarRatingLine.lineKey)).properties.label, 'امتیاز ۴٫۸ از ۱۸ امتیاز');
  });

  testWidgets('below 3 revealed ratings the card says «بازیکن جدید», with the newcomer chip', (tester) async {
    await show(tester, testPartner(reliability: ReliabilityTier.newPlayer, ratingCount: 2));

    expect(find.text(AppStrings.reputationNewPlayer), findsOneWidget);
    expect(find.text(AppStrings.reliabilityNew), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('an unknown tier shows no chip; the rest of the card stays', (tester) async {
    await show(tester, testPartner(ratingAverage: 3.5, ratingCount: 4));

    expect(find.byKey(ReliabilityBadge.badgeKey), findsNothing);
    expect(find.text('۳٫۵'), findsOneWidget);
    expect(find.text('علی'), findsOneWidget);
    expect(find.text(AppStrings.inviteToGame), findsOneWidget);
  });
}
