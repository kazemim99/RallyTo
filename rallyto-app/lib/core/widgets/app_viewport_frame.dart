import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';

/// Keeps the app phone-shaped on wide screens.
///
/// Every screen is designed for a phone. In a desktop browser (1440 px) the tab bar, full-width buttons, cards and
/// bottom sheets would stretch across the whole window. On the web, or on a large screen (a tablet: shortest side at
/// least [largeScreenShortestSide]), a viewport wider than [maxContentWidth] is drawn in a centred column of that
/// width, on a quiet backdrop with a hairline edge. A native phone is never framed, in either orientation: turned to
/// landscape it keeps the whole screen, as every other phone app does. At or below [maxContentWidth] the child is
/// returned as is.
///
/// Inside the column [MediaQuery] reports the column's size, so code that sizes itself from `MediaQuery.sizeOf`
/// (chat bubbles, dialogs, bottom sheets) and code that uses a [LayoutBuilder] agree on the width. Apply it once,
/// above the navigator (`MaterialApp.builder`), so routes and their overlays all live inside the column.
class AppViewportFrame extends StatelessWidget {
  const AppViewportFrame({super.key, required this.child, this.isWeb = kIsWeb});

  /// The column width on wide screens: a large phone, wide enough for the cards and forms, narrow enough that
  /// nothing stretches.
  static const double maxContentWidth = 480;

  /// Identifies the backdrop drawn outside the column (present only on wide screens).
  static const Key backdropKey = ValueKey('app-viewport-backdrop');

  /// Identifies the column itself (present only on wide screens).
  static const Key columnKey = ValueKey('app-viewport-column');

  /// Material's compact/medium breakpoint: a device whose shortest side reaches it is a tablet, not a phone.
  static const double largeScreenShortestSide = 600;

  /// How much darker than the canvas the backdrop is.
  static const double backdropShade = 0.08;

  /// Whether a viewport of [size] is drawn in the column.
  static bool appliesTo(Size size, {required bool isWeb}) =>
      size.width > maxContentWidth && (isWeb || size.shortestSide >= largeScreenShortestSide);

  final Widget child;

  /// Running in a browser. Defaults to [kIsWeb]; tests pass it to exercise the web path.
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!appliesTo(media.size, isWeb: isWeb)) return child;

    final palette = context.palette;
    final scrim = Theme.of(context).colorScheme.scrim;
    final columnSize = Size(maxContentWidth, media.size.height);
    return ColoredBox(
      key: backdropKey,
      color: Color.alphaBlend(scrim.withValues(alpha: backdropShade), palette.canvas),
      child: Align(
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          key: columnKey,
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: palette.line),
              end: BorderSide(color: palette.line),
            ),
            boxShadow: [BoxShadow(color: scrim.withValues(alpha: 0.10), blurRadius: 32)],
          ),
          child: SizedBox.fromSize(
            size: columnSize,
            child: MediaQuery(
              // The column is far from the window's side edges, so side insets (notches, rounded corners) no longer
              // apply to it; top/bottom insets and the keyboard still do.
              data: media
                  .removePadding(removeLeft: true, removeRight: true)
                  .removeViewPadding(removeLeft: true, removeRight: true)
                  .copyWith(size: columnSize),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
