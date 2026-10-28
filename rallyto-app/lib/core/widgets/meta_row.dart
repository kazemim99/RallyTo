import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// One item of a [MetaRow]: an optional icon and a short text.
class MetaItem {
  const MetaItem(this.text, {this.icon});

  final String text;
  final IconData? icon;
}

/// The design's `.meta`: small muted icon+text facts (venue, time, level) wrapping between a top and a bottom line.
class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.items,
    this.margin = const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
  });

  final List<MetaItem> items;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted);
    return Container(
      margin: margin,
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.line),
          bottom: BorderSide(color: palette.line),
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final item in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: AppIconSize.meta, color: palette.muted),
                  const SizedBox(width: 5),
                ],
                Flexible(child: Text(item.text, style: style)),
              ],
            ),
        ],
      ),
    );
  }
}
