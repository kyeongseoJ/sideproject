import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/mission/mission_models.dart';

void main() {
  test('parses a valid mission and maps UI status labels', () {
    final mission = UserMission.fromJson({
      'userMissionId': 1,
      'missionId': 2,
      'title': '낯선 음악 듣기',
      'description': '처음 듣는 장르를 골라 보세요.',
      'category': 'CULTURE',
      'difficulty': 1,
      'estimatedMinutes': 15,
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
}
