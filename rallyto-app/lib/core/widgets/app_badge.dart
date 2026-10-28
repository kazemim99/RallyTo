import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import '../utils/persian_digits.dart';

/// The design's unread badge: [count] in Persian digits on the accent, in ink (never white: 2.91:1), 18dp tall,
/// «۹+» beyond [max]. Nothing is shown for zero or less. With a [child] the badge sits on its top end corner.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.count, this.max = 9, this.child, this.semanticLabel});

  final int count;
  final int max;
  final Widget? child;

  /// Read out instead of the default «۳ مورد خوانده‌نشده».
  final String? semanticLabel;

  /// [count] as the badge writes it.
  static String text(int count, {int max = 9}) =>
      count > max ? '${PersianDigits.fromInt(max)}+' : PersianDigits.fromInt(count);

  @override
  Widget build(BuildContext context) {
    final badge = count <= 0 ? null : _badge(context);
    final host = child;
    if (host == null) return badge ?? const SizedBox.shrink();
    if (badge == null) return host;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        host,
        PositionedDirectional(top: -3, end: -6, child: badge),
      ],
    );
  }

  Widget _badge(BuildContext context) {
    final palette = context.palette;
    final label = text(count, max: max);
    return Semantics(
      label: semanticLabel ?? AppStrings.unreadCount(label),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: AppSizes.badge, minHeight: AppSizes.badge),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: palette.surface, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.onAccent, height: 1.3),
        ),
      ),
    );
  }
}
