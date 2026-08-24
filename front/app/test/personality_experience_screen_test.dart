import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_experience_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';

void main() {
  testWidgets('moves from the first analysis form to the complete profile', (
    tester,
  ) async {
    final gateway = _FakeGateway(result: _newResult());
    await _pumpExperience(tester, gateway, _notAnalyzedUser());

    expect(find.text('쉬는 날의 나는?'), findsOneWidget);
    await _fillAndSubmit(tester);

    expect(
      find.byKey(const Key('personality-profile-content')),
      findsOneWidget,
    );
    expect(find.text('활기찬 연결가'), findsOneWidget);
    expect(gateway.requests.single.analysisMode, AnalysisMode.initial);
    expect(gateway.userKeys.single, 'cached-user-key');
  });

  testWidgets('restores an analyzed user directly to the complete profile', (
    tester,
  ) async {
    final gateway = _FakeGateway(result: _newResult());
    await _pumpExperience(tester, gateway, _analyzedUser());

    expect(
      find.byKey(const Key('personality-profile-content')),
      findsOneWidget,
    );
    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(find.byKey(const Key('personality-form')), findsNothing);
    expect(gateway.submitCalls, 0);
  });

  testWidgets('cancels reanalysis confirmation and keeps the current profile', (
    tester,
  ) async {
    final gateway = _FakeGateway(result: _newResult());
    await _pumpExperience(tester, gateway, _analyzedUser());

    await _openReanalysisDialog(tester);
    await tester.tap(
      find.byKey(const Key('personality-reanalysis-dialog-cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(find.byKey(const Key('personality-form')), findsNothing);
    expect(gateway.submitCalls, 0);
  });

  testWidgets('submits REANALYSIS and replaces the profile only on success', (
    tester,
  ) async {
    final gateway = _FakeGateway(result: _newResult());
    await _pumpExperience(tester, gateway, _analyzedUser());

    await _confirmReanalysis(tester);
    await _fillAndSubmit(tester);

    expect(find.text('활기찬 연결가'), findsOneWidget);
    expect(find.text('고요한 몰입가'), findsNothing);
    expect(gateway.requests.single.analysisMode, AnalysisMode.reanalysis);
    expect(
      gateway.requests.single.answers.indoorOutdoor,
      IndoorOutdoor.outdoor,
    );
  });

  testWidgets('keeps the old profile after failed reanalysis', (tester) async {
    final gateway = _FakeGateway(
      error: const PersonalityApiException(
        kind: PersonalityApiFailureKind.api,
        code: PersonalityApiErrorCode.personalitySaveFailed,
        statusCode: 500,
        message: '성향 정보를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      ),
    );
    await _pumpExperience(tester, gateway, _analyzedUser());

    await _confirmReanalysis(tester);
    await _fillAndSubmit(tester);

    expect(find.byKey(const Key('personality-submit-error')), findsOneWidget);
    expect(find.textContaining('저장하지 못했습니다.'), findsOneWidget);
    expect(find.text('고요한 몰입가'), findsNothing);

    await tester.tap(find.byKey(const Key('personality-form-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(find.text('활기찬 연결가'), findsNothing);
    expect(gateway.requests.single.analysisMode, AnalysisMode.reanalysis);
  });

  testWidgets('does not expose unexpected reanalysis failure details', (
    tester,
  ) async {
    final gateway = _FakeGateway(error: StateError('oracle-secret-detail'));
    await _pumpExperience(tester, gateway, _analyzedUser());

    await _confirmReanalysis(tester);
    await _fillAndSubmit(tester);

    expect(find.text('성향 분석을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('oracle-secret-detail'), findsNothing);
  });

  testWidgets(
    'renders the initial personality form without overflow on mobile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpExperience(tester, _FakeGateway(), _notAnalyzedUser());

      expect(find.text('쉬는 날의 나는?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openReanalysisDialog(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('personality-reanalyze-button')),
  );
  await tester.tap(find.byKey(const Key('personality-reanalyze-button')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('personality-reanalysis-dialog')),
    findsOneWidget,
  );
}

Future<void> _confirmReanalysis(WidgetTester tester) async {
  await _openReanalysisDialog(tester);
  await tester.tap(
    find.byKey(const Key('personality-reanalysis-dialog-confirm')),
  );
  await tester.pumpAndSettle();
  expect(find.text('쉬는 날의 나는?'), findsOneWidget);
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await _selectAndContinue(tester, 1, 'OUTDOOR');
  await _selectAndContinue(tester, 2, 'HIGH');
  await _selectAndContinue(tester, 3, 'HIGH');
  await _selectAndContinue(tester, 4, 'HIGH');
  await _selectAndContinue(tester, 5, 'MOVEMENT');
  await _tap(tester, 'personality-option-6-SPONTANEOUS');
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

Future<void> _pumpExperience(
  WidgetTester tester,
  _FakeGateway gateway,
  UserProfile user,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildNoveltyTheme(),
      home: PersonalityExperienceScreen(
        gateway: gateway,
        userKey: 'cached-user-key',
        initialUser: user,
      ),
    ),
  );
}

class _FakeGateway implements PersonalityGateway {
  _FakeGateway({this.result, this.error});

  final PersonalityAnalysisResult? result;
  final Object? error;
  final List<PersonalityAnalysisRequest> requests = [];
  final List<String> userKeys = [];
  int submitCalls = 0;
  int nicknameUpdateCalls = 0;

  @override
  Future<PersonalityAnalysisResult> submitAnalysis(
    String userKey,
    PersonalityAnalysisRequest request,
  ) async {
    submitCalls++;
    userKeys.add(userKey);
    requests.add(request);
    if (error != null) throw error!;
    return result ?? _newResult();
  }

  @override
  Future<AnonymousUser> createAnonymousUser() => throw UnimplementedError();

  @override
  Future<AnonymousUser> register(String loginId, String password) =>
      throw UnimplementedError();

  @override
  Future<AnonymousUser> login(String loginId, String password) =>
      throw UnimplementedError();

  @override
  Future<UserProfile> getCurrentUser(String userKey) =>
      throw UnimplementedError();

  @override
  Future<String> updateNickname(String userKey, String nickname) async {
    nicknameUpdateCalls++;
    return nickname;
  }
}

UserProfile _notAnalyzedUser() => const UserProfile(
  userId: 7,
  nickname: '노벨티07QK',
  personalityCompleted: false,
  personality: null,
);

UserProfile _analyzedUser() => UserProfile(
  userId: 7,
  nickname: '노벨티07QK',
  personalityCompleted: true,
  personality: _oldProfile(),
);

PersonalityAnalysisResult _newResult() => PersonalityAnalysisResult(
  analysisId: 84,
  status: 'ANALYZED',
  personality: PersonalityProfile(
    typeCode: 'ACTIVE_CONNECTOR',
    typeName: '활기찬 연결가',
    summary: '바깥에서 사람들과 함께 움직일 때 활력을 느껴요.',
    indoorOutdoor: IndoorOutdoor.outdoor,
    indoorOutdoorScore: 1,
    socialLevel: SocialLevel.high,
    socialScore: 1,
    physicalActivityLevel: PhysicalActivityLevel.high,
    physicalActivityScore: 2,
    noveltyLevel: NoveltyLevel.high,
    noveltyScore: 2,
    executionStyle: ExecutionStyle.spontaneous,
    interests: const [PersonalityInterest.movement],
    analysisVersion: 'PERSONALITY_V2',
    analyzedAt: DateTime.parse('2026-08-19T18:00:00+09:00'),
  ),
);

PersonalityProfile _oldProfile() => PersonalityProfile(
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
  interests: const [PersonalityInterest.creative, PersonalityInterest.learning],
  analysisVersion: 'PERSONALITY_V2',
  analyzedAt: DateTime.parse('2026-08-19T17:15:00+09:00'),
);
