import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.toggle-row`: a bold [title], an optional muted [subtitle], and a switch at the end. The whole row
/// toggles, and is read out as one switch.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final callback = onChanged;
    return MergeSemantics(
      child: InkWell(
        onTap: callback == null ? null : () => callback(!value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch(value: value, onChanged: callback),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
