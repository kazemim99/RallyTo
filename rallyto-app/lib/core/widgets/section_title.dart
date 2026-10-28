import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.section-title`: a section heading (18 bold), an optional muted [subtitle] under it, and an optional
/// action link at the end («مشاهده همه»). 12dp below it; screens leave [AppSpacing.section] (24) above it.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: context.palette.muted)),
                ],
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
