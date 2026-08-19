import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/survey_api.dart';
import 'package:novelty_app/main.dart';
import 'package:novelty_app/survey/survey_models.dart';

void main() {
  test('serializes answers with the backend contract codes', () {
    final answers = SurveyAnswers()
      ..activityLevel = ActivityLevel.indoor
      ..socialActivity = SocialActivity.low
      ..noveltyTolerance = NoveltyTolerance.medium
      ..interests.addAll([Interest.creative, Interest.food, Interest.culture])
      ..energyLevel = EnergyLevel.low;

    expect(answers.toJson(), {
      'activityLevel': 'INDOOR',
      'socialActivity': 'LOW',
      'noveltyTolerance': 'MEDIUM',
      'interests': ['CREATIVE', 'FOOD', 'CULTURE'],
      'energyLevel': 'LOW',
    });
  });

  testWidgets('requires an answer before moving to the next question', (
    tester,
  ) async {
    await tester.pumpWidget(const NoveltyApp());
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();

    FilledButton nextButton = tester.widget(
      find.byKey(const Key('next-button')),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('option-INDOOR')));
    await tester.pump();

    nextButton = tester.widget(find.byKey(const Key('next-button')));
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('keeps answers while moving backward', (tester) async {
    await tester.pumpWidget(const NoveltyApp());
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option-INDOOR')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pumpAndSettle();

    final option = tester.widget<Semantics>(
      find.byKey(const Key('option-INDOOR')),
    );
    expect(option.properties.selected, isTrue);
  });

  testWidgets('limits interests to three selections', (tester) async {
    await _moveToInterestQuestion(tester);

    await tester.tap(find.byKey(const Key('option-MOVEMENT')));
    await tester.tap(find.byKey(const Key('option-CREATIVE')));
    await tester.tap(find.byKey(const Key('option-FOOD')));
    await tester.tap(find.byKey(const Key('option-LEARNING')));
    await tester.pump();

    expect(find.text('3 / 3 선택'), findsOneWidget);
    expect(find.text('관심 활동은 최대 3개까지 선택할 수 있어요.'), findsOneWidget);
    final fourth = tester.widget<Semantics>(
      find.byKey(const Key('option-LEARNING')),
    );
    expect(fourth.properties.selected, isFalse);
  });

  testWidgets('shows the returned survey id after a successful save', (
    tester,
  ) async {
    final submitter = _FakeSurveySubmitter(
      (_) async => const SurveySaveResult(surveyId: 42, status: 'SAVED'),
    );
    await _fillSurvey(tester, submitter);

    await tester.tap(find.byKey(const Key('complete-button')));
    await tester.pumpAndSettle();

    expect(find.text('설문이 저장됐어요'), findsOneWidget);
    expect(find.textContaining('저장 번호 42'), findsOneWidget);
    expect(submitter.callCount, 1);
  });

  testWidgets('blocks duplicate submission while saving', (tester) async {
    final completer = Completer<SurveySaveResult>();
    final submitter = _FakeSurveySubmitter((_) => completer.future);
    await _fillSurvey(tester, submitter);

    await tester.tap(find.byKey(const Key('complete-button')));
    await tester.pump();

    expect(find.text('저장 중...'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('complete-button')),
    );
    expect(button.onPressed, isNull);
    expect(submitter.callCount, 1);

    completer.complete(const SurveySaveResult(surveyId: 43, status: 'SAVED'));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장 번호 43'), findsOneWidget);
  });

  testWidgets('keeps answers and retries after a failed save', (tester) async {
    var attempts = 0;
    final submitter = _FakeSurveySubmitter((_) async {
      attempts++;
      if (attempts == 1) {
        throw const SurveyApiException('서버에 연결하지 못했습니다.');
      }
      return const SurveySaveResult(surveyId: 44, status: 'SAVED');
    });
    await _fillSurvey(tester, submitter);

    await tester.tap(find.byKey(const Key('complete-button')));
    await tester.pumpAndSettle();

    expect(find.text('서버에 연결하지 못했습니다.'), findsOneWidget);
    final selectedEnergy = tester.widget<Semantics>(
      find.byKey(const Key('option-HIGH')),
    );
    expect(selectedEnergy.properties.selected, isTrue);

    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장 번호 44'), findsOneWidget);
    expect(submitter.callCount, 2);
  });
}

Future<void> _moveToInterestQuestion(WidgetTester tester) async {
  await tester.pumpWidget(const NoveltyApp());
  await tester.tap(find.byKey(const Key('start-button')));
  await tester.pumpAndSettle();
  await _selectAndContinue(tester, 'INDOOR');
  await _selectAndContinue(tester, 'LOW');
  await _selectAndContinue(tester, 'MEDIUM');
}

Future<void> _selectAndContinue(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(Key('option-$code')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('next-button')));
  await tester.pumpAndSettle();
}

Future<void> _fillSurvey(WidgetTester tester, SurveySubmitter submitter) async {
  await tester.pumpWidget(NoveltyApp(surveySubmitter: submitter));
  await tester.tap(find.byKey(const Key('start-button')));
  await tester.pumpAndSettle();
  await _selectAndContinue(tester, 'INDOOR');
  await _selectAndContinue(tester, 'LOW');
  await _selectAndContinue(tester, 'MEDIUM');
  await _selectAndContinue(tester, 'CREATIVE');
  await tester.tap(find.byKey(const Key('option-HIGH')));
  await tester.pump();
}

class _FakeSurveySubmitter implements SurveySubmitter {
  _FakeSurveySubmitter(this.callback);

  final Future<SurveySaveResult> Function(SurveyAnswers answers) callback;
  int callCount = 0;

  @override
  Future<SurveySaveResult> submit(SurveyAnswers answers) {
    callCount++;
    return callback(answers);
  }
}
