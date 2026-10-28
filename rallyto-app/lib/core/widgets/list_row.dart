import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.list-row`: [leading] (an avatar or an icon), a bold [title] with an optional muted [subtitle], and
/// a [trailing] widget, on white with a line border and radius 14. Stack rows with 8dp gaps. Tappable rows are at
/// least 48dp tall.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleTrailing,
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Inline after the title (a «میزبان» chip).
  final Widget? titleTrailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : AppTouchTarget.min),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(13),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: palette.primary, size: AppIconSize.md),
                child: leading!,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                      ),
                      if (titleTrailing != null) ...[const SizedBox(width: AppSpacing.xs - 2), titleTrailing!],
                    ],
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.xs), trailing!],
          ],
        ),
      ),
    );
    final row = Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    if (onTap == null && semanticLabel == null) return row;
    return Semantics(button: onTap != null, label: semanticLabel, child: row);
  }
}
