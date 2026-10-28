import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// One choice of an [AppSegmented].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.key});

  final T value;
  final String label;

  /// Put on the segment's tap target, so a page test can find one choice.
  final Key? key;
}

/// The design's `.segment`: equal-width choices on a soft track; the selected one is white with bold green text.
/// Each choice is a 50dp-tall tap target, read out as a selected/unselected button of one group.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({super.key, required this.segments, required this.selected, required this.onChanged});

  final List<AppSegment<T>> segments;
  final T selected;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final duration = MediaQuery.of(context).disableAnimations ? Duration.zero : AppMotion.fast;
    return Container(
      decoration: BoxDecoration(color: palette.track, borderRadius: BorderRadius.circular(AppRadius.field)),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(child: _segment(context, segments[i], i, palette, theme, duration)),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    AppSegment<T> segment,
    int index,
    AppPalette palette,
    ThemeData theme,
    Duration duration,
  ) {
    final isSelected = segment.value == selected;
    final callback = onChanged;
    return Semantics(
      key: segment.key,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      enabled: callback != null,
      label: segment.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: callback == null || isSelected ? null : () => callback(segment.value),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            top: 4,
            bottom: 4,
            start: index == 0 ? 4 : 2,
            end: index == segments.length - 1 ? 4 : 2,
          ),
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 42),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected ? palette.surface : palette.track,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: isSelected
                  ? [BoxShadow(color: palette.shadow, blurRadius: 8, offset: const Offset(0, 2))]
                  : const [],
            ),
            child: Text(
              segment.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? palette.primary : palette.ink,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
