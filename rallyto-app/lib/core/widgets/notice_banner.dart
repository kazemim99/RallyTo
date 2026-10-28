import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import 'app_button.dart';

/// The design's notice tones: [brand] `.notice-card` (soft green, a round white icon), [info] `.info`/`.safety`
/// (blue), [warning] `.warning` (soft orange), [success] `.success-banner`, [error] `.error-banner`.
enum NoticeTone { brand, info, warning, success, error }

/// A notice: an icon, a bold [title] and/or a [body], and an optional compact action at the end. Each tone pairs its
/// fill with an AA text colour.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    this.tone = NoticeTone.brand,
    this.title,
    this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : assert(title != null || body != null, 'A notice needs a title or a body');

  final NoticeTone tone;
  final String? title;
  final String? body;

  /// Defaults to the tone's icon.
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final (background, border, iconColor, titleColor, bodyColor, defaultIcon) = switch (tone) {
      NoticeTone.brand => (
        palette.primarySoft,
        palette.primarySoftBorder,
        palette.primary,
        palette.ink,
        palette.muted,
        Icons.schedule_rounded,
      ),
      NoticeTone.success => (
        palette.primarySoft,
        palette.primarySoftBorder,
        palette.success,
        palette.ink,
        palette.muted,
        Icons.verified_user_outlined,
      ),
      NoticeTone.info => (palette.infoSoft, null, palette.info, palette.info, palette.info, Icons.shield_outlined),
      NoticeTone.warning => (
        palette.accentSoft,
        null,
        palette.warning,
        palette.warning,
        palette.warning,
        Icons.warning_amber_rounded,
      ),
      NoticeTone.error => (palette.errorSoft, null, palette.error, palette.error, palette.error, Icons.error_outline),
    };

    final glyph = Icon(icon ?? defaultIcon, color: iconColor, size: AppIconSize.action);
    final leading = tone == NoticeTone.brand
        ? Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: palette.surface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: glyph,
          )
        : Padding(padding: const EdgeInsetsDirectional.only(top: 2), child: glyph);

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(tone == NoticeTone.brand ? AppRadius.md : AppRadius.field),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: tone == NoticeTone.brand ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: AppSpacing.sm - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: titleColor, fontSize: 13)),
                  if (body != null)
                    Text(body!, style: theme.textTheme.bodySmall?.copyWith(color: bodyColor, height: 1.7)),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.xs),
              AppButton.secondary(label: actionLabel!, onPressed: onAction, expanded: false, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}
