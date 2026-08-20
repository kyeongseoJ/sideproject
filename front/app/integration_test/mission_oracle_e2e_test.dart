import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/mission/mission_experience_screen.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_models.dart';

const bool _runOracleE2e = bool.fromEnvironment('RUN_MISSION_ORACLE_E2E');
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'Flutter REST Spring Boot Oracle mission normal and failure flow',
    (tester) async {
      final personalityApi = PersonalityApi(baseUrl: _apiBaseUrl);
      final missionApi = MissionApi(baseUrl: _apiBaseUrl);
      addTearDown(personalityApi.close);
      addTearDown(missionApi.close);

      final user = await personalityApi.createAnonymousUser();
      // 사용자 키는 출력하지 않는다. ID는 Oracle 사후 검증과 정리에만 사용한다.
      // ignore: avoid_print
      print('MISSION_PHASE7_E2E_USER_ID=${user.userId}');
      await personalityApi.submitAnalysis(
        user.userKey,
        PersonalityAnalysisRequest(
          submissionKey: '30000000-0000-4000-8000-000000000003',
          analysisMode: AnalysisMode.initial,
          answers: PersonalityAnswers(
            indoorOutdoor: IndoorOutdoor.indoor,
            socialLevel: SocialLevel.low,
            physicalActivityLevel: PhysicalActivityLevel.low,
            noveltyLevel: NoveltyLevel.low,
            interests: [PersonalityInterest.learning],
            executionStyle: ExecutionStyle.planned,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildNoveltyTheme(),
          home: MissionExperienceScreen(
            gateway: missionApi,
            userKey: user.userKey,
            onBackToProfile: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mission-settings-form')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mission-time-MEDIUM')));
      await tester.tap(find.byKey(const Key('mission-limit-1')));
      await tester.tap(find.byKey(const Key('mission-settings-save')));
      await tester.pumpAndSettle();
      expect(find.text('추천 미션'), findsOneWidget);
      expect(find.text('이 미션 선택'), findsWidgets);

      await tester.ensureVisible(find.text('이 미션 선택').first);
      await tester.tap(find.text('이 미션 선택').first);
      await tester.pumpAndSettle();
      expect(find.text('수행 중'), findsOneWidget);
      final completeButton = find.widgetWithText(FilledButton, '완료');
      expect(completeButton, findsOneWidget);

      await tester.ensureVisible(completeButton);
      await tester.pumpAndSettle();
      await tester.tap(completeButton);
      await tester.pumpAndSettle();
      expect(find.text('총 1개 완료'), findsOneWidget);

      final summary = await missionApi.getSummary(user.userKey);
      expect(summary.completedMissionCount, 1);
      expect(summary.categoryStats, isNotEmpty);

      await expectLater(
        missionApi.getToday('invalid-phase7-user-key'),
        throwsA(
          isA<MissionApiException>()
              .having((error) => error.statusCode, 'status', 401)
              .having((error) => error.code, 'code', 'INVALID_USER_KEY')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('invalid-phase7-user-key')),
              ),
        ),
      );
    },
    skip: !_runOracleE2e,
  );
}
