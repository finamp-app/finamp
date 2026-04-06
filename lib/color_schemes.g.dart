import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:finamp/services/finamp_settings_helper.dart';

const jellyfinBlueColor = Color(0xFF00A4DC);
const jellyfinPurpleColor = Color(0xFFAA5CC3);

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Primary
  primary: Color(0xFF00668A),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC4E8FF),
  onPrimaryContainer: Color(0xFF001E2C),
  // Secondary
  secondary: Color(0xFF406374),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFCCE8F8),
  onSecondaryContainer: Color(0xFF1B333F),
  // Tertiary
  tertiary: Color(0xFF893DA2),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFAD7FF),
  onTertiaryContainer: Color(0xFF330044),
  // Error
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  // Background & Surface
  background: Color(0xFFFCFDFE),
  onBackground: Color(0xFF191C1E),
  surface: Color(0xFFFCFDFE),
  surfaceContainerHighest: Color(0xFFFCFCFE),
  onSurface: Color(0xFF191C1E),
  surfaceVariant: Color(0xFFDDE4E8),
  onSurfaceVariant: Color(0xFF41484D),
  // Other colors
  outline: Color(0xFF727A7F),
  onInverseSurface: Color(0xFFF0F1F3),
  inverseSurface: Color(0xFF2E3133),
  inversePrimary: Color(0xFF7BD0FF),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF00668A),
  outlineVariant: Color(0xFFC0C7CD),
  scrim: Color(0xFF000000),
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Primary
  primary: jellyfinBlueColor,
  onPrimary: Color(0xFF001E2C),
  primaryContainer: Color(0xFF004C68),
  onPrimaryContainer: Color(0xFFC3E7FF),
  // Secondary
  secondary: Color(0xFF60B4DD),
  onSecondary: Color(0xFF112732),
  secondaryContainer: Color(0xFF206B8C),
  onSecondaryContainer: Color(0xFFCEEEFF),
  // Tertiary
  tertiary: Color(0xFFC979E2),
  onTertiary: Color(0xFF3D0050),
  tertiaryContainer: Color(0xFF762A90),
  onTertiaryContainer: Color(0xFFFAD7FF),
  // Error
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF93000A),
  onError: Color(0xFF690005),
  onErrorContainer: Color(0xFFFFDAD6),
  // Background & Surface
  background: Color(0xFF101315),
  onBackground: Color(0xFFE1E2E5),
  surface: Color(0xFF101315),
  surfaceContainerHighest: Color(0xFF111A1B),
  onSurface: Color(0xFFE1E2E5),
  surfaceVariant: Color(0xFF333A3E),
  onSurfaceVariant: Color(0xFFC0C7CD),
  // Other colors
  outline: Color(0xFF80878C),
  onInverseSurface: Color(0xFF191C1E),
  inverseSurface: Color(0xFFE1E2E5),
  inversePrimary: Color(0xFF00668A),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF7BD0FF),
  outlineVariant: Color(0xFF41484D),
  scrim: Color(0xFF000000),
);

/// If [color] is provided -> returns a generated color scheme
/// otherwise falls back to default color schemes
/// [lightColorScheme] or [darkColorScheme]
ColorScheme getColorScheme(Color? color, Brightness brightness, bool amoledTheme) {
  ColorScheme scheme = brightness == Brightness.dark ? darkColorScheme : lightColorScheme;

  if (color != null) {
    scheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  if (amoledTheme && brightness == Brightness.dark) {
    scheme = scheme.copyWith(background: Color(0xFF000000), surface: Color(0xFF000000));
  }

  return scheme;
}
