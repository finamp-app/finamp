import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

extension AtContrast on Color {
  static const double _tolerance = 0.05;

  static Color getContrastiveTintedTextColor({required Color onBackground}) {
    final whiteTinted = Color.alphaBlend(onBackground.withOpacity(0.05), Colors.white);
    final blackTinted = Color.alphaBlend(onBackground.withOpacity(0.3), Colors.black);
    final contrasts = {
      'white': whiteTinted.contrastAgainst(onBackground),
      'black': blackTinted.contrastAgainst(onBackground),
    };

    return switch (contrasts.entries.sortedBy((e) => -e.value).first.key) {
      'white' => whiteTinted,
      'black' => blackTinted,
      _ => onBackground,
    };
  }

  double contrastAgainst(Color other) {
    return contrastRatio(computeLuminance(), other.computeLuminance());
  }

  // Contrast calculations
  double contrastRatio(num a, num b) {
    final ratio = (a + 0.05) / (b + 0.05);
    return ratio >= 1 ? ratio : 1 / ratio;
  }

  Color atContrast(double targetContrast, Color background, bool lighter) {
    final backgroundLuminance = background.computeLuminance();

    HSLColor hslColor = HSLColor.fromColor(this);

    double contrast = contrastRatio(computeLuminance(), backgroundLuminance);

    double minLightness = 0.0;
    double maxLightness = 1.0;
    double diff = contrast.abs() - targetContrast.abs();
    int steps = 0;
    int maxSteps = 25;

    // If diff is negative, we need more contrast.
    while (diff < -_tolerance && steps < maxSteps) {
      steps++;
      // print("contrast: $steps $diff");
      if (diff.isNegative) {
        if (lighter) {
          minLightness = hslColor.lightness;
        } else {
          maxLightness = hslColor.lightness;
        }

        final lightDiff = lighter ? maxLightness - minLightness : minLightness - maxLightness;

        hslColor = hslColor.withLightness(hslColor.lightness + lightDiff / 2);
      }

      contrast = contrastRatio(hslColor.toColor().computeLuminance(), backgroundLuminance);

      diff = (contrast.abs() - targetContrast.abs());
    }

    return hslColor.toColor();
  }
}

extension ColorToHex on Color {
  /// Converts to a hex string.
  ///```
  /// Color(0xFF2196F3).toHex() // "#2196F3"
  /// Color(0xFF2196F3).toHex(includeAlpha: true)  // "#FF2196F3"
  ///```
  /// Note: the toARGB32 method used here might be imprecise on
  /// different platforms because of floating-point math
  String toHex({bool includeAlpha = false}) {
    final value = toARGB32();
    final hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return includeAlpha ? '#$hex' : '#${hex.substring(2)}';
  }
}

extension WithColorScheme on ThemeData {
  /// Apply a colorScheme to ThemeData.  This applies the colorscheme to all values it impacts
  /// when building a default material3 color scheme, based on the ThemeData() constructor.
  ThemeData withColorScheme(ColorScheme scheme) {
    bool isDark = brightness == Brightness.dark;
    final newPrimary = isDark ? scheme.surface : scheme.primary;
    final bool primaryIsDark = ThemeData.estimateBrightnessForColor(newPrimary) == Brightness.dark;
    final Color light = isDark ? scheme.onSurface : scheme.surface;
    final Color dark = isDark ? scheme.surface : scheme.onSurface;
    TextTheme applyLight(TextTheme old) => old.apply(displayColor: light, bodyColor: light, decorationColor: light);
    TextTheme applyDark(TextTheme old) => old.apply(displayColor: dark, bodyColor: dark, decorationColor: dark);
    return copyWith(
      colorScheme: scheme,
      buttonTheme: buttonTheme.copyWith(colorScheme: scheme),
      iconTheme: iconTheme.copyWith(color: scheme.primary),
      primaryColor: newPrimary,
      canvasColor: scheme.surface,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: scheme.surface,
      dividerColor: scheme.outline,
      applyElevationOverlayColor: brightness == Brightness.dark,
      typography: typography.copyWith(black: applyDark(typography.black), white: applyLight(typography.white)),
      textTheme: isDark ? applyLight(textTheme) : applyDark(textTheme),
      primaryTextTheme: primaryIsDark ? applyLight(primaryTextTheme) : applyDark(primaryTextTheme),
    );
  }
}
