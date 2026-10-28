import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';

/// Standard feedback snackbars: floating, radius 14, on ink (success and info) or the error colour, with a tone
/// icon. Every action the player starts ends in one of these (or a success screen): no silent success or failure.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message, {VoidCallback? onUndo}) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      iconColor: scheme.inversePrimary,
      background: scheme.inverseSurface,
      foreground: scheme.onInverseSurface,
      action: onUndo == null
          ? null
          : SnackBarAction(label: AppStrings.undo, textColor: scheme.inversePrimary, onPressed: onUndo),
    );
  }

  static void error(BuildContext context, String message) {
    final palette = context.palette;
    _show(
      context,
      message,
      icon: Icons.error_outline_rounded,
      iconColor: palette.onError,
      background: palette.error,
      foreground: palette.onError,
    );
  }

  static void info(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message,
      icon: Icons.info_outline_rounded,
      iconColor: scheme.onInverseSurface,
      background: scheme.inverseSurface,
      foreground: scheme.onInverseSurface,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color iconColor,
    required Color background,
    required Color foreground,
    SnackBarAction? action,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.6);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          action: action,
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: AppIconSize.action),
              const SizedBox(width: AppSpacing.sm - 2),
              Expanded(child: Text(message, style: style)),
            ],
          ),
        ),
      );
  }
}
