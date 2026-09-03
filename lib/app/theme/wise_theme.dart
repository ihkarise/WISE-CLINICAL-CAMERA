import 'package:flutter/material.dart';

import 'wise_tokens.dart';

/// Builds the Material theme from [WiseTokens].
///
/// Two themes exist because UX/UI section 58 requires a predominantly dark
/// interface around the live camera preview while the rest of the application
/// uses the light Soft Background surface.
abstract final class WiseTheme {
  /// The application theme used everywhere except the camera.
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: WiseTokens.wiseBlue,
      onPrimary: WiseTokens.white,
      secondary: WiseTokens.wiseRed,
      onSecondary: WiseTokens.white,
      tertiary: WiseTokens.aiGlowBlue,
      surface: WiseTokens.white,
      onSurface: WiseTokens.deepNavy,
      surfaceContainerLowest: WiseTokens.white,
      surfaceContainerLow: WiseTokens.softBackground,
      surfaceContainer: WiseTokens.softBackground,
      outline: WiseTokens.lightGray,
      outlineVariant: WiseTokens.lightGray,
      error: WiseTokens.warningRed,
      onError: WiseTokens.white,
    );

    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: WiseTokens.softBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: WiseTokens.softBackground,
        foregroundColor: WiseTokens.deepNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: WiseTokens.fontFamily,
          fontFamilyFallback: WiseTokens.fontFamilyFallback,
          fontSize: WiseTokens.screenTitleSize,
          fontWeight: WiseTokens.screenTitleWeight,
          color: WiseTokens.deepNavy,
        ),
      ),
    );
  }

  /// Camera chrome (UX/UI 58). Brand blue and red mark active controls and
  /// meaningful states rather than filling the screen.
  static ThemeData cameraDark() {
    final colorScheme = const ColorScheme.dark(
      primary: WiseTokens.wiseBlue,
      onPrimary: WiseTokens.white,
      secondary: WiseTokens.wiseRed,
      onSecondary: WiseTokens.white,
      tertiary: WiseTokens.aiGlowBlue,
      surface: WiseTokens.cameraSurface,
      onSurface: WiseTokens.cameraOnSurface,
      outline: WiseTokens.slateGray,
      error: WiseTokens.warningRed,
      onError: WiseTokens.white,
    );

    return _base(colorScheme).copyWith(
      scaffoldBackgroundColor: WiseTokens.cameraSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: WiseTokens.cameraOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final onSurface = colorScheme.onSurface;
    final muted = colorScheme.brightness == Brightness.light
        ? WiseTokens.slateGray
        : WiseTokens.cameraOnSurfaceMuted;

    TextStyle style(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: WiseTokens.fontFamily,
      fontFamilyFallback: WiseTokens.fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );

    final textTheme = TextTheme(
      headlineMedium: style(
        WiseTokens.screenTitleSize,
        WiseTokens.screenTitleWeight,
        onSurface,
      ),
      titleLarge: style(
        WiseTokens.sectionTitleSize,
        WiseTokens.sectionTitleWeight,
        onSurface,
      ),
      titleMedium: style(
        WiseTokens.bodySize,
        WiseTokens.secondaryWeight,
        onSurface,
      ),
      bodyLarge: style(WiseTokens.bodySize, WiseTokens.bodyWeight, onSurface),
      bodyMedium: style(
        WiseTokens.secondarySize,
        WiseTokens.secondaryWeight,
        muted,
      ),
      labelLarge: style(
        WiseTokens.bodySize,
        FontWeight.w600,
        colorScheme.onPrimary,
      ),
      labelMedium: style(
        WiseTokens.cameraStatusSize,
        WiseTokens.cameraStatusWeight,
        onSurface,
      ),
      labelSmall: style(
        WiseTokens.captionSize,
        WiseTokens.captionWeight,
        muted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: WiseTokens.fontFamily,
      fontFamilyFallback: WiseTokens.fontFamilyFallback,
      splashFactory: InkSparkle.splashFactory,
      // Pill geometry, 16px semibold label (UX/UI 65).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WiseTokens.wiseBlue,
          foregroundColor: WiseTokens.white,
          minimumSize: const Size(0, WiseTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: WiseTokens.space24,
            vertical: WiseTokens.space8,
          ),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      // White/light background, Wise Blue text, subtle border (UX/UI 66).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WiseTokens.wiseBlue,
          minimumSize: const Size(0, WiseTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: WiseTokens.space24,
            vertical: WiseTokens.space8,
          ),
          side: BorderSide(color: colorScheme.outline),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(color: WiseTokens.wiseBlue),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WiseTokens.wiseBlue,
          minimumSize: const Size(0, WiseTokens.minTouchTarget),
          textStyle: textTheme.labelLarge?.copyWith(color: WiseTokens.wiseBlue),
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WiseTokens.cardRadius),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: WiseTokens.wiseBlue,
        thumbColor: WiseTokens.wiseBlue,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? WiseTokens.white
              : colorScheme.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? WiseTokens.wiseBlue
              : WiseTokens.lightGray,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WiseTokens.cardRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WiseTokens.deepNavy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: WiseTokens.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WiseTokens.controlRadius),
        ),
      ),
    );
  }
}
