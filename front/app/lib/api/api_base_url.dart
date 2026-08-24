import 'package:flutter/foundation.dart';

const String _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String resolveApiBaseUrl() {
  final configured = _configuredApiBaseUrl.trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  if (kIsWeb) {
    return 'http://localhost:8080';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}
