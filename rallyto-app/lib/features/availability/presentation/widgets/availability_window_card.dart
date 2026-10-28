import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../domain/entities/availability_window.dart';
import '../availability_labels.dart';

/// One availability window as a card: the sport with its status chip, when (weekdays or date) and the hours, then the
/// clubs, formats and repetition as meta, the end date, the day it pauses itself ([showPauseDay]) and note, with
/// [actions] under it.
class AvailabilityWindowCard extends StatelessWidget {
  const AvailabilityWindowCard({
    super.key,
    required this.window,
    required this.sportNames,
    this.actions = const [],
    this.showPauseDay = false,
  });

  final AvailabilityWindow window;

  /// Persian names by sport code.
  final Map<String, String> sportNames;
  final List<Widget> actions;

  /// The player's own list: an active weekly window shows the day it pauses itself unless confirmed, as a warning
  /// chip when the server says it needs reconfirming now.
  final bool showPauseDay;

  static Key pauseDayKey(String id) => Key('availabilityCard.pauseDay.$id');

  static Key reconfirmChipKey(String id) => Key('availabilityCard.reconfirm.$id');

  static AppChipTone _tone(AvailabilityStatus status) => switch (status) {
    AvailabilityStatus.active => AppChipTone.green,
    AvailabilityStatus.paused => AppChipTone.orange,
    AvailabilityStatus.expired => AppChipTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final muted = theme.textTheme.bodySmall?.copyWith(color: palette.muted);
    final validUntil = window.validUntil;
    final sportName = ProfileLabels.sportName(window.sportCode, sportNames);
    final code = window.sportCode;
    final pausesOn = window.pausesOn;
    final showsPauseDay =
        showPauseDay &&
        pausesOn != null &&
        window.status == AvailabilityStatus.active &&
        window.kind == AvailabilityKind.recurring;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SportBall(label: code.isEmpty ? '' : code.substring(0, 1).toUpperCase(), semanticLabel: sportName),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sportName, style: theme.textTheme.titleMedium),
                      Text(
                        [AvailabilityLabels.when(window), AvailabilityLabels.time(window)].joinDisplay(),
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppChip(label: AvailabilityLabels.status(window.status), tone: _tone(window.status)),
              ],
            ),
            MetaRow(
              items: [
                if (window.venues.isNotEmpty)
                  MetaItem(window.venues.map((v) => v.name).join('، '), icon: Icons.place_outlined),
                if (window.formats.isNotEmpty) MetaItem(window.formats.map(ProfileLabels.format).join('، ')),
                MetaItem(AvailabilityLabels.kind(window.kind), icon: Icons.repeat_rounded),
              ],
            ),
            if (validUntil != null) Text(AppStrings.validUntil(JalaliDateText.display(validUntil)), style: muted),
            if (showsPauseDay)
              if (window.needsReconfirmation)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppChip(
                      key: reconfirmChipKey(window.id),
                      label: AppStrings.availabilityPausesOn(JalaliDateText.display(pausesOn)),
                      tone: AppChipTone.orange,
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                )
              else
                Text(
                  AppStrings.availabilityPausesOn(JalaliDateText.display(pausesOn)),
                  key: pauseDayKey(window.id),
                  style: muted,
                ),
            if (window.note case final note?)
              Text(note, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
            if (actions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xxs,
                children: actions,
              )
            else
              const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}
