import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The icon tones of the design's `.quick-grid` tiles.
enum QuickActionTone { green, orange, blue }

/// One tile of the design's `.quick-grid`: a tinted icon square, a bold [label] and a small [caption]. Lay three in a
/// row with 8dp gaps (`Row` of `Expanded`, or a 3-column grid).
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    this.tone = QuickActionTone.green,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final QuickActionTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    // Orange text and icons use the warning tone: the accent itself is 2.6:1 on its soft fill.
    final (background, foreground) = switch (tone) {
      QuickActionTone.green => (palette.primarySoft, palette.primary),
      QuickActionTone.orange => (palette.accentSoft, palette.warning),
      QuickActionTone.blue => (palette.blueSoft, palette.blue),
    };
    return Semantics(
      button: true,
      label: caption == null ? label : '$label، $caption',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 128),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs, vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
                    alignment: Alignment.center,
                    child: Icon(icon, color: foreground, size: AppIconSize.action),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: theme.textTheme.labelMedium),
                  if (caption != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(caption!, style: theme.textTheme.labelSmall?.copyWith(color: palette.muted, height: 1.5)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
