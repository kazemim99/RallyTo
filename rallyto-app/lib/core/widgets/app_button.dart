import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's button variants (`.button`, `.secondary`, `.ghost`, `.danger`), plus [inverse] for a button on the
/// brand gradient (the hero's white call to action).
enum AppButtonVariant {
  /// Filled green: the screen's main action.
  primary,

  /// Soft green with a green border and green text: the companion action.
  secondary,

  /// Text only, green.
  ghost,

  /// Filled with the error colour: destructive actions.
  danger,

  /// White with green text, for use on the brand gradient and dark covers.
  inverse;

  /// The earlier name of [ghost].
  static const AppButtonVariant text = ghost;

  /// The earlier name of [danger].
  static const AppButtonVariant destructive = danger;
}

/// The app's button. 50dp tall ([compact]: 48dp), radius 14, bold; while [loading] it shows a spinner and ignores
/// taps without changing its size. [expanded] buttons fill the width.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.icon,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  /// The same as [AppButton.ghost].
  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.danger;

  /// The same as [AppButton.danger].
  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.danger;

  const AppButton.inverse({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.icon,
  }) : variant = AppButtonVariant.inverse;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expanded;

  /// 48dp tall with smaller text: card actions and banner buttons.
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final effectiveOnPressed = loading ? null : onPressed;

    final foreground = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.secondary || AppButtonVariant.ghost => scheme.primary,
      AppButtonVariant.inverse => palette.brandStart,
    };

    final Widget child;
    if (loading) {
      child = SizedBox.square(
        dimension: AppIconSize.action,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.action),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );
    } else {
      child = Text(label, overflow: TextOverflow.ellipsis);
    }

    final height = compact ? AppTouchTarget.min : AppSizes.control;
    final textStyle = compact ? Theme.of(context).textTheme.labelMedium : null;
    final size = WidgetStatePropertyAll(Size(compact ? AppTouchTarget.min : 64, height));
    ButtonStyle sized(ButtonStyle style) => style.copyWith(
      minimumSize: size,
      textStyle: textStyle == null ? null : WidgetStatePropertyAll(textStyle),
      padding: compact
          ? const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm))
          : null,
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: sized(const ButtonStyle()),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: sized(
          OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            backgroundColor: palette.primarySoft,
            side: BorderSide(color: palette.primarySoftBorder),
          ),
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: sized(TextButton.styleFrom(foregroundColor: scheme.primary)),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: sized(FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)),
        child: child,
      ),
      AppButtonVariant.inverse => FilledButton(
        onPressed: effectiveOnPressed,
        style: sized(
          FilledButton.styleFrom(
            backgroundColor: palette.onBrand,
            foregroundColor: palette.brandStart,
            disabledBackgroundColor: palette.onBrand.withValues(alpha: 0.6),
            disabledForegroundColor: palette.brandStart.withValues(alpha: 0.6),
          ),
        ),
        child: child,
      ),
    };

    final semantic = Semantics(button: true, enabled: effectiveOnPressed != null, label: label, child: button);
    return expanded ? SizedBox(width: double.infinity, child: semantic) : semantic;
  }
}
