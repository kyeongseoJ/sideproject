enum ActivityLevel {
  indoor('INDOOR'),
  mixed('MIXED'),
  outdoor('OUTDOOR');

  const ActivityLevel(this.code);
  final String code;
}

enum SocialActivity {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const SocialActivity(this.code);
  final String code;
}

enum NoveltyTolerance {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const NoveltyTolerance(this.code);
  final String code;
}

enum Interest {
  movement('MOVEMENT'),
  creative('CREATIVE'),
  food('FOOD'),
  learning('LEARNING'),
  social('SOCIAL'),
  outdoor('OUTDOOR'),
  organizing('ORGANIZING'),
  culture('CULTURE');

  const Interest(this.code);
  final String code;
}

enum EnergyLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const EnergyLevel(this.code);
  final String code;
}

class SurveyAnswers {
  ActivityLevel? activityLevel;
  SocialActivity? socialActivity;
  NoveltyTolerance? noveltyTolerance;
  final Set<Interest> interests = <Interest>{};
  EnergyLevel? energyLevel;

  bool isStepComplete(int step) {
    return switch (step) {
      0 => activityLevel != null,
      1 => socialActivity != null,
      2 => noveltyTolerance != null,
      3 => interests.isNotEmpty && interests.length <= 3,
      4 => energyLevel != null,
      _ => false,
    };
  }

  bool get isComplete =>
      activityLevel != null &&
      socialActivity != null &&
      noveltyTolerance != null &&
      interests.isNotEmpty &&
      interests.length <= 3 &&
      energyLevel != null;

  Map<String, Object> toJson() {
    if (!isComplete) {
      throw StateError('모든 설문 문항에 응답해야 합니다.');
    }

    return <String, Object>{
      'activityLevel': activityLevel!.code,
      'socialActivity': socialActivity!.code,
      'noveltyTolerance': noveltyTolerance!.code,
      'interests': interests.map((interest) => interest.code).toList(),
      'energyLevel': energyLevel!.code,
    };
  }
}

class SurveySaveResult {
  const SurveySaveResult({required this.surveyId, required this.status});

  final int surveyId;
  final String status;

  factory SurveySaveResult.fromJson(Map<String, Object?> json) {
    final surveyId = json['surveyId'];
    final status = json['status'];

    if (surveyId is! int ||
        surveyId <= 0 ||
        status is! String ||
        status != 'SAVED') {
      throw const FormatException('Invalid survey save response.');
    }

    return SurveySaveResult(surveyId: surveyId, status: status);
  }
}
