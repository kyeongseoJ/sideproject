import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/novelty_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches the DESIGN.md button, input, card and chip tokens', () {
    final theme = buildNoveltyTheme(baseTextTheme: ThemeData().textTheme);
    final filledStyle = theme.filledButtonTheme.style!;
    final filledShape =
        filledStyle.shape!.resolve({})! as RoundedRectangleBorder;
    final inputBorder =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final chipShape = theme.chipTheme.shape! as RoundedRectangleBorder;

    expect(filledStyle.minimumSize!.resolve({}), const Size(64, 44));
    expect(filledShape.borderRadius, BorderRadius.circular(6));
    expect(inputBorder.borderRadius, BorderRadius.circular(6));
    expect(cardShape.borderRadius, BorderRadius.circular(16));
    expect(theme.cardTheme.elevation, 0);
    expect(chipShape.borderRadius, BorderRadius.circular(6));
    expect(theme.scaffoldBackgroundColor, NoveltyColors.surfaceAlt);
  });

  test('uses DESIGN.md semantic colors without shadows', () {
    final theme = buildNoveltyTheme(baseTextTheme: ThemeData().textTheme);

    expect(theme.colorScheme.primary, const Color(0xFF7234E0));
    expect(theme.colorScheme.error, const Color(0xFFF1415E));
    expect(theme.colorScheme.tertiary, const Color(0xFF21AB79));
    expect(theme.colorScheme.shadow, Colors.transparent);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
  });
}
