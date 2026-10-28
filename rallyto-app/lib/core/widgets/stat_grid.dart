import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// One cell of a [StatGrid]: a small muted [label] over a bold [value].
class StatItem {
  const StatItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// The design's `.stat-grid`: equal columns (three in the design) divided by lines, in a white bordered box. Each
/// cell is read out as «label: value».
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: palette.line),
              Expanded(
                child: Semantics(
                  label: '${items[i].label}: ${items[i].value}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xxs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          items[i].label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                        Text(items[i].value, textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
