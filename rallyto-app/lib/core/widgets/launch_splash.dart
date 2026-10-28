import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_palette.dart';
import '../constants/app_strings.dart';
import 'brand_mark.dart';

/// The animated launch splash: a canvas-coloured overlay above the whole window, played once per app start.
///
/// Its first frame is the native splash (the canvas with a [tileSize] [BrandTile] centred), so the hand-off from the
/// platform is seamless. Then, over [duration]:
///
/// * 0–750 ms, the rally: the mark spins one full turn inside the tile and stops in its brand pose, and the tile gives
///   a small landing pop (650–850 ms);
/// * 700–1100 ms: the tile glides up [glideDistance] while the wordmark and tagline fade and slide up beneath it;
/// * a short hold, then 1350–1600 ms the overlay fades out and leaves the tree.
///
/// [child] (the app) is built from the start and keeps running underneath; the overlay absorbs taps while it shows
/// and is excluded from semantics. With reduced motion (`MediaQuery.disableAnimations`) there is no overlay at all.
/// Apply it once, above everything else in `MaterialApp.builder`.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child});

  /// The whole timeline, from the first frame until the overlay is gone.
  static const Duration duration = Duration(milliseconds: _totalMs);

  /// When the spin ends and the mark is back in its brand pose.
  static const Duration spinEnd = Duration(milliseconds: _spinEndMs);

  /// The tile's side: the native splash's `launch_mark` (Android) and `LaunchImage` (iOS).
  static const double tileSize = 96;

  /// How far the tile rises to make room for the wordmark.
  static const double glideDistance = 36;

  /// Identifies the overlay (present only while it shows).
  static const Key overlayKey = ValueKey('launch-splash');

  static const int _totalMs = 1600;
  static const int _spinEndMs = 750;

  final Widget child;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash> with SingleTickerProviderStateMixin {
  /// Created only when the splash plays; with reduced motion there is none.
  AnimationController? _controller;
  bool _started = false;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      // Decided once, on the first frame: a rebuild never restarts the splash.
      _started = true;
      if (reducedMotion) return;
      _visible = true;
      _controller = AnimationController(vsync: this, duration: LaunchSplash.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) setState(() => _visible = false);
        })
        ..forward();
    } else if (reducedMotion && _visible) {
      _controller?.stop();
      _visible = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The child keeps its place (and its state) when the overlay leaves.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_visible) Positioned.fill(child: _SplashOverlay(animation: _controller!)),
      ],
    );
  }
}

class _SplashOverlay extends AnimatedWidget {
  const _SplashOverlay({required Animation<double> animation}) : super(listenable: animation);

  static const _total = LaunchSplash._totalMs;
  static const _spin = Interval(0, LaunchSplash._spinEndMs / _total, curve: Curves.easeInOutCubic);
  static const _pop = Interval(650 / _total, 850 / _total);
  static const _glide = Interval(700 / _total, 1100 / _total, curve: Curves.easeOutCubic);
  static const _fadeOut = Interval(1350 / _total, 1, curve: Curves.easeOut);

  /// The landing pop's peak: the tile grows to 106%.
  static const double _popScale = 0.06;

  /// The gap between the tile and the wordmark, and how far the wordmark rises as it fades in.
  static const double _captionGap = 16;
  static const double _captionRise = 12;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final palette = context.palette;
    final theme = Theme.of(context);
    final glide = _glide.transform(t);
    final tileOffset = -LaunchSplash.glideDistance * glide;
    // A full turn ends exactly in the static pose (360° is drawn as 0°).
    final rotation = 360 * _spin.transform(t) % 360;
    final scale = 1 + _popScale * math.sin(math.pi * _pop.transform(t));

    return ExcludeSemantics(
      child: AbsorbPointer(
        // Dark status-bar icons on the light canvas, whatever the screen underneath asks for.
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Opacity(
            opacity: 1 - _fadeOut.transform(t),
            child: Material(
              key: LaunchSplash.overlayKey,
              color: palette.canvas,
              child: Stack(
                children: [
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, tileOffset),
                      child: Transform.scale(
                        scale: scale,
                        child: BrandTile(size: LaunchSplash.tileSize, markRotationDegrees: rotation),
                      ),
                    ),
                  ),
                  if (glide > 0)
                    Center(
                      child: Transform.translate(
                        // The caption's top sits [_captionGap] below the tile's bottom edge.
                        offset: Offset(
                          0,
                          LaunchSplash.tileSize / 2 + _captionGap + tileOffset + _captionRise * (1 - glide),
                        ),
                        child: FractionalTranslation(
                          translation: const Offset(0, 0.5),
                          child: Opacity(
                            opacity: glide,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.appName,
                                  style: theme.textTheme.headlineMedium?.copyWith(color: palette.ink),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  AppStrings.appTagline,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
