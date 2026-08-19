import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_experience_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/personality/submission_key.dart';

const bool _runOracleE2e = bool.fromEnvironment('RUN_ORACLE_E2E');
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Flutter REST Spring Boot Oracle response Flutter full flow',
    (tester) async {
      final api = PersonalityApi(baseUrl: _apiBaseUrl);
      addTearDown(api.close);

      final anonymous = await api.createAnonymousUser();
      // 사용자 키는 출력하지 않는다. 이 ID는 후속 Oracle 검증과 정리에만 사용한다.
      // ignore: avoid_print
      print('PHASE7_E2E_USER_ID=${anonymous.userId}');

      final before = await api.getCurrentUser(anonymous.userKey);
      expect(before.personalityCompleted, isFalse);

      await expectLater(
        api.submitAnalysis(
          anonymous.userKey,
          _request(
            '00000000-0000-4000-8000-000000000009',
            AnalysisMode.reanalysis,
            IndoorOutdoor.outdoor,
          ),
        ),
        throwsA(
          isA<PersonalityApiException>().having(
            (error) => error.code,
            'code',
            PersonalityApiErrorCode.personalityNotAnalyzed,
          ),
        ),
      );

      final invalidResponse = await http.post(
        Uri.parse('$_apiBaseUrl/api/personality-analyses'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-User-Key': anonymous.userKey,
        },
        body: jsonEncode(<String, Object>{
          'submissionKey': '00000000-0000-4000-8000-000000000008',
          'analysisMode': 'INITIAL',
          'indoorOutdoor': 'INDOOR',
          'socialLevel': 'LOW',
          'physicalActivityLevel': 'MEDIUM',
          'noveltyLevel': 'HIGH',
          'interests': <String>[],
          'executionStyle': 'PLANNED',
        }),
      );
      expect(invalidResponse.statusCode, 400);
      expect(
        (jsonDecode(invalidResponse.body) as Map<String, Object?>)['code'],
        'INVALID_PERSONALITY_ANSWERS',
      );
      expect(invalidResponse.body, isNot(contains(anonymous.userKey)));

      final submissionSession = PersonalitySubmissionSession(
        generator: _SequenceSubmissionKeys(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildNoveltyTheme(),
          home: PersonalityExperienceScreen(
            key: const ValueKey<String>('phase7-initial'),
            gateway: api,
            userKey: anonymous.userKey,
            initialUser: before,
            submissionSession: submissionSession,
          ),
        ),
      );
      await _fillAndSubmit(
        tester,
        indoorOutdoor: 'INDOOR',
        socialLevel: 'LOW',
        physicalActivityLevel: 'MEDIUM',
        noveltyLevel: 'HIGH',
        interest: 'CREATIVE',
        executionStyle: 'PLANNED',
      );

      expect(find.text('고요한 몰입가'), findsOneWidget);

      final initialRequest = _request(
        _SequenceSubmissionKeys.initialKey,
        AnalysisMode.initial,
        IndoorOutdoor.indoor,
      );
      final firstRetry = await api.submitAnalysis(
        anonymous.userKey,
        initialRequest,
      );
      final secondRetry = await api.submitAnalysis(
        anonymous.userKey,
        initialRequest,
      );
      expect(secondRetry.analysisId, firstRetry.analysisId);

      await expectLater(
        api.submitAnalysis(
          anonymous.userKey,
          _request(
            _SequenceSubmissionKeys.initialKey,
            AnalysisMode.initial,
            IndoorOutdoor.outdoor,
          ),
        ),
        throwsA(
          isA<PersonalityApiException>().having(
            (error) => error.code,
            'code',
            PersonalityApiErrorCode.submissionKeyConflict,
          ),
        ),
      );
      await expectLater(
        api.submitAnalysis(
          anonymous.userKey,
          _request(
            '00000000-0000-4000-8000-000000000007',
            AnalysisMode.initial,
            IndoorOutdoor.indoor,
          ),
        ),
        throwsA(
          isA<PersonalityApiException>().having(
            (error) => error.code,
            'code',
            PersonalityApiErrorCode.personalityAlreadyAnalyzed,
          ),
        ),
      );

      final restored = await api.getCurrentUser(anonymous.userKey);
      expect(restored.personalityCompleted, isTrue);
      expect(restored.personality?.typeCode, 'QUIET_FOCUSER');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildNoveltyTheme(),
          home: PersonalityExperienceScreen(
            key: const ValueKey<String>('phase7-restored'),
            gateway: api,
            userKey: anonymous.userKey,
            initialUser: restored,
            submissionSession: submissionSession,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('고요한 몰입가'), findsOneWidget);
      expect(find.byKey(const Key('personality-form')), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('personality-reanalyze-button')),
      );
      await tester.tap(find.byKey(const Key('personality-reanalyze-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('personality-reanalysis-dialog-confirm')),
      );
      await tester.pumpAndSettle();
      await _fillAndSubmit(
        tester,
        indoorOutdoor: 'OUTDOOR',
        socialLevel: 'HIGH',
        physicalActivityLevel: 'HIGH',
        noveltyLevel: 'HIGH',
        interest: 'MOVEMENT',
        executionStyle: 'SPONTANEOUS',
      );

      expect(find.text('활기찬 연결가'), findsOneWidget);
      final afterReanalysis = await api.getCurrentUser(anonymous.userKey);
      expect(afterReanalysis.personality?.typeCode, 'ACTIVE_CONNECTOR');
      expect(afterReanalysis.personality?.interests, [
        PersonalityInterest.movement,
      ]);

      await expectLater(
        api.getCurrentUser('phase7-invalid-user-key'),
        throwsA(
          isA<PersonalityApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.code,
                'code',
                PersonalityApiErrorCode.invalidUserKey,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('phase7-invalid-user-key')),
              ),
        ),
      );
    },
    skip: !_runOracleE2e,
  );
}

PersonalityAnalysisRequest _request(
  String submissionKey,
  AnalysisMode mode,
  IndoorOutdoor indoorOutdoor,
) {
  return PersonalityAnalysisRequest(
    submissionKey: submissionKey,
    analysisMode: mode,
    answers: PersonalityAnswers(
      indoorOutdoor: indoorOutdoor,
      socialLevel: indoorOutdoor == IndoorOutdoor.outdoor
          ? SocialLevel.high
          : SocialLevel.low,
      physicalActivityLevel: indoorOutdoor == IndoorOutdoor.outdoor
          ? PhysicalActivityLevel.high
          : PhysicalActivityLevel.medium,
      noveltyLevel: NoveltyLevel.high,
      interests: [
        indoorOutdoor == IndoorOutdoor.outdoor
            ? PersonalityInterest.movement
            : PersonalityInterest.creative,
      ],
      executionStyle: indoorOutdoor == IndoorOutdoor.outdoor
          ? ExecutionStyle.spontaneous
          : ExecutionStyle.planned,
    ),
  );
}

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  required String indoorOutdoor,
  required String socialLevel,
  required String physicalActivityLevel,
  required String noveltyLevel,
  required String interest,
  required String executionStyle,
}) async {
  await _selectAndContinue(tester, 1, indoorOutdoor);
  await _selectAndContinue(tester, 2, socialLevel);
  await _selectAndContinue(tester, 3, physicalActivityLevel);
  await _selectAndContinue(tester, 4, noveltyLevel);
  await _selectAndContinue(tester, 5, interest);
  await _tap(tester, 'personality-option-6-$executionStyle');
  await _tap(tester, 'personality-submit-button');
  await tester.pumpAndSettle();
}

Future<void> _selectAndContinue(
  WidgetTester tester,
  int question,
  String code,
) async {
  await _tap(tester, 'personality-option-$question-$code');
  await _tap(tester, 'personality-next-button');
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

class _SequenceSubmissionKeys implements SubmissionKeyGenerator {
  static const String initialKey = '10000000-0000-4000-8000-000000000001';
  static const String reanalysisKey = '20000000-0000-4000-8000-000000000002';

  int _index = 0;

  @override
  String generate() {
    final keys = <String>[initialKey, reanalysisKey];
    if (_index >= keys.length) {
      throw StateError('No more Phase 7 submission keys.');
    }
    return keys[_index++];
  }
}
