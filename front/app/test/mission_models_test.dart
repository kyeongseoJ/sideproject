import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/mission/mission_models.dart';

void main() {
  test('uses the canonical mission category codes', () {
    expect(MissionCategory.values.map((value) => value.code), {
      'MOVEMENT',
      'CREATIVE',
      'FOOD',
      'LEARNING',
      'SOCIAL',
      'OUTDOOR',
      'ORGANIZING',
      'CULTURE',
    });
  });

  test('parses a valid mission and maps UI status labels', () {
    final mission = UserMission.fromJson({
      'userMissionId': 1,
      'missionId': 2,
      'title': '낯선 음악 듣기',
      'description': '처음 듣는 장르를 골라 보세요.',
      'category': 'CULTURE',
      'difficulty': 1,
      'estimatedMinutes': 15,
      'indoorOutdoor': -1,
      'socialLevel': -1,
      'activityLevel': 0,
      'noveltyLevel': 2,
      'personalityDistance': 0.8,
      'status': 'SELECTED',
    });

    expect(mission.status.label, '수행중');
    expect(MissionStatus.completed.label, '완료');
  });

  test('rejects out-of-range values and unknown enums', () {
    expect(
      () => MissionSettings.fromJson({
        'availableTime': 'SHORT',
        'dailyMissionLimit': 4,
      }),
      throwsFormatException,
    );
    expect(
      () => MissionSettings.fromJson({
        'availableTime': 'UNKNOWN',
        'dailyMissionLimit': 1,
      }),
      throwsFormatException,
    );
  });

  test('parses persisted personality change values from completion response', () {
    final change = MissionPersonalityChange.fromJson({
      'previousIndoorOutdoor': -1,
      'currentIndoorOutdoor': 0,
      'previousSocialLevel': 0,
      'currentSocialLevel': 1,
      'previousActivityLevel': 0,
      'currentActivityLevel': 1,
      'previousNoveltyLevel': 1,
      'currentNoveltyLevel': 2,
      'previousPersonalityCode': 'QUIET_FOCUSER',
      'currentPersonalityCode': 'ACTIVE_CONNECTOR',
    });

    expect(change.currentIndoorOutdoor - change.previousIndoorOutdoor, 1);
    expect(change.currentPersonalityCode, 'ACTIVE_CONNECTOR');
  });
}
