import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/catalog/presentation/widgets/sport_level_picker.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';

/// The five tiers of a sport in the server's Persian words, lowest first, one selectable.
void main() {
  testWidgets("shows the five tiers with the sport's names and descriptions, and reports the choice", (tester) async {
    final chosen = <LevelTier>[];
    var selected = LevelTier.intermediate;
    final sport = tennis();
    await pumpInShell(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: SportLevelPicker(
              sport: sport,
              selected: selected,
              onChanged: (tier) => setState(() {
                chosen.add(tier);
                selected = tier;
              }),
            ),
          ),
        ),
      ),
    );

    for (final level in sport.levels) {
      expect(find.text(level.name), findsOneWidget);
      expect(find.text(level.description), findsOneWidget);
    }
    Finder option(LevelTier tier) => find.byKey(SportLevelPicker.tierKey(tier));
    final tops = [for (final tier in LevelTier.values) tester.getTopLeft(option(tier)).dy];
    expect(tops, [...tops]..sort(), reason: 'lowest tier first');
    // One choice of a group, read out as checked or not.
    expect(
      tester.getSemantics(option(LevelTier.intermediate)),
      isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: true),
    );
    expect(tester.getSemantics(option(LevelTier.advanced)), isSemantics(hasCheckedState: true, isChecked: false));

    await tester.tap(find.text('پیشرفته'));
    await tester.pump();

    expect(chosen, [LevelTier.advanced]);
    expect(tester.getSemantics(option(LevelTier.advanced)), isSemantics(hasCheckedState: true, isChecked: true));
    expect(tester.getSemantics(option(LevelTier.intermediate)), isSemantics(hasCheckedState: true, isChecked: false));
    expect(find.byType(RadioCard), findsNWidgets(sport.levels.length), reason: 'each tier is a level card');
  });
}
