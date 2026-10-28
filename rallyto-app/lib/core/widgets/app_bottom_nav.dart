import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import 'app_badge.dart';

/// One destination of an [AppBottomNav].
class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.selectedIcon, this.badgeCount = 0, this.key});

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// An [AppBadge] on the icon when above zero.
  final int badgeCount;
  final Key? key;
}

/// The design's `.bottom-nav`: white, a 1px top line and a soft upward shadow; each item is its icon over a small
/// label, the selected one green and bold, the others [AppPalette.navInactive]. Items run right to left in the RTL
/// app. Each item is a 48dp+ tap target read out as a selected/unselected tab with its unread count.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onSelected});

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.navBar,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              children: [for (var i = 0; i < items.length; i++) Expanded(child: _item(items[i], i, palette, theme))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(AppNavItem item, int index, AppPalette palette, ThemeData theme) {
    final selected = index == currentIndex;
    final color = selected ? palette.primary : palette.navInactive;
    final badge = item.badgeCount > 0 ? '، ${AppStrings.unreadCount(AppBadge.text(item.badgeCount))}' : '';
    return Semantics(
      key: item.key,
      button: true,
      selected: selected,
      label: '${item.label}$badge',
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onSelected(index),
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min, minWidth: AppTouchTarget.min),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppBadge(
                count: item.badgeCount,
                child: Icon(selected ? item.selectedIcon ?? item.icon : item.icon, color: color, size: AppIconSize.nav),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
