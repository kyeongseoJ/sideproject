import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/personality/personality_models.dart';

void main() {
  test('registers and logs in with account credentials', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(jsonDecode(request.body), {
        'loginId': 'tester1',
        'password': 'Password1',
      });
      return _jsonResponse({
        'userId': 7,
        'userKey': 'user-key-value',
        'nickname': '노벨티07QK',
        'personalityCompleted': request.url.path.endsWith('/login'),
      }, request.url.path.endsWith('/register') ? 201 : 200);
    });
    final api = PersonalityApi(
      client: client,
      baseUrl: 'http://localhost:8080',
    );

    final registered = await api.register('tester1', 'Password1');
    final loggedIn = await api.login('tester1', 'Password1');

    expect(registered.personalityCompleted, isFalse);
    expect(loggedIn.personalityCompleted, isTrue);
    expect(paths, ['/api/users/register', '/api/users/login']);
    api.close();
  });

  test(
    'restores the current user with X-User-Key and never calls V1',
    () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'GET');
        expect(request.headers['X-User-Key'], 'cached-user-key');
        return _jsonResponse({
          'userId': 7,
          'nickname': '노벨티07QK',
          'personalityCompleted': false,
          'personality': null,
        }, 200);
      });
      final api = PersonalityApi(
        client: client,
        baseUrl: 'http://localhost:8080',
      );

      final user = await api.getCurrentUser('cached-user-key');

      expect(user.personalityCompleted, isFalse);
      expect(requestedPaths, ['/api/users/me']);
      expect(requestedPaths, isNot(contains('/api/surveys')));
      api.close();
    },
  );

  test('updates nickname with the official user endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/users/me/nickname');
      expect(request.headers['X-User-Key'], 'cached-user-key');
      expect(jsonDecode(request.body), {'nickname': '새닉네임7'});
      return _jsonResponse({'nickname': '새닉네임7'}, 200);
    });
    final api = PersonalityApi(
      client: client,
      baseUrl: 'http://localhost:8080',
    );

    expect(await api.updateNickname('cached-user-key', '새닉네임7'), '새닉네임7');
    api.close();
  });

  test('posts the V2 analysis contract with the cached user key', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/personality-analyses');
      expect(request.headers['X-User-Key'], 'cached-user-key');
      expect(request.headers['content-type'], 'application/json');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['analysisMode'], 'INITIAL');
      expect(body['physicalActivityLevel'], 'MEDIUM');
      expect(body.containsKey('energyLevel'), isFalse);
      expect(body.containsKey('activityLevel'), isFalse);
      return _jsonResponse({
        'analysisId': 42,
        'status': 'ANALYZED',
        'personality': _personalityJson(),
      }, 201);
    });
    final api = PersonalityApi(
      client: client,
      baseUrl: 'http://localhost:8080',
    );

    final result = await api.submitAnalysis('cached-user-key', _request());

    expect(result.analysisId, 42);
    expect(result.personality.typeCode, 'QUIET_FOCUSER');
    api.close();
  });

  test('accepts 200 for an idempotent analysis retry', () async {
    final api = PersonalityApi(
      client: MockClient(
        (_) async => _jsonResponse({
          'analysisId': 42,
          'status': 'ANALYZED',
          'personality': _personalityJson(),
        }, 200),
      ),
      baseUrl: 'http://localhost:8080',
    );

    expect(
      (await api.submitAnalysis('cached-user-key', _request())).analysisId,
      42,
    );
    api.close();
  });

  final definedErrors = <(int, String, PersonalityApiErrorCode)>[
    (
      400,
      'INVALID_PERSONALITY_ANSWERS',
      PersonalityApiErrorCode.invalidPersonalityAnswers,
    ),
    (
      400,
      'INVALID_SUBMISSION_KEY',
      PersonalityApiErrorCode.invalidSubmissionKey,
    ),
    (401, 'INVALID_USER_KEY', PersonalityApiErrorCode.invalidUserKey),
    (
      409,
      'PERSONALITY_ALREADY_ANALYZED',
      PersonalityApiErrorCode.personalityAlreadyAnalyzed,
    ),
    (
      409,
      'PERSONALITY_NOT_ANALYZED',
      PersonalityApiErrorCode.personalityNotAnalyzed,
    ),
    (
      409,
      'SUBMISSION_KEY_CONFLICT',
      PersonalityApiErrorCode.submissionKeyConflict,
    ),
    (
      500,
      'PERSONALITY_SAVE_FAILED',
      PersonalityApiErrorCode.personalitySaveFailed,
    ),
  ];
  for (final (status, code, expectedCode) in definedErrors) {
    test('maps backend error $code', () async {
      final api = PersonalityApi(
        client: MockClient(
          (_) async =>
              _jsonResponse({'code': code, 'message': '안전한 오류 메시지'}, status),
        ),
        baseUrl: 'http://localhost:8080',
      );

      await expectLater(
        api.submitAnalysis('cached-user-key', _request()),
        throwsA(
          isA<PersonalityApiException>()
              .having((error) => error.code, 'code', expectedCode)
              .having((error) => error.statusCode, 'statusCode', status)
              .having((error) => error.message, 'message', '안전한 오류 메시지'),
        ),
      );
      api.close();
    });
  }

  test('uses a safe fallback for malformed server errors', () async {
    final api = PersonalityApi(
      client: MockClient(
        (_) async => http.Response('<html>failure</html>', 500),
      ),
      baseUrl: 'http://localhost:8080',
    );

    await expectLater(
      api.getCurrentUser('cached-user-key'),
      throwsA(
        isA<PersonalityApiException>()
            .having(
              (error) => error.code,
              'code',
              PersonalityApiErrorCode.unknown,
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('<html>')),
            ),
      ),
    );
    api.close();
  });

  test('maps timeout and network failures separately', () async {
    final timeoutApi = PersonalityApi(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('', 200);
      }),
      baseUrl: 'http://localhost:8080',
      timeout: const Duration(milliseconds: 1),
    );
    final networkApi = PersonalityApi(
      client: MockClient((_) async => throw http.ClientException('offline')),
      baseUrl: 'http://localhost:8080',
    );

    await expectLater(
      timeoutApi.getCurrentUser('cached-user-key'),
      throwsA(
        isA<PersonalityApiException>().having(
          (error) => error.kind,
          'kind',
          PersonalityApiFailureKind.timeout,
        ),
      ),
    );
    await expectLater(
      networkApi.getCurrentUser('cached-user-key'),
      throwsA(
        isA<PersonalityApiException>().having(
          (error) => error.kind,
          'kind',
          PersonalityApiFailureKind.network,
        ),
      ),
    );
    timeoutApi.close();
    networkApi.close();
  });

  test('rejects malformed success responses and missing API URL', () async {
    final malformedApi = PersonalityApi(
      client: MockClient((_) async => _jsonResponse({'analysisId': 0}, 201)),
      baseUrl: 'http://localhost:8080',
    );
    final missingUrlApi = PersonalityApi(
      client: MockClient((_) async => http.Response('', 200)),
      baseUrl: '',
    );

    await expectLater(
      malformedApi.submitAnalysis('cached-user-key', _request()),
      throwsA(
        isA<PersonalityApiException>().having(
          (error) => error.kind,
          'kind',
          PersonalityApiFailureKind.contract,
        ),
      ),
    );
    await expectLater(
      missingUrlApi.getCurrentUser('cached-user-key'),
      throwsA(
        isA<PersonalityApiException>().having(
          (error) => error.kind,
          'kind',
          PersonalityApiFailureKind.configuration,
        ),
      ),
    );
    malformedApi.close();
    missingUrlApi.close();
  });
}

PersonalityAnalysisRequest _request() => PersonalityAnalysisRequest(
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

http.Response _jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _personalityJson() => <String, Object?>{
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
