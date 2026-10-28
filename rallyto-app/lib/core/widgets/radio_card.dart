import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// One choice of a single-choice list as a card (design `.selected-game` with `.radio`, and `.level-card`): a radio
/// mark, a bold [title], an optional muted [subtitle] and a [trailing] widget. The selected card has a 2dp green
/// border on soft green. Read out as a checked/unchecked option of one group.
class RadioCard extends StatelessWidget {
  const RadioCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: onTap != null,
      child: Material(
        color: selected ? palette.primarySoft : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          side: BorderSide(color: selected ? palette.primary : palette.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
            child: Padding(
              padding: EdgeInsetsDirectional.all(selected ? 13 : 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? palette.primary : palette.navInactive,
                          width: selected ? 5 : 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: AppSpacing.xs), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
