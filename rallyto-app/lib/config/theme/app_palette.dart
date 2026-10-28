import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The design's semantic colours that [ColorScheme] has no slot for, as a [ThemeExtension] so light and dark each
/// carry their own. Read it with `context.palette`.
///
/// Every `on…` colour is the text/icon colour for the fill it is named after, and every such pair is at least 4.5:1
/// (pinned in test/config/theme/app_theme_test.dart). The pairs are:
///
/// | fill | text on it |
/// |---|---|
/// | [primary] | [onPrimary] |
/// | [primarySoft] | [primary] (buttons, links), [onPrimarySoft] (the player's own chat bubble), [muted] |
/// | [accent] | [onAccent] (never white) |
/// | [accentSoft] | [warning] |
/// | [surface], [canvas] | [ink], [muted], [primary], [success], [warning], [error] |
/// | [errorSoft] | [error] |
/// | [infoSoft] | [info] |
/// | [blueSoft] | [blue] |
/// | [track] | [ink] |
/// | [ball] | [onBall] |
/// | [brandStart], [brandEnd] | [onBrand], [onBrandMuted] |
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.primarySoftBorder,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.surface,
    required this.canvas,
    required this.track,
    required this.skeleton,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.blue,
    required this.blueSoft,
    required this.navInactive,
    required this.ball,
    required this.onBall,
    required this.brandStart,
    required this.brandEnd,
    required this.onBrand,
    required this.onBrandMuted,
    required this.star,
    required this.rating,
    required this.shadow,
  });

  final Color primary;
  final Color onPrimary;

  /// Dark covers and the hero gradient's end. White text on it in both themes.
  final Color primaryDark;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color primarySoftBorder;

  /// Fills only: badges, the orange tile's background. Text on it is [onAccent].
  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  final Color ink;
  final Color muted;

  /// 1px borders and dividers.
  final Color line;
  final Color surface;

  /// The scaffold background.
  final Color canvas;

  /// The segmented control's track.
  final Color track;

  /// Placeholder bars while loading.
  final Color skeleton;

  final Color success;
  final Color warning;
  final Color error;
  final Color onError;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;
  final Color blue;
  final Color blueSoft;

  /// Bottom navigation items that are not selected.
  final Color navInactive;

  /// The sport-ball badge.
  final Color ball;
  final Color onBall;

  /// The brand gradient (hero, sign-in art), the same green in both themes, with white text.
  final Color brandStart;
  final Color brandEnd;
  final Color onBrand;
  final Color onBrandMuted;

  /// The rating star's fill, and the score's text.
  final Color star;
  final Color rating;

  /// The tint of the design's soft shadows.
  final Color shadow;

  static const AppPalette light = AppPalette(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryDark: AppColors.primaryDark,
    primarySoft: AppColors.primarySoft,
    onPrimarySoft: AppColors.primaryDark,
    primarySoftBorder: AppColors.primarySoftBorder,
    accent: AppColors.accent,
    onAccent: AppColors.ink,
    accentSoft: AppColors.accentSoft,
    ink: AppColors.ink,
    muted: AppColors.muted,
    line: AppColors.line,
    surface: AppColors.surface,
    canvas: AppColors.canvas,
    track: AppColors.track,
    skeleton: AppColors.skeleton,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorSoft: AppColors.errorSoft,
    info: AppColors.info,
    infoSoft: AppColors.infoSoft,
    blue: AppColors.blue,
    blueSoft: AppColors.blueSoft,
    navInactive: AppColors.navInactive,
    ball: AppColors.ball,
    onBall: AppColors.onBall,
    brandStart: AppColors.primary,
    brandEnd: AppColors.primaryDark,
    onBrand: AppColors.onPrimary,
    onBrandMuted: AppColors.onBrandMuted,
    star: AppColors.star,
    rating: AppColors.rating,
    shadow: AppColors.shadow,
  );

  static const AppPalette dark = AppPalette(
    primary: AppColors.primaryDarkTheme,
    onPrimary: AppColors.onPrimaryDarkTheme,
    primaryDark: AppColors.primaryDark,
    primarySoft: AppColors.primarySoftDarkTheme,
    onPrimarySoft: AppColors.onPrimarySoftDarkTheme,
    primarySoftBorder: AppColors.primarySoftBorderDarkTheme,
    accent: AppColors.accent,
    onAccent: AppColors.ink,
    accentSoft: AppColors.accentSoftDarkTheme,
    ink: AppColors.inkDarkTheme,
    muted: AppColors.mutedDarkTheme,
    line: AppColors.lineDarkTheme,
    surface: AppColors.surfaceDarkTheme,
    canvas: AppColors.canvasDarkTheme,
    track: AppColors.trackDarkTheme,
    skeleton: AppColors.skeletonDarkTheme,
    success: AppColors.successDarkTheme,
    warning: AppColors.warningDarkTheme,
    error: AppColors.errorDarkTheme,
    onError: AppColors.onErrorDarkTheme,
    errorSoft: AppColors.errorSoftDarkTheme,
    info: AppColors.infoDarkTheme,
    infoSoft: AppColors.infoSoftDarkTheme,
    blue: AppColors.blueDarkTheme,
    blueSoft: AppColors.blueSoftDarkTheme,
    navInactive: AppColors.navInactiveDarkTheme,
    ball: AppColors.ball,
    onBall: AppColors.onBall,
    brandStart: AppColors.primary,
    brandEnd: AppColors.primaryDark,
    onBrand: AppColors.onPrimary,
    onBrandMuted: AppColors.onBrandMuted,
    star: AppColors.star,
    rating: AppColors.ratingDarkTheme,
    shadow: AppColors.shadowDarkTheme,
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryDark,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? primarySoftBorder,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? ink,
    Color? muted,
    Color? line,
    Color? surface,
    Color? canvas,
    Color? track,
    Color? skeleton,
    Color? success,
    Color? warning,
    Color? error,
    Color? onError,
    Color? errorSoft,
    Color? info,
    Color? infoSoft,
    Color? blue,
    Color? blueSoft,
    Color? navInactive,
    Color? ball,
    Color? onBall,
    Color? brandStart,
    Color? brandEnd,
    Color? onBrand,
    Color? onBrandMuted,
    Color? star,
    Color? rating,
    Color? shadow,
  }) => AppPalette(
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryDark: primaryDark ?? this.primaryDark,
    primarySoft: primarySoft ?? this.primarySoft,
    onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
    primarySoftBorder: primarySoftBorder ?? this.primarySoftBorder,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentSoft: accentSoft ?? this.accentSoft,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    surface: surface ?? this.surface,
    canvas: canvas ?? this.canvas,
    track: track ?? this.track,
    skeleton: skeleton ?? this.skeleton,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    errorSoft: errorSoft ?? this.errorSoft,
    info: info ?? this.info,
    infoSoft: infoSoft ?? this.infoSoft,
    blue: blue ?? this.blue,
    blueSoft: blueSoft ?? this.blueSoft,
    navInactive: navInactive ?? this.navInactive,
    ball: ball ?? this.ball,
    onBall: onBall ?? this.onBall,
    brandStart: brandStart ?? this.brandStart,
    brandEnd: brandEnd ?? this.brandEnd,
    onBrand: onBrand ?? this.onBrand,
    onBrandMuted: onBrandMuted ?? this.onBrandMuted,
    star: star ?? this.star,
    rating: rating ?? this.rating,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryDark: c(primaryDark, other.primaryDark),
      primarySoft: c(primarySoft, other.primarySoft),
      onPrimarySoft: c(onPrimarySoft, other.onPrimarySoft),
      primarySoftBorder: c(primarySoftBorder, other.primarySoftBorder),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      surface: c(surface, other.surface),
      canvas: c(canvas, other.canvas),
      track: c(track, other.track),
      skeleton: c(skeleton, other.skeleton),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      onError: c(onError, other.onError),
      errorSoft: c(errorSoft, other.errorSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      blue: c(blue, other.blue),
      blueSoft: c(blueSoft, other.blueSoft),
      navInactive: c(navInactive, other.navInactive),
      ball: c(ball, other.ball),
      onBall: c(onBall, other.onBall),
      brandStart: c(brandStart, other.brandStart),
      brandEnd: c(brandEnd, other.brandEnd),
      onBrand: c(onBrand, other.onBrand),
      onBrandMuted: c(onBrandMuted, other.onBrandMuted),
      star: c(star, other.star),
      rating: c(rating, other.rating),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// `context.palette`: the current theme's [AppPalette]. Falls back to the light or dark palette by brightness when a
/// theme without the extension is in use (a bare `ThemeData()` in a test).
extension AppPaletteContext on BuildContext {
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ?? (theme.brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
  }
}
