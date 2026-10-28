import 'package:flutter/material.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/sport.dart';

/// The five skill tiers of [sport], each with the server's Persian name and the sport's own description, for the
/// player to say how well they play. Each is a level card (design `.level-card`); the chosen one has a 2dp green
/// border on soft green. A column, so it sits inside the caller's scroll view.
class SportLevelPicker extends StatelessWidget {
  const SportLevelPicker({super.key, required this.sport, required this.selected, required this.onChanged});

  /// The key of [tier]'s option.
  static Key tierKey(LevelTier tier) => Key('sportLevelPicker.${tier.name}');

  final Sport sport;
  final LevelTier? selected;
  final ValueChanged<LevelTier> onChanged;

  @override
  Widget build(BuildContext context) {
    final levels = [...sport.levels]..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final level in levels)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: RadioCard(
              key: tierKey(level.tier),
              title: level.name,
              subtitle: level.description.isEmpty ? null : level.description,
              selected: level.tier == selected,
              onTap: () => onChanged(level.tier),
            ),
          ),
      ],
    );
  }
}
