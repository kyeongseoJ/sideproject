import 'dart:io';

import 'package:novelty_app/api/survey_api.dart';
import 'package:novelty_app/survey/survey_models.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/survey_e2e_check.dart <API_BASE_URL>');
    exitCode = 64;
    return;
  }

  final answers = SurveyAnswers()
    ..activityLevel = ActivityLevel.outdoor
    ..socialActivity = SocialActivity.high
    ..noveltyTolerance = NoveltyTolerance.low
    ..interests.addAll([
      Interest.movement,
      Interest.outdoor,
      Interest.organizing,
    ])
    ..energyLevel = EnergyLevel.medium;
  final api = SurveyApi(baseUrl: arguments.single);

  try {
    final result = await api.submit(answers);
    stdout.writeln('E2E_SURVEY_ID=${result.surveyId}');
    stdout.writeln('E2E_STATUS=${result.status}');
  } on SurveyApiException catch (exception) {
    stderr.writeln('E2E_ERROR=${exception.message}');
    exitCode = 1;
  } finally {
    api.close();
  }
}
