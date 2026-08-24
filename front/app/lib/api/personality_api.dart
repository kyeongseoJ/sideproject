import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novelty_app/api/api_base_url.dart';
import 'package:novelty_app/personality/personality_models.dart';

abstract interface class PersonalityGateway {
  Future<AnonymousUser> createAnonymousUser();

  Future<UserProfile> getCurrentUser(String userKey);

  Future<String> updateNickname(String userKey, String nickname);

  Future<PersonalityAnalysisResult> submitAnalysis(
    String userKey,
    PersonalityAnalysisRequest request,
  );
}

enum PersonalityApiErrorCode {
  invalidPersonalityAnswers('INVALID_PERSONALITY_ANSWERS'),
  invalidSubmissionKey('INVALID_SUBMISSION_KEY'),
  invalidUserKey('INVALID_USER_KEY'),
  personalityAlreadyAnalyzed('PERSONALITY_ALREADY_ANALYZED'),
  personalityNotAnalyzed('PERSONALITY_NOT_ANALYZED'),
  submissionKeyConflict('SUBMISSION_KEY_CONFLICT'),
  personalitySaveFailed('PERSONALITY_SAVE_FAILED'),
  invalidNickname('INVALID_NICKNAME'),
  bannedNickname('BANNED_NICKNAME'),
  duplicateNickname('DUPLICATE_NICKNAME'),
  profileSaveFailed('PROFILE_SAVE_FAILED'),
  unknown('UNKNOWN');

  const PersonalityApiErrorCode(this.code);
  final String code;

  static PersonalityApiErrorCode fromCode(Object? code) {
    return values.firstWhere(
      (value) => value.code == code,
      orElse: () => unknown,
    );
  }
}

enum PersonalityApiFailureKind {
  api,
  timeout,
  network,
  contract,
  configuration,
}

class PersonalityApiException implements Exception {
  const PersonalityApiException({
    required this.kind,
    required this.message,
    this.code = PersonalityApiErrorCode.unknown,
    this.statusCode,
  });

  final PersonalityApiFailureKind kind;
  final PersonalityApiErrorCode code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'PersonalityApiException(${code.code})';
}

class PersonalityApi implements PersonalityGateway {
  PersonalityApi({
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
  Future<AnonymousUser> createAnonymousUser() async {
    final response = await _send(
      () => _client.post(_uri('/api/users/anonymous')),
    );
    if (response.statusCode != 201) {
      throw _apiError(response);
    }
    return _parse(() => AnonymousUser.fromJson(_readJsonObject(response)));
  }

  @override
  Future<UserProfile> getCurrentUser(String userKey) async {
    final response = await _send(
      () => _client.get(
        _uri('/api/users/me'),
        headers: <String, String>{'X-User-Key': userKey},
      ),
    );
    if (response.statusCode != 200) {
      throw _apiError(response);
    }
    return _parse(() => UserProfile.fromJson(_readJsonObject(response)));
  }

  @override
  Future<String> updateNickname(String userKey, String nickname) async {
    final response = await _send(
      () => _client.patch(
        _uri('/api/users/me/nickname'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-User-Key': userKey,
        },
        body: jsonEncode(<String, Object>{'nickname': nickname}),
      ),
    );
    if (response.statusCode != 200) {
      throw _apiError(response);
    }
    return _parse(() {
      final value = _readJsonObject(response)['nickname'];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid nickname response.');
      }
      return value;
    });
  }

  @override
  Future<PersonalityAnalysisResult> submitAnalysis(
    String userKey,
    PersonalityAnalysisRequest request,
  ) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/personality-analyses'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-User-Key': userKey,
        },
        body: jsonEncode(request.toJson()),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _apiError(response);
    }
    return _parse(
      () => PersonalityAnalysisResult.fromJson(_readJsonObject(response)),
    );
  }

  void close() {
    _client.close();
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const PersonalityApiException(
        kind: PersonalityApiFailureKind.timeout,
        message: '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.',
      );
    } on http.ClientException {
      throw const PersonalityApiException(
        kind: PersonalityApiFailureKind.network,
        message: '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException {
      throw const PersonalityApiException(
        kind: PersonalityApiFailureKind.contract,
        message: '서버 응답을 확인할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw const PersonalityApiException(
        kind: PersonalityApiFailureKind.configuration,
        message: 'API 주소가 설정되지 않았습니다. API_BASE_URL을 지정해 주세요.',
      );
    }
    final normalized = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.tryParse('$normalized$path');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const PersonalityApiException(
        kind: PersonalityApiFailureKind.configuration,
        message: 'API_BASE_URL 형식이 올바르지 않습니다.',
      );
    }
    return uri;
  }

  Map<String, Object?> _readJsonObject(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected JSON object.');
    }
    return decoded;
  }

  PersonalityApiException _apiError(http.Response response) {
    PersonalityApiErrorCode code = PersonalityApiErrorCode.unknown;
    String? message;
    try {
      final json = _readJsonObject(response);
      code = PersonalityApiErrorCode.fromCode(json['code']);
      final rawMessage = json['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        message = rawMessage;
      }
    } on FormatException {
      // 계약 형식이 아닌 오류 응답에는 상태별 안전한 기본 문구를 사용한다.
    }

    return PersonalityApiException(
      kind: PersonalityApiFailureKind.api,
      code: code,
      statusCode: response.statusCode,
      message: message ?? _fallbackMessage(response.statusCode),
    );
  }

  String _fallbackMessage(int statusCode) {
    if (statusCode == 401) {
      return '저장된 사용자 정보를 확인할 수 없습니다.';
    }
    if (statusCode == 409) {
      return '현재 성향 분석 상태를 확인해 주세요.';
    }
    if (statusCode >= 500) {
      return '성향 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    return '입력한 내용을 확인해 주세요.';
  }
}
