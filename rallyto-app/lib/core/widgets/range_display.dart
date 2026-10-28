import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';

/// The design's `.range`: a level range shown as its two ends with a green bar and end dots between them, in a white
/// bordered box. Display only: pair it with a picker to change the range. Read out as «از … تا …».
class RangeDisplay extends StatelessWidget {
  const RangeDisplay({super.key, required this.start, required this.end, this.onTap});

  final String start;
  final String end;

  /// Opens the picker that changes the range.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700);
    final content = Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Row(
        children: [
          Text(start, style: style),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
              child: SizedBox(
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 4, color: palette.primary),
                    _dot(palette, AlignmentDirectional.centerStart),
                    _dot(palette, AlignmentDirectional.centerEnd),
                  ],
                ),
              ),
            ),
          ),
          Text(end, style: style),
        ],
      ),
    );
    return Semantics(
      label: AppStrings.rangeFromTo(start, end),
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }

  static Widget _dot(AppPalette palette, AlignmentDirectional alignment) => Align(
    alignment: alignment,
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle),
    ),
  );
}
