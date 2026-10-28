import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The app's Material 3 themes in Vazir: light (the approved design) and a derived dark. Each carries its
/// [AppPalette] extension (`context.palette`). RTL comes from the app shell, not from here.
class AppTheme {
  AppTheme._();

  static const String fontFamily = AppTypography.fontFamily;

  static ThemeData get light => _build(lightScheme, AppPalette.light);

  static ThemeData get dark => _build(darkScheme, AppPalette.dark);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.accentSoft,
    onSecondaryContainer: AppColors.onWarningContainer,
    tertiary: AppColors.info,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: AppColors.infoSoft,
    onTertiaryContainer: AppColors.onInfoContainer,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.errorSoft,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceDim: AppColors.track,
    surfaceBright: AppColors.surface,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.canvas,
    // Muted text stays at least 4.5:1 on every container tone.
    surfaceContainer: Color(0xFFF1F5F4),
    surfaceContainerHigh: Color(0xFFEEF3F1),
    surfaceContainerHighest: Color(0xFFEBF1EF),
    outline: AppColors.outline,
    outlineVariant: AppColors.line,
    shadow: AppColors.shadow,
    scrim: Color(0x99000000),
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.canvas,
    inversePrimary: AppColors.inversePrimary,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDarkTheme,
    onPrimary: AppColors.onPrimaryDarkTheme,
    primaryContainer: AppColors.primarySoftDarkTheme,
    onPrimaryContainer: AppColors.onPrimarySoftDarkTheme,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.accentSoftDarkTheme,
    onSecondaryContainer: AppColors.warningDarkTheme,
    tertiary: AppColors.infoDarkTheme,
    onTertiary: AppColors.onInfoDarkTheme,
    tertiaryContainer: AppColors.infoSoftDarkTheme,
    onTertiaryContainer: AppColors.onInfoContainerDarkTheme,
    error: AppColors.errorDarkTheme,
    onError: AppColors.onErrorDarkTheme,
    errorContainer: AppColors.errorSoftDarkTheme,
    onErrorContainer: AppColors.onErrorContainerDarkTheme,
    surface: AppColors.surfaceDarkTheme,
    onSurface: AppColors.inkDarkTheme,
    onSurfaceVariant: AppColors.mutedDarkTheme,
    surfaceDim: AppColors.canvasDarkTheme,
    surfaceBright: AppColors.trackDarkTheme,
    surfaceContainerLowest: Color(0xFF0B1210),
    surfaceContainerLow: Color(0xFF141D1A),
    surfaceContainer: Color(0xFF1A2522),
    surfaceContainerHigh: AppColors.trackDarkTheme,
    surfaceContainerHighest: Color(0xFF2A3834),
    outline: AppColors.outlineDarkTheme,
    outlineVariant: AppColors.lineDarkTheme,
    shadow: Color(0xFF000000),
    scrim: Color(0x99000000),
    inverseSurface: AppColors.inkDarkTheme,
    onInverseSurface: AppColors.ink,
    inversePrimary: AppColors.primary,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final textTheme = AppTypography.textTheme(scheme.onSurface);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
    const buttonSize = Size(64, AppSizes.control);
    const buttonPadding = EdgeInsetsDirectional.symmetric(horizontal: 18);
    final buttonText = textTheme.labelLarge;

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      dividerColor: palette.line,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: palette.canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.md),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: scheme.primary,
          backgroundColor: palette.primarySoft,
          side: BorderSide(color: palette.primarySoftBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: scheme.primary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(AppTouchTarget.min)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.muted),
        labelStyle: textTheme.bodyLarge?.copyWith(color: palette.muted),
        floatingLabelStyle: textTheme.bodyLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
        helperStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: palette.muted,
        suffixIconColor: palette.muted,
        border: fieldBorder(palette.line),
        enabledBorder: fieldBorder(palette.line),
        disabledBorder: fieldBorder(palette.line),
        focusedBorder: fieldBorder(scheme.primary, 1.5),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error, 1.5),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: palette.line),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(color: states.contains(WidgetState.selected) ? scheme.primary : palette.line),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : palette.surface,
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
        checkmarkColor: scheme.onPrimary,
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.sm),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xxs),
        showCheckmark: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : palette.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(AppTouchTarget.min, AppTouchTarget.min)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? palette.surface : palette.track,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface,
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: palette.track, width: 2)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field))),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        dragHandleColor: palette.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: palette.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.line,
        circularTrackColor: Colors.transparent,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: palette.accent,
        textColor: palette.onAccent,
        textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: palette.muted,
        indicatorColor: scheme.primary,
        dividerColor: palette.line,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(AppRadius.sm)),
        textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
