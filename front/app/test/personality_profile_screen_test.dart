import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/mission/behavior_preference_change.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/profile/personality_profile_screen.dart';

void main() {
  testWidgets('shows every required personality profile field', (tester) async {
    var reanalyzeCalls = 0;
    await _pumpProfile(tester, onReanalyze: () => reanalyzeCalls++);

    expect(find.byKey(const Key('novelty-wordmark')), findsOneWidget);
    expect(find.byKey(const Key('novelty-symbol')), findsOneWidget);
    expect(find.text('노벨티07QK'), findsNothing);
    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(find.textContaining('익숙하고 조용한 공간'), findsOneWidget);
    expect(find.textContaining('실내 중심'), findsOneWidget);
    expect(find.textContaining('혼자 하는 편'), findsOneWidget);
    expect(find.textContaining('가벼운 움직임'), findsOneWidget);
    expect(find.textContaining('큰 새로움'), findsOneWidget);
    expect(find.text('계획 실행형'), findsOneWidget);
    expect(find.text('만들기'), findsOneWidget);
    expect(find.text('배우기'), findsOneWidget);
    expect(
      find.text('마지막 분석 2026.08.19 17:15\nPERSONALITY_V2'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(find.text('0 / 100'), findsNWidgets(2));
    expect(find.text('50 / 100'), findsOneWidget);
    expect(find.text('100 / 100'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('personality-reanalyze-button')),
    );
    await tester.tap(find.byKey(const Key('personality-reanalyze-button')));
    expect(reanalyzeCalls, 1);
  });

  testWidgets('separates interests and behavior preference sections', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.byKey(const Key('personality-summary-card')), findsOneWidget);
    expect(
      find.byKey(const Key('personality-profile-interests')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('personality-profile-traits')), findsOneWidget);
  });

  testWidgets('renders without overflow on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProfile(tester);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personality-reanalyze-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the latest mission preference direction separately', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      lastPreferenceChange: const BehaviorPreferenceChange(
        indoorOutdoor: 1,
        social: 0,
        activity: 1,
        novelty: -1,
      ),
    );

    expect(find.byKey(const Key('behavior-preference-change')), findsOneWidget);
    expect(find.text('실외 경험 +1'), findsOneWidget);
    expect(find.text('활동성 경험 +1'), findsOneWidget);
    expect(find.text('익숙함 경험 +1'), findsOneWidget);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  VoidCallback? onReanalyze,
  BehaviorPreferenceChange? lastPreferenceChange,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildNoveltyTheme(),
      home: PersonalityProfileScreen(
        user: _analyzedUser(),
        onReanalyze: onReanalyze ?? () {},
        lastPreferenceChange: lastPreferenceChange,
      ),
    ),
  );
}

UserProfile _analyzedUser() => UserProfile(
  userId: 7,
  nickname: '노벨티07QK',
  personalityCompleted: true,
  personality: PersonalityProfile(
    typeCode: 'QUIET_FOCUSER',
    typeName: '고요한 몰입가',
    summary: '익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.',
    indoorOutdoor: IndoorOutdoor.indoor,
    indoorOutdoorScore: -1,
    socialLevel: SocialLevel.low,
    socialScore: -1,
    physicalActivityLevel: PhysicalActivityLevel.medium,
    physicalActivityScore: 1,
    noveltyLevel: NoveltyLevel.high,
    noveltyScore: 2,
    executionStyle: ExecutionStyle.planned,
    interests: const [
      PersonalityInterest.creative,
      PersonalityInterest.learning,
    ],
    analysisVersion: 'PERSONALITY_V2',
    analyzedAt: DateTime.parse('2026-08-19T08:15:00Z'),
  ),
);
