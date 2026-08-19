import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novelty_app/survey/survey_models.dart';

abstract interface class SurveySubmitter {
  Future<SurveySaveResult> submit(SurveyAnswers answers);
}

class SurveyApi implements SurveySubmitter {
  SurveyApi({
    http.Client? client,
    String baseUrl = const String.fromEnvironment('API_BASE_URL'),
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.trim(),
       _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<SurveySaveResult> submit(SurveyAnswers answers) async {
    final uri = _surveyUri();

    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(answers.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode != 201) {
        throw SurveyApiException(_readErrorMessage(response));
      }

      return SurveySaveResult.fromJson(_readJsonObject(response));
    } on TimeoutException {
      throw const SurveyApiException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    } on http.ClientException {
      throw const SurveyApiException('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } on FormatException {
      throw const SurveyApiException('서버 응답을 확인할 수 없습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  void close() {
    _client.close();
  }

  Uri _surveyUri() {
    if (_baseUrl.isEmpty) {
      throw const SurveyApiException(
        'API 주소가 설정되지 않았습니다. API_BASE_URL을 지정해 주세요.',
      );
    }

    final normalizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.tryParse('$normalizedBaseUrl/api/surveys');

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const SurveyApiException('API_BASE_URL 형식이 올바르지 않습니다.');
    }

    return uri;
  }

  Map<String, Object?> _readJsonObject(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  String _readErrorMessage(http.Response response) {
    try {
      final json = _readJsonObject(response);
      final message = json['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    } on FormatException {
      // 계약 형식이 아닌 오류 응답에는 안전한 기본 문구를 사용한다.
    }

    if (response.statusCode >= 500) {
      return '선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    return '선택 내용을 확인해 주세요.';
  }
}

class SurveyApiException implements Exception {
  const SurveyApiException(this.message);

  final String message;
}
