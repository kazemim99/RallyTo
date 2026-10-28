import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's chip tones (`.chip`, `.active`, `.green`, `.orange`, `.red`) plus blue for info.
enum AppChipTone { neutral, active, green, orange, red, blue }

/// The design's `.chip`: a small pill, optionally with a leading icon. Static by default (a status or a tag); with
/// [onTap] it becomes a 48dp-tall toggle whose [AppChipTone.active] tone reads as selected.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.tone = AppChipTone.neutral, this.icon, this.onTap});

  final String label;
  final AppChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, foreground, border) = switch (tone) {
      AppChipTone.neutral => (palette.surface, palette.ink, palette.line),
      AppChipTone.active => (palette.primary, palette.onPrimary, palette.primary),
      AppChipTone.green => (palette.primarySoft, palette.success, palette.primarySoft),
      AppChipTone.orange => (palette.accentSoft, palette.warning, palette.accentSoft),
      AppChipTone.red => (palette.errorSoft, palette.error, palette.errorSoft),
      AppChipTone.blue => (palette.infoSoft, palette.info, palette.infoSoft),
    };
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, height: 1.4);

    final pill = Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
          ),
        ],
      ),
    );

    if (onTap == null) return Semantics(container: true, child: pill);
    return Semantics(
      button: true,
      selected: tone == AppChipTone.active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min, minWidth: AppTouchTarget.min),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}
