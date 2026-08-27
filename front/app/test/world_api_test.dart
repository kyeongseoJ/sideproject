import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novelty_app/api/world_api.dart';

void main() {
  test('GET /api/world sends the user key', () async {
    final api = WorldApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        expect(request.url.path, '/api/world');
        expect(request.headers['X-User-Key'], 'user-key');
        return http.Response(
          '{"objects":[{"objectCode":"BOOKSHELF","categoryCode":"LEARNING","displayName":"책장","level":1,"exp":0,"nextLevelRequiredExp":50,"maxLevel":5}]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    expect(
      (await api.getSnapshot('user-key')).objects.single.objectCode,
      'BOOKSHELF',
    );
  });

  test('invalid contract is reported as a safe API error', () async {
    final api = WorldApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('{"objects":null}', 200)),
    );
    await expectLater(
      api.getSnapshot('user-key'),
      throwsA(isA<WorldApiException>()),
    );
  });

  test('normalizes a trailing API base URL slash', () async {
    final api = WorldApi(
      baseUrl: 'https://api.example.com/',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.com/api/world');
        return http.Response('{"objects":[]}', 200);
      }),
    );

    expect((await api.getSnapshot('user-key')).objects, isEmpty);
  });
}
