import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_colors.dart';
import 'package:rallyto_app/config/theme/app_palette.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/config/theme/app_tokens.dart';

/// The approved design's palette (adjusted for AA), in light and a derived dark, with every text/background pair the
/// app uses at least 4.5:1 (WCAG AA), and the component themes the design specifies.
void main() {
  final themes = {'light': AppTheme.light, 'dark': AppTheme.dark};

  test('both themes are Material 3 in Vazir, with the right brightness and a palette', () {
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    for (final theme in themes.values) {
      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Vazir');
      expect(theme.extension<AppPalette>(), isNotNull);
    }
    expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
  });

  test('the light palette is the design, with the AA adjustments', () {
    const expected = {
      'primary': (AppColors.primary, 0xFF146B52),
      'primaryDark': (AppColors.primaryDark, 0xFF0B4C3A),
      'primarySoft': (AppColors.primarySoft, 0xFFE7F3EF),
      'primarySoftBorder': (AppColors.primarySoftBorder, 0xFFB8D8CD),
      'accent': (AppColors.accent, 0xFFE9783C),
      'accentSoft': (AppColors.accentSoft, 0xFFFFF0E7),
      'ink': (AppColors.ink, 0xFF172522),
      'muted (design #687875)': (AppColors.muted, 0xFF61706D),
      'line': (AppColors.line, 0xFFDCE5E2),
      'surface': (AppColors.surface, 0xFFFFFFFF),
      'canvas': (AppColors.canvas, 0xFFF5F8F7),
      'success (design #16835F)': (AppColors.success, 0xFF147C5A),
      'warning (design #A85C18)': (AppColors.warning, 0xFFA65B17),
      'error (design #C53C3C)': (AppColors.error, 0xFFC33B3B),
      'errorSoft': (AppColors.errorSoft, 0xFFFDEAEA),
      'info': (AppColors.info, 0xFF315F84),
      'infoSoft': (AppColors.infoSoft, 0xFFEAF2FA),
      'blue': (AppColors.blue, 0xFF2F6AAA),
      'blueSoft': (AppColors.blueSoft, 0xFFE8F0FA),
      'navInactive (design #83908D)': (AppColors.navInactive, 0xFF6E7876),
      'ball': (AppColors.ball, 0xFFD9EF70),
      'onBall': (AppColors.onBall, 0xFF315215),
    };
    for (final MapEntry(key: name, value: (actual, hex)) in expected.entries) {
      expect(actual, Color(hex), reason: name);
    }
  });

  test('the light scheme: green primary with white on it, the accent as secondary with ink on it', () {
    const s = AppTheme.lightScheme;
    expect(s.primary, AppColors.primary);
    expect(s.onPrimary, const Color(0xFFFFFFFF));
    expect(s.secondary, AppColors.accent);
    expect(s.onSecondary, AppColors.ink, reason: 'white on the accent is 2.91:1');
    expect(s.surface, AppColors.surface);
    expect(s.onSurface, AppColors.ink);
    expect(s.onSurfaceVariant, AppColors.muted);
    expect(s.outlineVariant, AppColors.line);
    expect(s.error, AppColors.error);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.canvas);
  });

  test('white on the accent fails AA, which is why the badge and accent fills carry ink', () {
    expect(_contrast(AppColors.accent, const Color(0xFFFFFFFF)), lessThan(4.5));
    expect(_contrast(AppColors.accent, AppColors.ink), greaterThanOrEqualTo(4.5));
  });

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    test('$name: text on every scheme colour is at least 4.5:1', () {
      final s = theme.colorScheme;
      final pairs = {
        'primary': (s.primary, s.onPrimary),
        'primaryContainer': (s.primaryContainer, s.onPrimaryContainer),
        'secondary': (s.secondary, s.onSecondary),
        'secondaryContainer': (s.secondaryContainer, s.onSecondaryContainer),
        'tertiary': (s.tertiary, s.onTertiary),
        'tertiaryContainer': (s.tertiaryContainer, s.onTertiaryContainer),
        'surface': (s.surface, s.onSurface),
        'surface, variant text': (s.surface, s.onSurfaceVariant),
        'surfaceContainerHighest, variant text': (s.surfaceContainerHighest, s.onSurfaceVariant),
        'error': (s.error, s.onError),
        'errorContainer': (s.errorContainer, s.onErrorContainer),
        'inverseSurface': (s.inverseSurface, s.onInverseSurface),
        'inverseSurface, inverse primary': (s.inverseSurface, s.inversePrimary),
        'scaffold': (theme.scaffoldBackgroundColor, s.onSurface),
      };
      for (final MapEntry(key: role, value: (background, foreground)) in pairs.entries) {
        expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5), reason: '$name $role');
      }
    });

    test('$name: every palette text pair is at least 4.5:1', () {
      final p = theme.extension<AppPalette>()!;
      final pairs = {
        'onPrimary on primary': (p.primary, p.onPrimary),
        'primary on primarySoft (secondary button, links)': (p.primarySoft, p.primary),
        'onPrimarySoft on primarySoft (own chat bubble)': (p.primarySoft, p.onPrimarySoft),
        'muted on primarySoft (notice body)': (p.primarySoft, p.muted),
        'ink on primarySoft (notice title)': (p.primarySoft, p.ink),
        'success on primarySoft (green chip)': (p.primarySoft, p.success),
        'onPrimarySoft on primarySoftBorder (avatar initial)': (p.primarySoftBorder, p.onPrimarySoft),
        'onAccent on accent (badge)': (p.accent, p.onAccent),
        'warning on accentSoft (orange chip, warning note)': (p.accentSoft, p.warning),
        'ink on surface': (p.surface, p.ink),
        'muted on surface': (p.surface, p.muted),
        'primary on surface': (p.surface, p.primary),
        'success on surface': (p.surface, p.success),
        'warning on surface': (p.surface, p.warning),
        'error on surface': (p.surface, p.error),
        'ink on canvas': (p.canvas, p.ink),
        'muted on canvas': (p.canvas, p.muted),
        'primary on canvas': (p.canvas, p.primary),
        'onError on error (danger button)': (p.error, p.onError),
        'error on errorSoft (red chip, error note)': (p.errorSoft, p.error),
        'info on infoSoft (safety and info notes)': (p.infoSoft, p.info),
        'blue on blueSoft (blue tile)': (p.blueSoft, p.blue),
        'ink on track (unselected segment)': (p.track, p.ink),
        'navInactive on surface (bottom bar)': (p.surface, p.navInactive),
        'onBall on ball': (p.ball, p.onBall),
        'onBrand on brandStart (hero)': (p.brandStart, p.onBrand),
        'onBrand on brandEnd (dark covers)': (p.brandEnd, p.onBrand),
        'onBrandMuted on brandStart (hero eyebrow)': (p.brandStart, p.onBrandMuted),
        'onBrand on primaryDark': (p.primaryDark, p.onBrand),
        'brandStart on onBrand (inverse button)': (p.onBrand, p.brandStart),
        'rating on surface': (p.surface, p.rating),
      };
      for (final MapEntry(key: role, value: (background, foreground)) in pairs.entries) {
        expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5), reason: '$name $role');
      }
    });

    test('$name: the switch track and visible outlines are at least 3:1 (non-text contrast)', () {
      final s = theme.colorScheme;
      final p = theme.extension<AppPalette>()!;
      expect(_contrast(p.surface, s.outline), greaterThanOrEqualTo(3), reason: '$name outline on surface');
      expect(_contrast(p.canvas, s.primary), greaterThanOrEqualTo(3), reason: '$name primary on canvas');
    });
  }

  test('the radii and type scale follow the design', () {
    expect(AppRadius.sm, 10);
    expect(AppRadius.md, 16);
    expect(AppRadius.lg, 24);
    expect(AppRadius.button, 14);
    expect(AppRadius.field, 13);
    expect(AppRadius.card, 16);
    final t = AppTheme.light.textTheme;
    expect(t.headlineMedium?.fontSize, 24);
    expect(t.titleLarge?.fontSize, 18);
    expect(t.titleMedium?.fontSize, 16);
    expect(t.bodyMedium?.fontSize, 13);
    expect(t.bodyMedium?.height, 1.8);
    expect(t.bodySmall?.fontSize, 12);
    expect(t.labelSmall?.fontSize, 11);
    expect(AppTheme.light.appBarTheme.titleTextStyle?.fontSize, 17);
    expect(AppTheme.light.appBarTheme.backgroundColor, AppColors.canvas);
    expect(AppTheme.light.appBarTheme.centerTitle, isTrue);
  });

  test('buttons are 50dp tall with radius 14; fields radius 13 on white; cards white with a line border', () {
    final style = AppTheme.light.filledButtonTheme.style!;
    expect(style.minimumSize?.resolve({})?.height, 50);
    final shape = style.shape?.resolve({}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));

    final input = AppTheme.light.inputDecorationTheme;
    expect(input.fillColor, AppColors.surface);
    final border = input.enabledBorder as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(13));
    expect(border.borderSide.color, AppColors.line);

    final card = AppTheme.light.cardTheme;
    expect(card.color, AppColors.surface);
    final cardShape = card.shape as RoundedRectangleBorder;
    expect(cardShape.side.color, AppColors.line);
    expect(cardShape.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('context.palette reads the theme, and falls back by brightness without the extension', (tester) async {
    late AppPalette themed;
    late AppPalette bare;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            themed = context.palette;
            return Theme(
              data: ThemeData(brightness: Brightness.light),
              child: Builder(
                builder: (context) {
                  bare = context.palette;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(themed, AppPalette.dark);
    expect(bare, AppPalette.light);
  });

  test('the palette interpolates between themes', () {
    final halfway = AppPalette.light.lerp(AppPalette.dark, 0.5);
    expect(halfway.primary, Color.lerp(AppPalette.light.primary, AppPalette.dark.primary, 0.5));
    expect(AppPalette.light.copyWith(ink: AppColors.primary).ink, AppColors.primary);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
