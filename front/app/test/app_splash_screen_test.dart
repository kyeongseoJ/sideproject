import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/app_splash_screen.dart';

void main() {
  testWidgets('shows the branded splash and then reveals app content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoveltySplashGate(
          duration: Duration(milliseconds: 100),
          child: Text('회원가입 화면'),
        ),
      ),
    );

    expect(find.byKey(const Key('novelty-splash')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('회원가입 화면'), findsNothing);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('novelty-splash')), findsNothing);
    expect(find.text('회원가입 화면'), findsOneWidget);
  });
}
