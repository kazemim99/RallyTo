import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.sticky-actions`: a bottom-pinned row of a [secondary] and a [primary] action in a 1 : 1.5 ratio,
/// over a fade from transparent to the canvas, so content scrolls away beneath it.
///
/// Put it in `Scaffold.bottomNavigationBar` with `extendBody: true`, and leave [contentPadding] at the bottom of the
/// scrolling content so the last item can scroll clear of it.
class StickyActions extends StatelessWidget {
  const StickyActions({super.key, required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;

  /// The bottom padding scrolling content needs under a [StickyActions].
  static const double contentPadding = 104;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.24],
          colors: [palette.canvas.withValues(alpha: 0), palette.canvas],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 28, AppSpacing.screen, AppSpacing.xxs),
          child: Row(
            children: [
              if (secondary != null) ...[Expanded(flex: 2, child: secondary!), const SizedBox(width: AppSpacing.xs)],
              Expanded(flex: 3, child: primary),
            ],
          ),
        ),
      ),
    );
  }
}
