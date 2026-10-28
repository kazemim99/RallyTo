import 'package:flutter/material.dart';

/// The design's type scale (Vazirmatn in the design; the bundled Vazir here, the same family, offline) mapped onto
/// Material's [TextTheme]. Vazir ships 100/300/400/500/700, so the design's 800 renders as 700.
///
/// | Design | Size / weight / line height | TextTheme |
/// |---|---|---|
/// | hero title (`.hero h2`) | 27 / 700 / 1.55 | displaySmall |
/// | h1, screen title (`h1`) | 24 / 800 / 1.45 | headlineMedium |
/// | greeting (`.home-head h1`) | 20 / 800 / 1.45 | headlineSmall |
/// | section title (`h2`) | 18 / 700 / 1.5 | titleLarge |
/// | app bar title (`.topbar strong`) | 17 / 700 | AppBarTheme.titleTextStyle |
/// | card title (`h3`) | 16 / 700 / 1.5 | titleMedium |
/// | emphasis (`b`, `.lead`) | 14 / 700 / 1.6 | titleSmall |
/// | input text, lead body | 14 / 400 / 1.6 | bodyLarge |
/// | body (`p`) | 13 / 400 / 1.8, muted | bodyMedium (+ `palette.muted`) |
/// | small (`small`, meta) | 12 / 400 / 1.7 | bodySmall |
/// | button | 15 / 700 | labelLarge |
/// | field label, tile label (`.label`, `.quick-grid b`) | 12 / 700 | labelMedium |
/// | chip, nav label, caption (`.chip`, `.bottom-nav small`) | 11 / 500 | labelSmall |
///
/// Body copy in the design is muted; the theme keeps [TextTheme.bodyMedium] in ink because it is also the default
/// for every unstyled [Text]. Apply `context.palette.muted` where the design shows grey body text.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Vazir';

  static TextTheme textTheme(Color ink) {
    TextStyle style(double size, FontWeight weight, [double? height]) =>
        TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: weight, height: height, color: ink);

    return TextTheme(
      displayLarge: style(36, FontWeight.w700, 1.4),
      displayMedium: style(32, FontWeight.w700, 1.45),
      displaySmall: style(27, FontWeight.w700, 1.55),
      headlineLarge: style(26, FontWeight.w800, 1.45),
      headlineMedium: style(24, FontWeight.w800, 1.45),
      headlineSmall: style(20, FontWeight.w800, 1.45),
      titleLarge: style(18, FontWeight.w700, 1.5),
      titleMedium: style(16, FontWeight.w700, 1.5),
      titleSmall: style(14, FontWeight.w700, 1.6),
      bodyLarge: style(14, FontWeight.w400, 1.6),
      bodyMedium: style(13, FontWeight.w400, 1.8),
      bodySmall: style(12, FontWeight.w400, 1.7),
      labelLarge: style(15, FontWeight.w700),
      labelMedium: style(12, FontWeight.w700),
      labelSmall: style(11, FontWeight.w500),
    );
  }
}
