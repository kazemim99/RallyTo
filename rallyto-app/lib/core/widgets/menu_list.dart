import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// One row of a [MenuList].
class MenuItem {
  const MenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.trailing,
    this.destructive = false,
    this.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Shown before the chevron (a count, a status chip).
  final Widget? trailing;

  /// Red label and icon («خروج از حساب»).
  final bool destructive;
  final Key? key;
}

/// The design's profile `.menu`: rows of icon, label and a forward chevron in one white bordered box, divided by
/// lines, each at least 54dp tall. An optional [title] heads the group.
class MenuList extends StatelessWidget {
  const MenuList({super.key, required this.items, this.title});

  final List<MenuItem> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final box = Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: palette.line),
            _row(items[i], palette, theme),
          ],
        ],
      ),
    );
    if (title == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.xxs, bottom: AppSpacing.xs),
          child: Semantics(
            header: true,
            child: Text(title!, style: theme.textTheme.labelMedium?.copyWith(color: palette.muted)),
          ),
        ),
        box,
      ],
    );
  }

  Widget _row(MenuItem item, AppPalette palette, ThemeData theme) {
    final color = item.destructive ? palette.error : palette.ink;
    return Semantics(
      button: true,
      enabled: item.onTap != null,
      child: InkWell(
        key: item.key,
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, color: color, size: AppIconSize.md - 2),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(item.label, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
                ),
                if (item.trailing != null) ...[item.trailing!, const SizedBox(width: AppSpacing.xs)],
                ExcludeSemantics(
                  child: Icon(Icons.chevron_right_rounded, color: palette.muted, size: AppIconSize.meta + 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
