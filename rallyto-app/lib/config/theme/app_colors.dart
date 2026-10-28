import 'package:flutter/material.dart';

/// The raw palette of the approved Rallyto design (Figma Make export, `docs/design/figma-export/index.css`), in
/// light and dark. A few design values were darkened slightly so every text/background pair meets WCAG AA (4.5:1);
/// the original value is noted next to each one, and every pair is pinned in test/config/theme/app_theme_test.dart.
///
/// Widgets never use these constants: they read `Theme.of(context).colorScheme` or `context.palette`
/// ([AppPalette]), so the light and dark themes both work.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------------------------------------------
  // Light (the design target)
  // ---------------------------------------------------------------------------------------------------------------

  /// Court green. White text on it is 6.45:1.
  static const Color primary = Color(0xFF146B52);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// The hero gradient's end, dark covers (game cover, profile completion).
  static const Color primaryDark = Color(0xFF0B4C3A);

  /// Soft green fills: secondary buttons, the availability-overlap box, the player's own chat bubble.
  static const Color primarySoft = Color(0xFFE7F3EF);
  static const Color primarySoftBorder = Color(0xFFB8D8CD);

  /// Clay orange, for fills only. Text on it is [ink] (5.45:1), never white (2.91:1).
  static const Color accent = Color(0xFFE9783C);
  static const Color accentSoft = Color(0xFFFFF0E7);

  static const Color ink = Color(0xFF172522);

  /// Design #687875 (4.34:1 on the canvas), darkened.
  static const Color muted = Color(0xFF61706D);
  static const Color line = Color(0xFFDCE5E2);

  /// UI-component borders that must be seen (3.59:1 on white): switch tracks, focus-less outlines.
  static const Color outline = Color(0xFF7D8A87);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF5F8F7);

  /// The segmented control's track, and the highest surface container.
  static const Color track = Color(0xFFE9EFED);
  static const Color skeleton = Color(0xFFE5EBE9);

  /// Design #16835F, darkened.
  static const Color success = Color(0xFF147C5A);

  /// Design #A85C18, darkened.
  static const Color warning = Color(0xFFA65B17);
  static const Color onWarningContainer = Color(0xFF6B3510);

  /// Design #C53C3C, darkened.
  static const Color error = Color(0xFFC33B3B);
  static const Color errorSoft = Color(0xFFFDEAEA);
  static const Color onErrorContainer = Color(0xFF8C1D1D);

  /// Safety and info notes.
  static const Color info = Color(0xFF315F84);
  static const Color infoSoft = Color(0xFFEAF2FA);
  static const Color onInfoContainer = Color(0xFF1F4566);

  /// The blue quick-action tile.
  static const Color blue = Color(0xFF2F6AAA);
  static const Color blueSoft = Color(0xFFE8F0FA);

  /// Design #83908D (3.31:1), darkened.
  static const Color navInactive = Color(0xFF6E7876);

  /// The sport-ball badge.
  static const Color ball = Color(0xFFD9EF70);
  static const Color onBall = Color(0xFF315215);

  /// Secondary text on the brand gradient and dark covers (design .eyebrow.light).
  static const Color onBrandMuted = Color(0xFFCCE6DD);

  /// Ratings: the star's fill, and the score's text (design #9A6A05).
  static const Color star = Color(0xFFF5BD3D);
  static const Color rating = Color(0xFF9A6A05);
  static const Color inversePrimary = Color(0xFF8ED5B8);

  /// The design's shadows are green-tinted: rgba(13, 49, 40, .08).
  static const Color shadow = Color(0x140D3128);

  // ---------------------------------------------------------------------------------------------------------------
  // Dark (derived: the same hues, readable on a deep green-grey)
  // ---------------------------------------------------------------------------------------------------------------

  static const Color primaryDarkTheme = Color(0xFF6FCFAE);
  static const Color onPrimaryDarkTheme = Color(0xFF062A1F);
  static const Color primarySoftDarkTheme = Color(0xFF183A30);
  static const Color onPrimarySoftDarkTheme = Color(0xFF9FE3C9);
  static const Color primarySoftBorderDarkTheme = Color(0xFF2F5C4E);
  static const Color accentSoftDarkTheme = Color(0xFF3D2A1E);
  static const Color inkDarkTheme = Color(0xFFE3ECE9);
  static const Color mutedDarkTheme = Color(0xFFA3B3AE);
  static const Color lineDarkTheme = Color(0xFF2E3D39);
  static const Color outlineDarkTheme = Color(0xFF6F7E7A);
  static const Color surfaceDarkTheme = Color(0xFF17211E);
  static const Color canvasDarkTheme = Color(0xFF0F1715);
  static const Color trackDarkTheme = Color(0xFF22302C);
  static const Color skeletonDarkTheme = Color(0xFF24312D);
  static const Color successDarkTheme = Color(0xFF5FD0A0);
  static const Color warningDarkTheme = Color(0xFFF2B27A);
  static const Color errorDarkTheme = Color(0xFFFF8A80);
  static const Color onErrorDarkTheme = Color(0xFF3B0A0A);
  static const Color errorSoftDarkTheme = Color(0xFF3D1F1F);
  static const Color onErrorContainerDarkTheme = Color(0xFFFFD6D2);
  static const Color infoDarkTheme = Color(0xFF9CC5EA);
  static const Color onInfoDarkTheme = Color(0xFF0E2235);
  static const Color infoSoftDarkTheme = Color(0xFF1E2E3D);
  static const Color onInfoContainerDarkTheme = Color(0xFFCFE3F5);
  static const Color blueDarkTheme = Color(0xFF8AB6EA);
  static const Color blueSoftDarkTheme = Color(0xFF1E2C3E);
  static const Color navInactiveDarkTheme = Color(0xFF8E9B97);
  static const Color ratingDarkTheme = Color(0xFFF2C46B);
  static const Color shadowDarkTheme = Color(0x33000000);
}
