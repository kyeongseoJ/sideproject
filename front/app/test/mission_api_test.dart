import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_models.dart';

void main() {
  test('sends the user key and parses the recommendation response', () async {
    late http.Request captured;
    final api = MissionApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode(_todayJson())),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await api.recommendToday('safe-user-key');

    expect(result.candidates.single.status, MissionStatus.shown);
    expect(captured.url.path, '/api/missions/today/recommendations');
    expect(captured.headers['X-User-Key'], 'safe-user-key');
  });

  test(
    'preserves a documented API error code without exposing request data',
    () async {
      final api = MissionApi(
        baseUrl: 'http://localhost:8080',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'DAILY_LIMIT_REACHED',
                'message': 'Daily mission is already selected.',
              }),
            ),
            409,
          ),
        ),
      );

      await expectLater(
        api.select('secret-user-key', 13),
        throwsA(
          isA<MissionApiException>()
              .having((error) => error.code, 'code', 'DAILY_LIMIT_REACHED')
              .having((error) => error.statusCode, 'status', 409)
              .having(
                (error) => error.toString(),
                'safe string',
                isNot(contains('secret-user-key')),
              ),
        ),
      );
    },
  );

  test(
    'completes a user mission and parses personality and World effects',
    () async {
      late http.Request captured;
      final api = MissionApi(
        baseUrl: 'https://api.example.com/',
        client: MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode(_completedActionJson())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await api.complete('safe-user-key', 13);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/user-missions/13/complete');
      expect(captured.headers['X-User-Key'], 'safe-user-key');
      expect(result.personalityUpdated, isTrue);
      expect(result.personalityChange?.currentNoveltyLevel, 2);
      expect(result.worldGrowth?.awardedExp, 20);
      expect(result.worldGrowth?.levelUp, isTrue);
    },
  );

  test('turns malformed success response into a contract failure', () async {
    final api = MissionApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      api.getToday('key'),
      throwsA(
        isA<MissionApiException>().having(
          (error) => error.kind,
          'kind',
          MissionApiFailureKind.contract,
        ),
      ),
    );
  });

  test('rejects an unset API base URL before sending a request', () async {
    final api = MissionApi(
      baseUrl: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      api.getToday('key'),
      throwsA(
        isA<MissionApiException>().having(
          (error) => error.kind,
          'kind',
          MissionApiFailureKind.configuration,
        ),
      ),
    );
  });
}

Map<String, Object?> _todayJson() => {
  'serviceDate': '2026-08-20',
  'completedToday': 0,
  'activeMissions': <Object?>[],
  'candidates': [_missionJson()],
};

Map<String, Object?> _missionJson() => {
  'userMissionId': 13,
  'missionId': 5,
  'title': 'Try a new walk',
  'description': 'Take a different route today.',
  'category': 'OUTDOOR',
  'difficulty': 1,
  'estimatedMinutes': 10,
  'indoorOutdoor': 1,
  'socialLevel': -1,
  'activityLevel': 1,
  'noveltyLevel': 1,
  'sourceType': 'BASE',
  'personalityDistance': 0.75,
  'recommendationScore': 0.71,
  'status': 'SHOWN',
  'statusAt': '2026-08-20T09:00:00+09:00',
};

Map<String, Object?> _completedActionJson() => {
  'mission': {..._missionJson(), 'status': 'COMPLETED'},
  'today': {
    'serviceDate': '2026-08-20',
    'completedToday': 1,
    'activeMissions': <Object?>[],
    'candidates': <Object?>[],
  },
  'idempotent': false,
  'completion': {
    'summary': {
      'completedMissionCount': 1,
      'lastPersonalityAdaptedCount': 1,
      'personalityCode': 'BALANCED_COORDINATOR',
      'categoryStats': [
        {'category': 'OUTDOOR', 'completedCount': 1},
      ],
    },
    'personalityUpdated': true,
    'personalityChange': {
      'previousIndoorOutdoor': 0,
      'currentIndoorOutdoor': 1,
      'previousSocialLevel': 0,
      'currentSocialLevel': 0,
      'previousActivityLevel': 1,
      'currentActivityLevel': 2,
      'previousNoveltyLevel': 1,
      'currentNoveltyLevel': 2,
      'previousPersonalityCode': 'BALANCED_COORDINATOR',
      'currentPersonalityCode': 'ACTIVE_CONNECTOR',
    },
    'milestone': 1,
    'llmGenerationStatus': 'NOT_REQUIRED',
    'worldGrowth': {
      'objectCode': 'INDOOR_GARDEN',
      'categoryCode': 'OUTDOOR',
      'awardedExp': 20,
      'previousLevel': 1,
      'currentLevel': 2,
      'currentExp': 60,
      'nextLevelRequiredExp': 120,
      'levelUp': true,
      'rewardApplied': true,
    },
  },
};
