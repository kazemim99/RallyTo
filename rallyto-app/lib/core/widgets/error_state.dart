import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import 'app_button.dart';

/// The standard error view: the icon in a soft red circle, the message, and a mandatory retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, required this.onRetry});

  /// Defaults to [AppStrings.genericError].
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: palette.errorSoft, shape: BoxShape.circle),
                child: Icon(Icons.error_outline_rounded, size: 40, color: palette.error),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                message ?? AppStrings.genericError,
                style: theme.textTheme.bodyLarge?.copyWith(color: palette.ink),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(label: AppStrings.retry, onPressed: onRetry, expanded: false, icon: Icons.refresh),
          ],
        ),
      ),
    );
  }
}
