import 'package:flutter/animation.dart';

/// Spacing scale (4dp grid). Use these for padding, margins and gaps — never arbitrary numbers. Screens use
/// [screen] side padding and [section] between sections.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Side padding of every screen.
  static const double screen = md;

  /// The gap above each [SectionTitle]-led section.
  static const double section = lg;
}

/// Corner radius scale (design `--r-sm`, `--r-md`, `--r-lg`).
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;

  /// Fully rounded: chips, pills, badges.
  static const double full = 999;

  static const double button = 14;
  static const double field = 13;
  static const double card = 16;
  static const double chip = full;

  /// List rows, info boxes, bios: between [sm] and [md] (design 12–14).
  static const double tile = 14;
}

/// Motion durations and curves. Animated components honour `MediaQuery.disableAnimations`.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
}

/// Icon sizes: [sm] inline, [md] functional, [action] inside a tap target, [hero] for empty and error states.
class AppIconSize {
  AppIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double meta = 17;
  static const double action = 20;
  static const double nav = 23;
  static const double md = 24;
  static const double hero = 72;
}

/// Minimum touch target (accessibility baseline).
class AppTouchTarget {
  AppTouchTarget._();

  static const double min = 48;
}

/// Fixed component heights from the design.
class AppSizes {
  AppSizes._();

  /// Buttons, inputs and the search box.
  static const double control = 50;

  /// The bottom navigation bar, without the system inset.
  static const double navBar = 64;

  static const double progressBar = 5;
  static const double badge = 18;
}
