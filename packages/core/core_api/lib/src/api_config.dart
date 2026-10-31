import 'package:flutter/foundation.dart';

/// 백엔드 주소. `--dart-define=FINGERBELL_API_URL=http://192.168.0.10:8765`으로 바꿉니다.
///
/// 지정하지 않으면 웹은 앱을 연 주소(같은 서버가 웹 앱을 제공하는 경우),
/// 그 밖의 기기는 `http://127.0.0.1:8765`을 씁니다. Android는 `adb reverse
/// tcp:8765 tcp:8765`으로 PC의 서버에 연결합니다 (run-android.ps1이 해 줍니다).
class ApiConfig {
  final Uri baseUrl;

  ApiConfig(Uri baseUrl) : baseUrl = _trim(baseUrl);

  static const _defined = String.fromEnvironment('FINGERBELL_API_URL');

  factory ApiConfig.fromEnvironment() {
    if (_defined.isNotEmpty) return ApiConfig(Uri.parse(_defined));
    if (kIsWeb) return ApiConfig(Uri.parse(Uri.base.origin));
    return ApiConfig(Uri.parse('http://127.0.0.1:8765'));
  }

  static Uri _trim(Uri uri) {
    final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
    return uri.replace(path: path, query: null, fragment: null);
  }

  /// `/api/v1/...` 경로를 붙인 HTTP 주소.
  Uri endpoint(String path, [Map<String, String>? query]) {
    final full = Uri.parse('$baseUrl/api/v1$path');
    return query == null || query.isEmpty ? full : full.replace(queryParameters: query);
  }

  /// 실시간 이벤트 WebSocket 주소.
  Uri get websocket {
    final http = endpoint('/ws');
    return http.replace(scheme: http.scheme == 'https' ? 'wss' : 'ws');
  }

  @override
  String toString() => baseUrl.toString();
}
