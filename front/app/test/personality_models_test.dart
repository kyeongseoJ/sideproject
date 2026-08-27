import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/personality/personality_models.dart';

void main() {
  test('serializes the six-question V2 request without V1 fields', () {
    final request = PersonalityAnalysisRequest(
      submissionKey: '2c3ed6f9-5780-4da8-9c73-830ce137b899',
      analysisMode: AnalysisMode.initial,
      answers: PersonalityAnswers(
        indoorOutdoor: IndoorOutdoor.indoor,
        socialLevel: SocialLevel.low,
        physicalActivityLevel: PhysicalActivityLevel.medium,
        noveltyLevel: NoveltyLevel.high,
        interests: const [
          PersonalityInterest.creative,
          PersonalityInterest.learning,
        ],
        executionStyle: ExecutionStyle.planned,
      ),
    );

    expect(request.toJson(), {
      'submissionKey': '2c3ed6f9-5780-4da8-9c73-830ce137b899',
      'analysisMode': 'INITIAL',
      'indoorOutdoor': 'INDOOR',
      'socialLevel': 'LOW',
      'physicalActivityLevel': 'MEDIUM',
      'noveltyLevel': 'HIGH',
      'interests': ['CREATIVE', 'LEARNING'],
      'executionStyle': 'PLANNED',
    });
    expect(request.toJson(), isNot(contains('activityLevel')));
    expect(request.toJson(), isNot(contains('energyLevel')));
  });

  test('rejects empty, excessive, and duplicate interests locally', () {
    expect(() => _answers(const []), throwsArgumentError);
    expect(
      () => _answers(const [
        PersonalityInterest.creative,
        PersonalityInterest.learning,
        PersonalityInterest.food,
        PersonalityInterest.culture,
      ]),
      throwsArgumentError,
    );
    expect(
      () => _answers(const [
        PersonalityInterest.creative,
        PersonalityInterest.creative,
      ]),
      throwsArgumentError,
    );
  });

  test('parses a complete analyzed user profile', () {
    final user = UserProfile.fromJson({
      'userId': 7,
      'nickname': '노벨티07QK',
      'personalityCompleted': true,
      'personality': validPersonalityJson(),
    });

    expect(user.personalityCompleted, isTrue);
    expect(user.personality?.typeCode, 'QUIET_FOCUSER');
    expect(user.personality?.indoorOutdoorScore, -1);
    expect(user.personality?.physicalActivityScore, 1);
    expect(user.personality?.interests, [
      PersonalityInterest.creative,
      PersonalityInterest.learning,
    ]);
    expect(user.personality?.analysisVersion, 'PERSONALITY_V2');
  });

  test('rejects inconsistent or malformed user profile responses', () {
    expect(
      () => UserProfile.fromJson({
        'userId': 7,
        'nickname': '노벨티07QK',
        'personalityCompleted': true,
        'personality': null,
      }),
      throwsFormatException,
    );
    expect(
      () => UserProfile.fromJson({
        'userId': 7,
        'nickname': '노벨티07QK',
        'personalityCompleted': false,
        'personality': validPersonalityJson(),
      }),
      throwsFormatException,
    );
    final invalidVersion = validPersonalityJson()
      ..['analysisVersion'] = 'PERSONALITY_V1';
    expect(
      () => PersonalityProfile.fromJson(invalidVersion),
      throwsFormatException,
    );
  });

  test('parses both newly-created and idempotent analysis result bodies', () {
    final result = PersonalityAnalysisResult.fromJson({
      'analysisId': 42,
      'status': 'ANALYZED',
      'personality': validPersonalityJson(),
    });

    expect(result.analysisId, 42);
    expect(result.personality.typeName, '고요한 몰입가');
  });

  test(
    'applies completed mission scores to the visible personality profile',
    () {
      final original = PersonalityProfile.fromJson(validPersonalityJson());
      final updated = original.withPreferenceScores(
        indoorOutdoorScore: 0,
        socialScore: 1,
        physicalActivityScore: 2,
        noveltyScore: 0,
      );

      expect(updated.indoorOutdoor, IndoorOutdoor.mixed);
      expect(updated.indoorOutdoorScore, 0);
      expect(updated.socialLevel, SocialLevel.high);
      expect(updated.socialScore, 1);
      expect(updated.physicalActivityLevel, PhysicalActivityLevel.high);
      expect(updated.physicalActivityScore, 2);
      expect(updated.noveltyLevel, NoveltyLevel.low);
      expect(updated.noveltyScore, 0);
    },
  );
}

PersonalityAnswers _answers(List<PersonalityInterest> interests) {
  return PersonalityAnswers(
    indoorOutdoor: IndoorOutdoor.indoor,
    socialLevel: SocialLevel.low,
    physicalActivityLevel: PhysicalActivityLevel.medium,
    noveltyLevel: NoveltyLevel.high,
    interests: interests,
    executionStyle: ExecutionStyle.planned,
  );
}

Map<String, Object?> validPersonalityJson() => <String, Object?>{
  'typeCode': 'QUIET_FOCUSER',
  'typeName': '고요한 몰입가',
  'summary': '익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.',
  'indoorOutdoor': 'INDOOR',
  'indoorOutdoorScore': -1,
  'socialLevel': 'LOW',
  'socialScore': -1,
  'physicalActivityLevel': 'MEDIUM',
  'physicalActivityScore': 1,
  'noveltyLevel': 'HIGH',
  'noveltyScore': 2,
  'executionStyle': 'PLANNED',
  'interests': ['CREATIVE', 'LEARNING'],
  'analysisVersion': 'PERSONALITY_V2',
  'analyzedAt': '2026-08-19T17:15:00+09:00',
};
