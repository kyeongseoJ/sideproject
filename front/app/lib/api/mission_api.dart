import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novelty_app/api/api_base_url.dart';
import 'package:novelty_app/mission/mission_models.dart';

abstract interface class MissionGateway {
  Future<MissionSettings> getSettings(String userKey);
  Future<MissionSettings> saveSettings(
    String userKey,
    MissionSettings settings,
  );
  Future<MissionToday> getToday(String userKey);
  Future<MissionToday> recommendToday(String userKey);
  Future<MissionSummary> getSummary(String userKey);
  Future<MissionActionResult> select(String userKey, int userMissionId);
  Future<MissionActionResult> cancel(String userKey, int userMissionId);
  Future<MissionActionResult> replace(
    String userKey,
    int currentId,
    int replacementId,
  );
  Future<MissionActionResult> complete(String userKey, int userMissionId);
}

enum MissionApiFailureKind { api, timeout, network, contract, configuration }

class MissionApiException implements Exception {
  const MissionApiException({
    required this.kind,
    required this.message,
    this.code = 'UNKNOWN',
    this.statusCode,
  });
  final MissionApiFailureKind kind;
  final String code;
  final String message;
  final int? statusCode;
  @override
  String toString() => 'MissionApiException($code)';
}

class MissionApi implements MissionGateway {
  MissionApi({
    http.Client? client,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? resolveApiBaseUrl()).trim(),
       _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<MissionSettings> getSettings(String key) => _object(
    () => _client.get(_uri('/api/missions/settings'), headers: _headers(key)),
    {200},
    MissionSettings.fromJson,
  );

  @override
  Future<MissionSettings> saveSettings(String key, MissionSettings settings) =>
      _object(
        () => _client.put(
          _uri('/api/missions/settings'),
          headers: _headers(key, json: true),
          body: jsonEncode(settings.toJson()),
        ),
        {200},
        MissionSettings.fromJson,
      );

  @override
  Future<MissionToday> getToday(String key) => _object(
    () => _client.get(_uri('/api/missions/today'), headers: _headers(key)),
    {200},
    MissionToday.fromJson,
  );

  @override
  Future<MissionToday> recommendToday(String key) => _object(
    () => _client.post(
      _uri('/api/missions/today/recommendations'),
      headers: _headers(key),
    ),
    {200, 201},
    MissionToday.fromJson,
  );

  @override
  Future<MissionSummary> getSummary(String key) => _object(
    () => _client.get(_uri('/api/missions/summary'), headers: _headers(key)),
    {200},
    MissionSummary.fromJson,
  );

  @override
  Future<MissionActionResult> select(String key, int id) =>
      _action(key, id, 'select');
  @override
  Future<MissionActionResult> cancel(String key, int id) =>
      _action(key, id, 'cancel');
  @override
  Future<MissionActionResult> complete(String key, int id) =>
      _action(key, id, 'complete');

  @override
  Future<MissionActionResult> replace(
    String key,
    int currentId,
    int replacementId,
  ) => _object(
    () => _client.post(
      _uri('/api/user-missions/$currentId/replace'),
      headers: _headers(key, json: true),
      body: jsonEncode({'replacementUserMissionId': replacementId}),
    ),
    {200},
    MissionActionResult.fromJson,
  );

  Future<MissionActionResult> _action(String key, int id, String action) =>
      _object(
        () => _client.post(
          _uri('/api/user-missions/$id/$action'),
          headers: _headers(key),
        ),
        {200},
        MissionActionResult.fromJson,
      );

  Future<T> _object<T>(
    Future<http.Response> Function() request,
    Set<int> success,
    T Function(Map<String, Object?>) parser,
  ) async {
    final response = await _send(request);
    if (!success.contains(response.statusCode)) throw _apiError(response);
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return parser(decoded);
    } on FormatException {
      throw const MissionApiException(
        kind: MissionApiFailureKind.contract,
        message: '서버 응답을 확인할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const MissionApiException(
        kind: MissionApiFailureKind.timeout,
        message: '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.',
      );
    } on http.ClientException {
      throw const MissionApiException(
        kind: MissionApiFailureKind.network,
        message: '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  MissionApiException _apiError(http.Response response) {
    String code = 'UNKNOWN';
    String? message;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) {
        if (decoded['code'] is String) code = decoded['code'] as String;
        if (decoded['message'] is String &&
            (decoded['message'] as String).trim().isNotEmpty)
          message = decoded['message'] as String;
      }
    } catch (_) {}
    return MissionApiException(
      kind: MissionApiFailureKind.api,
      code: code,
      statusCode: response.statusCode,
      message:
          message ??
          (response.statusCode >= 500
              ? '미션 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.'
              : '미션 요청을 확인해 주세요.'),
    );
  }

  Map<String, String> _headers(String key, {bool json = false}) => {
    'X-User-Key': key,
    if (json) 'Content-Type': 'application/json',
  };

  Uri _uri(String path) {
    final normalized = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.tryParse('$normalized$path');
    if (_baseUrl.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const MissionApiException(
        kind: MissionApiFailureKind.configuration,
        message: 'API 주소가 설정되지 않았습니다. API_BASE_URL을 지정해 주세요.',
      );
    }
    return uri;
  }

  void close() => _client.close();
}
