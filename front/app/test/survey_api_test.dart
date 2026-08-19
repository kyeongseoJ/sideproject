import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelty_app/api/survey_api.dart';
import 'package:novelty_app/survey/survey_models.dart';

void main() {
  test('posts the survey contract and parses a created response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://localhost:8080/api/surveys');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {
        'activityLevel': 'INDOOR',
        'socialActivity': 'LOW',
        'noveltyTolerance': 'MEDIUM',
        'interests': ['CREATIVE', 'FOOD'],
        'energyLevel': 'HIGH',
      });
      return http.Response(
        jsonEncode({'surveyId': 21, 'status': 'SAVED'}),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SurveyApi(client: client, baseUrl: 'http://localhost:8080/');

    final result = await api.submit(_completeAnswers());

    expect(result.surveyId, 21);
    expect(result.status, 'SAVED');
    api.close();
  });

  test('uses the safe server message for an error response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'code': 'INVALID_SURVEY',
          'message': '관심 활동은 1개 이상 3개 이하로 선택해야 합니다.',
        }),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = SurveyApi(client: client, baseUrl: 'http://localhost:8080');

    await expectLater(
      api.submit(_completeAnswers()),
      throwsA(
        isA<SurveyApiException>().having(
          (exception) => exception.message,
          'message',
          '관심 활동은 1개 이상 3개 이하로 선택해야 합니다.',
        ),
      ),
    );
    api.close();
  });

  test('rejects submission when API_BASE_URL is missing', () async {
    final api = SurveyApi(
      client: MockClient((_) async => http.Response('', 500)),
      baseUrl: '',
    );

    await expectLater(
      api.submit(_completeAnswers()),
      throwsA(
        isA<SurveyApiException>().having(
          (exception) => exception.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
    api.close();
  });

  test('rejects a malformed success response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'surveyId': 0, 'status': 'UNKNOWN'}),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = SurveyApi(client: client, baseUrl: 'http://localhost:8080');

    await expectLater(
      api.submit(_completeAnswers()),
      throwsA(
        isA<SurveyApiException>().having(
          (exception) => exception.message,
          'message',
          contains('서버 응답'),
        ),
      ),
    );
    api.close();
  });
}

SurveyAnswers _completeAnswers() {
  return SurveyAnswers()
    ..activityLevel = ActivityLevel.indoor
    ..socialActivity = SocialActivity.low
    ..noveltyTolerance = NoveltyTolerance.medium
    ..interests.addAll([Interest.creative, Interest.food])
    ..energyLevel = EnergyLevel.high;
}
