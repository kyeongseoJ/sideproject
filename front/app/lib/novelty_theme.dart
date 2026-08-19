import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class NoveltyColors {
  static const primary = Color(0xFF7234E0);
  static const primaryStrong = Color(0xFF482486);
  static const primarySubtle = Color(0xFFE8D6FF);
  static const primaryFaint = Color(0xFFF6EEFF);

  static const ink = Color(0xFF0F1011);
  static const inkSoft = Color(0xFF1E1E1E);
  static const gray025 = Color(0xFF3D3D43);
  static const gray040 = Color(0xFF62626A);
  static const gray065 = Color(0xFFA3A3A9);
  static const gray075 = Color(0xFFBDBDC1);
  static const surface = Color(0xFFF2F2F3);
  static const surfaceAlt = Color(0xFFF7F7F8);
  static const line = Color(0xFFEBEBEB);

  static const success = Color(0xFF21AB79);
  static const error = Color(0xFFF1415E);
  static const errorFaint = Color(0xFFFFF0F3);
}

ThemeData buildNoveltyTheme() {
  final baseTheme = ThemeData(brightness: Brightness.light, useMaterial3: true);
  final textTheme = GoogleFonts.notoSansKrTextTheme(baseTheme.textTheme)
      .apply(bodyColor: NoveltyColors.ink, displayColor: NoveltyColors.ink)
      .copyWith(
        displaySmall: GoogleFonts.notoSansKr(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: NoveltyColors.ink,
        ),
        headlineMedium: GoogleFonts.notoSansKr(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.36,
          color: NoveltyColors.ink,
        ),
        headlineSmall: GoogleFonts.notoSansKr(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: NoveltyColors.ink,
        ),
        titleLarge: GoogleFonts.notoSansKr(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        bodyLarge: GoogleFonts.notoSansKr(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        bodyMedium: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: NoveltyColors.gray040,
        ),
        labelLarge: GoogleFonts.notoSansKr(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      );

  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: NoveltyColors.primary,
    onPrimary: Colors.white,
    primaryContainer: NoveltyColors.primarySubtle,
    onPrimaryContainer: NoveltyColors.primaryStrong,
    secondary: Color(0xFF1D4B99),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD3E2FC),
    onSecondaryContainer: Color(0xFF0E356A),
    tertiary: NoveltyColors.success,
    onTertiary: Colors.white,
    error: NoveltyColors.error,
    onError: Colors.white,
    errorContainer: NoveltyColors.errorFaint,
    onErrorContainer: Color(0xFF71132A),
    surface: Colors.white,
    onSurface: NoveltyColors.ink,
    onSurfaceVariant: NoveltyColors.gray040,
    outline: NoveltyColors.gray075,
    outlineVariant: NoveltyColors.line,
    shadow: Colors.transparent,
    scrim: Colors.black,
    inverseSurface: NoveltyColors.inkSoft,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF8243F2),
  );

  final primaryButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    backgroundColor: NoveltyColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: NoveltyColors.primarySubtle,
    disabledForegroundColor: NoveltyColors.gray065,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    textStyle: textTheme.labelLarge,
  );

  return baseTheme.copyWith(
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: NoveltyColors.surface,
    splashFactory: InkRipple.splashFactory,
    filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: NoveltyColors.ink,
        side: const BorderSide(color: NoveltyColors.gray075),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NoveltyColors.primaryStrong,
        textStyle: textTheme.labelLarge,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NoveltyColors.primary,
      linearTrackColor: NoveltyColors.line,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NoveltyColors.inkSoft,
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
