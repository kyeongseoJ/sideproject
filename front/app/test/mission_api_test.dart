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

  test('preserves a documented API error code without exposing request data', () async {
    final api = MissionApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'code': 'DAILY_LIMIT_REACHED',
              'message': 'Daily mission is already selected.',
            })),
            409,
          )),
    );

    await expectLater(
      api.select('secret-user-key', 13),
      throwsA(
        isA<MissionApiException>()
            .having((error) => error.code, 'code', 'DAILY_LIMIT_REACHED')
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.toString(), 'safe string',
                isNot(contains('secret-user-key'))),
      ),
    );
  });

  test('turns malformed success response into a contract failure', () async {
    final api = MissionApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      api.getToday('key'),
      throwsA(isA<MissionApiException>().having(
        (error) => error.kind,
        'kind',
        MissionApiFailureKind.contract,
      )),
    );
  });

  test('rejects an unset API base URL before sending a request', () async {
    final api = MissionApi(
      baseUrl: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      api.getToday('key'),
      throwsA(isA<MissionApiException>().having(
        (error) => error.kind,
        'kind',
        MissionApiFailureKind.configuration,
      )),
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
