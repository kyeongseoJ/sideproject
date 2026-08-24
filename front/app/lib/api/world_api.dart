import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novelty_app/api/api_base_url.dart';
import 'package:novelty_app/world/world_models.dart';

abstract interface class WorldGateway {
  Future<WorldSnapshot> getSnapshot(String userKey);
}

class WorldApiException implements Exception {
  const WorldApiException(this.message);
  final String message;
}

class WorldApi implements WorldGateway {
  WorldApi({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? resolveApiBaseUrl()).trim();

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  @override
  Future<WorldSnapshot> getSnapshot(String userKey) async {
    if (_baseUrl.isEmpty) throw const WorldApiException('API 주소가 설정되지 않았습니다.');
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/world'),
            headers: {'Accept': 'application/json', 'X-User-Key': userKey},
          )
          .timeout(timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200) {
        final message =
            decoded is Map<String, Object?> && decoded['message'] is String
            ? decoded['message'] as String
            : 'World 정보를 불러오지 못했습니다.';
        throw WorldApiException(message);
      }
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return WorldSnapshot.fromJson(decoded);
    } on WorldApiException {
      rethrow;
    } on TimeoutException {
      throw const WorldApiException('World 요청 시간이 초과되었습니다.');
    } on FormatException {
      throw const WorldApiException('World 응답 형식이 올바르지 않습니다.');
    } catch (_) {
      throw const WorldApiException('World 서버에 연결할 수 없습니다.');
    }
  }

  void close() => _client.close();
}
