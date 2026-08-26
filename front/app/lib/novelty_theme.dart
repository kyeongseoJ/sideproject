import 'package:flutter/material.dart';

abstract final class NoveltyColors {
  static const primary = Color(0xFF7234E0);
  static const primaryStrong = Color(0xFF482486);
  static const primarySubtle = Color(0xFFE8D6FF);
  static const primaryFaint = Color(0xFFF6EEFF);
  static const primaryDark = Color(0xFF8243F2);

  static const ncBlue = Color(0xFF1D4B99);
  static const ncBlueStrong = Color(0xFF0E356A);
  static const ncBlueSubtle = Color(0xFFD3E2FC);
  static const lightBlue = Color(0xFF38AEFA);

  static const ink = Color(0xFF0F1011);
  static const inkSoft = Color(0xFF1E1E1E);
  static const gray015 = Color(0xFF252628);
  static const gray025 = Color(0xFF3D3D43);
  static const gray040 = Color(0xFF62626A);
  static const gray055 = Color(0xFF888890);
  static const gray065 = Color(0xFFA3A3A9);
  static const gray075 = Color(0xFFBDBDC1);
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF2F2F3);
  static const surfaceAlt = Color(0xFFF7F7F8);
  static const line = Color(0xFFEBEBEB);
  static const heroDark = Color(0xFF333333);
  static const editorialFaint = Color(0xFFEFEFEF);

  static const success = Color(0xFF21AB79);
  static const successFaint = Color(0xFFEAF8F3);
  static const error = Color(0xFFF1415E);
  static const errorFaint = Color(0xFFFFF0F3);
  static const lavender = Color(0xFF6768F6);
}

abstract final class NoveltySpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const section = 64.0;
}

abstract final class NoveltyRadii {
  static const button = 6.0;
  static const medium = 10.0;
  static const tile = 12.0;
  static const card = 16.0;
}

abstract final class NoveltyMotion {
  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const enter = Cubic(0.2, 0.6, 0.25, 1);
  static const exit = Cubic(0.4, 0, 1, 1);
  static const standardCurve = Cubic(0.25, 0.1, 0.25, 1);
}

abstract final class NoveltyDecorations {
  static BoxDecoration card({
    Color color = NoveltyColors.canvas,
    Color borderColor = NoveltyColors.line,
    double radius = NoveltyRadii.card,
  }) => BoxDecoration(
    color: color,
    border: Border.all(color: borderColor),
    borderRadius: BorderRadius.circular(radius),
  );

  static BoxDecoration error() => BoxDecoration(
    color: NoveltyColors.errorFaint,
    border: Border.all(color: NoveltyColors.error),
    borderRadius: BorderRadius.circular(NoveltyRadii.medium),
  );
}

ThemeData buildNoveltyTheme({TextTheme? baseTextTheme}) {
  final baseTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    fontFamily: 'Noto Sans KR',
  );
  final fontTextTheme = (baseTextTheme ?? baseTheme.textTheme).apply(
    fontFamily: 'Noto Sans KR',
  );
  final textTheme = fontTextTheme
      .apply(bodyColor: NoveltyColors.ink, displayColor: NoveltyColors.ink)
      .copyWith(
        displayLarge: fontTextTheme.displayLarge?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: NoveltyColors.ink,
        ),
        displaySmall: fontTextTheme.displaySmall?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: NoveltyColors.ink,
        ),
        headlineMedium: fontTextTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.36,
          color: NoveltyColors.ink,
        ),
        headlineSmall: fontTextTheme.headlineSmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: NoveltyColors.ink,
        ),
        titleLarge: fontTextTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        bodyLarge: fontTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        bodyMedium: fontTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: NoveltyColors.gray040,
        ),
        labelLarge: fontTextTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        titleMedium: fontTextTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        titleSmall: fontTextTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: NoveltyColors.ink,
        ),
        bodySmall: fontTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: NoveltyColors.gray040,
        ),
      );

  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: NoveltyColors.primary,
    onPrimary: NoveltyColors.canvas,
    primaryContainer: NoveltyColors.primarySubtle,
    onPrimaryContainer: NoveltyColors.primaryStrong,
    secondary: NoveltyColors.ncBlue,
    onSecondary: NoveltyColors.canvas,
    secondaryContainer: NoveltyColors.ncBlueSubtle,
    onSecondaryContainer: NoveltyColors.ncBlueStrong,
    tertiary: NoveltyColors.success,
    onTertiary: NoveltyColors.canvas,
    error: NoveltyColors.error,
    onError: NoveltyColors.canvas,
    errorContainer: NoveltyColors.errorFaint,
    onErrorContainer: Color(0xFF71132A),
    surface: NoveltyColors.canvas,
    onSurface: NoveltyColors.ink,
    onSurfaceVariant: NoveltyColors.gray040,
    outline: NoveltyColors.gray075,
    outlineVariant: NoveltyColors.line,
    shadow: Colors.transparent,
    scrim: Colors.black,
    inverseSurface: NoveltyColors.inkSoft,
    onInverseSurface: NoveltyColors.canvas,
    inversePrimary: NoveltyColors.primaryDark,
  );

  final primaryButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size(64, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    backgroundColor: NoveltyColors.primary,
    foregroundColor: NoveltyColors.canvas,
    disabledBackgroundColor: NoveltyColors.primarySubtle,
    disabledForegroundColor: NoveltyColors.gray065,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NoveltyRadii.button),
    ),
    textStyle: textTheme.labelLarge,
  );

  return baseTheme.copyWith(
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: NoveltyColors.surfaceAlt,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: NoveltyColors.canvas,
      foregroundColor: NoveltyColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      shape: const Border(bottom: BorderSide(color: NoveltyColors.line)),
    ),
    cardTheme: CardThemeData(
      color: NoveltyColors.canvas,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NoveltyColors.line),
        borderRadius: BorderRadius.circular(NoveltyRadii.card),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: NoveltyColors.ink,
        side: const BorderSide(color: NoveltyColors.gray075),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NoveltyRadii.button),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NoveltyColors.primaryStrong,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NoveltyColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: NoveltyColors.gray055),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: NoveltyColors.error),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
        borderSide: const BorderSide(color: NoveltyColors.gray075),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
        borderSide: const BorderSide(color: NoveltyColors.primary),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
        borderSide: const BorderSide(color: NoveltyColors.line),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
        borderSide: const BorderSide(color: NoveltyColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
        borderSide: const BorderSide(color: NoveltyColors.error),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NoveltyColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NoveltyColors.line),
        borderRadius: BorderRadius.circular(NoveltyRadii.card),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NoveltyColors.surfaceAlt,
      selectedColor: NoveltyColors.primarySubtle,
      disabledColor: NoveltyColors.surface,
      labelStyle: textTheme.bodyMedium?.copyWith(color: NoveltyColors.ink),
      secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
        color: NoveltyColors.primaryStrong,
      ),
      side: const BorderSide(color: NoveltyColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      pressElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: NoveltyColors.line,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: NoveltyColors.ink),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NoveltyColors.primary,
      selectionColor: NoveltyColors.primarySubtle,
      selectionHandleColor: NoveltyColors.primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NoveltyColors.primary,
      linearTrackColor: NoveltyColors.line,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NoveltyColors.inkSoft,
      contentTextStyle: textTheme.bodyLarge?.copyWith(
        color: NoveltyColors.canvas,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NoveltyRadii.button),
      ),
    ),
  );
}
