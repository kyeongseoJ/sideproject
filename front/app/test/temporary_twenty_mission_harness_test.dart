import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/mission/mission_models.dart';

void main() {
  test('three users keep completion, milestone, preference and World payloads', () {
    for (var user = 1; user <= 3; user++) {
      for (var completion = 1; completion <= 20; completion++) {
        final result = MissionActionResult.fromJson(_completionJson(completion));

        expect(result.summary?.completedMissionCount, completion);
        expect(result.worldGrowth?.rewardApplied, isTrue);
        expect(result.personalityChange?.currentNoveltyLevel, 2);
        expect(result.llmGenerationStatus, completion % 5 == 0 ? 'NOT_CONFIGURED' : 'NOT_DUE');
      }
    }
  });
}

Map<String, Object?> _completionJson(int completion) => {
  'mission': {
    'userMissionId': completion,
    'missionId': 1,
    'title': 'Harness mission',
    'description': 'Verify the completion contract.',
    'category': 'OUTDOOR',
    'difficulty': 2,
    'estimatedMinutes': 15,
    'indoorOutdoor': 1,
    'socialLevel': 1,
    'activityLevel': 2,
    'noveltyLevel': 2,
    'personalityDistance': 0.5,
    'status': 'COMPLETED',
  },
  'today': {
    'serviceDate': '2026-08-20',
    'completedToday': 1,
    'activeMissions': <Object?>[],
    'candidates': <Object?>[],
  },
  'idempotent': false,
  'completion': {
    'summary': {
      'completedMissionCount': completion,
      'lastPersonalityAdaptedCount': completion,
      'personalityCode': 'ACTIVE_CONNECTOR',
      'categoryStats': [
        {'category': 'OUTDOOR', 'completedCount': completion},
      ],
    },
    'personalityUpdated': completion == 1,
    'personalityChange': {
      'previousIndoorOutdoor': 0,
      'currentIndoorOutdoor': 1,
      'previousSocialLevel': 0,
      'currentSocialLevel': 1,
      'previousActivityLevel': 1,
      'currentActivityLevel': 2,
      'previousNoveltyLevel': 1,
      'currentNoveltyLevel': 2,
      'previousPersonalityCode': 'BALANCED_COORDINATOR',
      'currentPersonalityCode': 'ACTIVE_CONNECTOR',
    },
    'milestone': completion % 5 == 0 ? completion : 0,
    'llmGenerationStatus': completion % 5 == 0 ? 'NOT_CONFIGURED' : 'NOT_DUE',
    'worldGrowth': {
      'objectCode': 'OUTDOOR_SIGN',
      'categoryCode': 'OUTDOOR',
      'awardedExp': 20,
      'previousLevel': 1,
      'currentLevel': 1,
      'currentExp': completion * 20,
      'nextLevelRequiredExp': 100,
      'levelUp': false,
      'rewardApplied': true,
    },
  },
};
