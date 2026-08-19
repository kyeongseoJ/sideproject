import 'package:flutter/material.dart';
import 'package:novelty_app/api/survey_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/survey/survey_screen.dart';

void main() {
  runApp(const NoveltyApp());
}

class NoveltyApp extends StatelessWidget {
  const NoveltyApp({super.key, this.surveySubmitter});

  final SurveySubmitter? surveySubmitter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novelty',
      debugShowCheckedModeBanner: false,
      theme: buildNoveltyTheme(),
      home: SurveyScreen(submitter: surveySubmitter),
    );
  }
}
