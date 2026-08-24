import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_form_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/personality/submission_key.dart';

void main() {
  testWidgets('requires an answer before moving to the next question', (
    tester,
  ) async {
    await _pumpForm(tester, _FakeGateway());

    expect(find.text('쉬는 날의 나는?'), findsOneWidget);
    expect(find.byKey(const Key('personality-back-button')), findsNothing);
    expect(_filledButton(tester, 'personality-next-button').onPressed, isNull);

    await _tap(tester, 'personality-option-1-INDOOR');
    expect(
      _filledButton(tester, 'personality-next-button').onPressed,
      isNotNull,
    );

    await _tap(tester, 'personality-next-button');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personality-back-button')), findsOneWidget);
  });

  testWidgets('shows all six questions and submits the exact V2 answers', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _fillForm(tester, gateway);

    await _tap(tester, 'personality-submit-button');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personality-analysis-result')),
      findsOneWidget,
    );
    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(gateway.submitCalls, 1);
    expect(gateway.userKeys.single, 'cached-user-key');
    expect(gateway.requests.single.analysisMode, AnalysisMode.initial);
    expect(gateway.requests.single.answers.toJson(), {
      'indoorOutdoor': 'INDOOR',
      'socialLevel': 'LOW',
      'physicalActivityLevel': 'MEDIUM',
      'noveltyLevel': 'HIGH',
      'interests': ['CREATIVE'],
      'executionStyle': 'PLANNED',
    });
    expect(gateway.requests.single.toJson(), isNot(contains('energyLevel')));
    expect(gateway.requests.single.toJson(), isNot(contains('activityLevel')));
  });

  testWidgets('keeps selected answers while moving backward and forward', (
    tester,
  ) async {
    await _pumpForm(tester, _FakeGateway());
    await _selectAndContinue(tester, 1, 'OUTDOOR');
    await _selectAndContinue(tester, 2, 'HIGH');

    await _tap(tester, 'personality-back-button');
    await tester.pumpAndSettle();
    final social = _optionSemantics(tester, 'personality-option-2-HIGH');
    expect(social.properties.selected, isTrue);

    await _tap(tester, 'personality-back-button');
    await tester.pumpAndSettle();
    final location = _optionSemantics(tester, 'personality-option-1-OUTDOOR');
    expect(location.properties.selected, isTrue);
  });

  testWidgets('requires one interest and immediately blocks a fourth', (
    tester,
  ) async {
    await _goToInterests(tester, _FakeGateway());

    expect(find.text('0 / 3 선택'), findsOneWidget);
    expect(
      find.byKey(const Key('personality-interest-required')),
      findsOneWidget,
    );
    expect(_filledButton(tester, 'personality-next-button').onPressed, isNull);

    await _tap(tester, 'personality-option-5-CREATIVE');
    await _tap(tester, 'personality-option-5-FOOD');
    await _tap(tester, 'personality-option-5-LEARNING');
    expect(find.text('3 / 3 선택'), findsOneWidget);

    await _tap(tester, 'personality-option-5-CULTURE');
    await tester.pump();
    expect(find.text('관심 분야는 최대 3개까지 선택할 수 있어요.'), findsOneWidget);
    final fourth = _optionSemantics(tester, 'personality-option-5-CULTURE');
    expect(fourth.properties.selected, isFalse);
  });

  testWidgets('locks navigation and blocks duplicate submission', (
    tester,
  ) async {
    final completer = Completer<PersonalityAnalysisResult>();
    final gateway = _FakeGateway(submit: (_) => completer.future);
    await _fillForm(tester, gateway);

    await _tap(tester, 'personality-submit-button');
    await tester.pump();

    expect(find.text('분석 중...'), findsOneWidget);
    expect(
      _filledButton(tester, 'personality-submit-button').onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('personality-back-button')),
          )
          .onPressed,
      isNull,
    );
    expect(gateway.submitCalls, 1);

    completer.complete(_analysisResult());
    await tester.pumpAndSettle();
    expect(gateway.submitCalls, 1);
  });

  testWidgets('keeps answers and submission key when a request is retried', (
    tester,
  ) async {
    var attempts = 0;
    final gateway = _FakeGateway(
      submit: (_) async {
        attempts++;
        if (attempts == 1) {
          throw const PersonalityApiException(
            kind: PersonalityApiFailureKind.network,
            message: '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
          );
        }
        return _analysisResult();
      },
    );
    final session = PersonalitySubmissionSession(generator: _SequenceKey());
    await _fillForm(tester, gateway, session: session);

    await _tap(tester, 'personality-submit-button');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personality-submit-error')), findsOneWidget);
    expect(find.textContaining('서버에 연결하지 못했습니다.'), findsOneWidget);
    expect(
      gateway.requests.single.answers.executionStyle,
      ExecutionStyle.planned,
    );

    await _tap(tester, 'personality-retry-button');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personality-analysis-result')),
      findsOneWidget,
    );
    expect(gateway.submitCalls, 2);
    expect(gateway.requests[0].submissionKey, 'submission-1');
    expect(gateway.requests[1].submissionKey, 'submission-1');
    expect(gateway.requests[1].answers.executionStyle, ExecutionStyle.planned);
  });

  testWidgets('hides unexpected exception details behind a safe message', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      submit: (_) async => throw StateError('database-secret-detail'),
    );
    await _fillForm(tester, gateway);

    await _tap(tester, 'personality-submit-button');
    await tester.pumpAndSettle();

    expect(find.text('성향 분석을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('database-secret-detail'), findsNothing);
  });

  testWidgets('renders the form without overflow on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpForm(tester, _FakeGateway());
    await _selectAndContinue(tester, 1, 'INDOOR');
    await _selectAndContinue(tester, 2, 'LOW');
    await _selectAndContinue(tester, 3, 'LOW');
    await _selectAndContinue(tester, 4, 'LOW');

    expect(find.text('어떤 활동에 관심이 있나요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

FilledButton _filledButton(WidgetTester tester, String key) {
  return tester.widget<FilledButton>(find.byKey(Key(key)));
}

Semantics _optionSemantics(WidgetTester tester, String key) {
  return tester.widget<Semantics>(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
    ),
  );
}

Future<void> _goToInterests(WidgetTester tester, _FakeGateway gateway) async {
  await _pumpForm(tester, gateway);
  await _selectAndContinue(tester, 1, 'INDOOR');
  await _selectAndContinue(tester, 2, 'LOW');
  await _selectAndContinue(tester, 3, 'MEDIUM');
  await _selectAndContinue(tester, 4, 'HIGH');
}

Future<void> _fillForm(
  WidgetTester tester,
  _FakeGateway gateway, {
  PersonalitySubmissionSession? session,
}) async {
  await _pumpForm(tester, gateway, session: session);
  await _selectAndContinue(tester, 1, 'INDOOR');
  await _selectAndContinue(tester, 2, 'LOW');
  await _selectAndContinue(tester, 3, 'MEDIUM');
  await _selectAndContinue(tester, 4, 'HIGH');
  await _selectAndContinue(tester, 5, 'CREATIVE');
  await _tap(tester, 'personality-option-6-PLANNED');
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

Future<void> _pumpForm(
  WidgetTester tester,
  _FakeGateway gateway, {
  PersonalitySubmissionSession? session,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildNoveltyTheme(),
      home: PersonalityFormScreen(
        gateway: gateway,
        userKey: 'cached-user-key',
        nickname: '노벨티07QK',
        submissionSession: session,
      ),
    ),
  );
}

class _FakeGateway implements PersonalityGateway {
  _FakeGateway({
    Future<PersonalityAnalysisResult> Function(PersonalityAnalysisRequest)?
    submit,
  }) : _submit = submit;

  final Future<PersonalityAnalysisResult> Function(PersonalityAnalysisRequest)?
  _submit;
  final List<PersonalityAnalysisRequest> requests = [];
  final List<String> userKeys = [];
  int submitCalls = 0;

  @override
  Future<PersonalityAnalysisResult> submitAnalysis(
    String userKey,
    PersonalityAnalysisRequest request,
  ) async {
    submitCalls++;
    userKeys.add(userKey);
    requests.add(request);
    return _submit == null ? _analysisResult() : await _submit(request);
  }

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
  Future<String> updateNickname(String userKey, String nickname) async =>
      nickname;
}

class _SequenceKey implements SubmissionKeyGenerator {
  int calls = 0;

  @override
  String generate() => 'submission-${++calls}';
}

PersonalityAnalysisResult _analysisResult() => PersonalityAnalysisResult(
  analysisId: 42,
  status: 'ANALYZED',
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
    interests: const [PersonalityInterest.creative],
    analysisVersion: 'PERSONALITY_V2',
    analyzedAt: DateTime.parse('2026-08-19T17:15:00+09:00'),
  ),
);
