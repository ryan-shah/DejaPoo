import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color sageGreen = Color(0xFF6FAE8D);
  static const Color forestGreen = Color(0xFF3E6B48);
  static const Color warmSand = Color(0xFFE9DFC8);
  static const Color offWhite = Color(0xFFFAFAF7);
  static const Color freshMint = Color(0xFF7CCF9A);
  static const Color amber = Color(0xFFF4B942);
  static const Color mutedCoral = Color(0xFFD96C6C);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: sageGreen,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD4EDDF),
    onPrimaryContainer: Color(0xFF1B3D28),
    secondary: forestGreen,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFBCDCC5),
    onSecondaryContainer: Color(0xFF0E2916),
    tertiary: warmSand,
    onTertiary: Color(0xFF3E3529),
    tertiaryContainer: Color(0xFFF5EFE2),
    onTertiaryContainer: Color(0xFF4A4035),
    error: mutedCoral,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF5D5D5),
    onErrorContainer: Color(0xFF5C1A1A),
    surface: offWhite,
    onSurface: Color(0xFF1C1C1A),
    surfaceDim: Color(0xFFE4E4DF),
    surfaceBright: offWhite,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF4F4EF),
    surfaceContainer: Color(0xFFEEEEE9),
    surfaceContainerHigh: Color(0xFFE8E8E3),
    surfaceContainerHighest: Color(0xFFE2E2DD),
    onSurfaceVariant: Color(0xFF44483E),
    outline: Color(0xFF75796E),
    outlineVariant: Color(0xFFC5C8BB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF313130),
    onInverseSurface: Color(0xFFF2F2ED),
    inversePrimary: Color(0xFF8FD4AD),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8FD4AD),
    onPrimary: Color(0xFF1B3D28),
    primaryContainer: forestGreen,
    onPrimaryContainer: Color(0xFFD4EDDF),
    secondary: Color(0xFFA8D4B3),
    onSecondary: Color(0xFF0E2916),
    secondaryContainer: Color(0xFF2D5237),
    onSecondaryContainer: Color(0xFFBCDCC5),
    tertiary: Color(0xFFD4C9AF),
    onTertiary: Color(0xFF3E3529),
    tertiaryContainer: Color(0xFF544A3D),
    onTertiaryContainer: Color(0xFFF5EFE2),
    error: Color(0xFFE8A0A0),
    onError: Color(0xFF5C1A1A),
    errorContainer: Color(0xFF7A2E2E),
    onErrorContainer: Color(0xFFF5D5D5),
    surface: Color(0xFF1A1F1A),
    onSurface: Color(0xFFE2E2DD),
    surfaceDim: Color(0xFF1A1F1A),
    surfaceBright: Color(0xFF3A403A),
    surfaceContainerLowest: Color(0xFF141914),
    surfaceContainerLow: Color(0xFF1E241E),
    surfaceContainer: Color(0xFF222A22),
    surfaceContainerHigh: Color(0xFF2C342C),
    surfaceContainerHighest: Color(0xFF363E36),
    onSurfaceVariant: Color(0xFFC5C8BB),
    outline: Color(0xFF8F9286),
    outlineVariant: Color(0xFF44483E),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE2E2DD),
    onInverseSurface: Color(0xFF313130),
    inversePrimary: sageGreen,
  );
}
