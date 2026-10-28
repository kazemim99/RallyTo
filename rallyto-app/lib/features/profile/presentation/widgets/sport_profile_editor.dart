import 'package:flutter/material.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/presentation/widgets/sport_level_picker.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/entities/profile_enums.dart';
import '../../domain/sport_rules.dart';
import '../profile_labels.dart';

/// One sport's profile: level (with the sport's own descriptions), experience, formats (only those the sport allows:
/// padel doubles, squash singles) and goals. A column, so it sits inside the caller's scroll view.
class SportProfileEditor extends StatelessWidget {
  const SportProfileEditor({super.key, required this.sport, required this.draft, required this.onChanged});

  /// The key of [format]'s chip for [sportCode].
  static Key formatKey(String sportCode, PlayFormat format) => Key('sportProfile.$sportCode.format.${format.name}');

  /// The key of [goal]'s chip for [sportCode].
  static Key goalKey(String sportCode, PlayGoal goal) => Key('sportProfile.$sportCode.goal.${goal.name}');

  /// The key of [band]'s chip for [sportCode].
  static Key experienceKey(String sportCode, ExperienceBand band) =>
      Key('sportProfile.$sportCode.experience.${band.name}');

  final Sport sport;
  final SportProfileDraft draft;
  final ValueChanged<SportProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final allowed = SportRules.allowedFormats(sport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(AppStrings.sportLevelTitle),
        SportLevelPicker(
          sport: sport,
          selected: draft.level,
          onChanged: (tier) => onChanged(draft.copyWith(level: tier)),
        ),
        const _Heading(AppStrings.experienceTitle),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: [
            for (final band in ExperienceBand.values)
              AppChip(
                key: experienceKey(sport.code, band),
                label: ProfileLabels.experience(band),
                tone: draft.experience == band ? AppChipTone.active : AppChipTone.neutral,
                onTap: () => onChanged(draft.copyWith(experience: band)),
              ),
          ],
        ),
        const _Heading(AppStrings.formatsTitle),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: [
            for (final format in allowed)
              AppChip(
                key: formatKey(sport.code, format),
                label: ProfileLabels.format(format),
                tone: draft.formats.contains(format) ? AppChipTone.active : AppChipTone.neutral,
                onTap: () => onChanged(
                  draft.copyWith(formats: _toggled(draft.formats, format, !draft.formats.contains(format))),
                ),
              ),
          ],
        ),
        const _Heading(AppStrings.goalsTitle),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: [
            for (final goal in PlayGoal.values)
              AppChip(
                key: goalKey(sport.code, goal),
                label: ProfileLabels.goal(goal),
                tone: draft.goals.contains(goal) ? AppChipTone.active : AppChipTone.neutral,
                onTap: () => onChanged(draft.copyWith(goals: _toggled(draft.goals, goal, !draft.goals.contains(goal)))),
              ),
          ],
        ),
      ],
    );
  }

  static Set<T> _toggled<T>(Set<T> set, T item, bool on) => on ? {...set, item} : {...set.where((x) => x != item)};
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md, bottom: AppSpacing.xxs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
