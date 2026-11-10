import 'package:flutter/foundation.dart';

class AppEnvironment {
  const AppEnvironment({required this.apiBaseUrl});
  final String apiBaseUrl;

  factory AppEnvironment.local() {
    const configured = String.fromEnvironment('API_BASE_URL');
    final fallback = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://127.0.0.1:8080';
    final value = configured.isEmpty ? fallback : configured;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (kReleaseMode && uri.scheme != 'https')) {
      throw StateError(
        'API_BASE_URL must be an origin; release builds require HTTPS.',
      );
    }
    return AppEnvironment(apiBaseUrl: value.replaceFirst(RegExp(r'/$'), ''));
  }
}
