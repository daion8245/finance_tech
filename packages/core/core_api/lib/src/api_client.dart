import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:core_errors/core_errors.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// 서버가 돌려준 오류나 연결 실패. [failure.code]는 서버의 error.code
/// (예: `frozen`, `balance`) 또는 `network`입니다.
class ApiException implements Exception {
  final Failure failure;
  final int? statusCode;

  const ApiException(this.failure, [this.statusCode]);

  String get message => failure.message;
  String? get code => failure.code;

  @override
  String toString() => 'ApiException($statusCode, ${failure.code}: ${failure.message})';
}

const networkFailure = Failure('서버에 연결할 수 없어요. 백엔드가 켜져 있는지 확인해 주세요.', 'network');

/// JSON REST 클라이언트. 모든 요청에 기기 식별자를 붙여, 서버가 보낸 실시간
/// 이벤트 중 이 기기에서 시작한 것을 구분할 수 있게 합니다.
class FingerBellApi {
  final ApiConfig config;
  final String clientId;
  final http.Client _client;
  final Duration timeout;

  FingerBellApi(
    this.config, {
    http.Client? client,
    String? clientId,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       clientId = clientId ?? _randomId();

  static String _randomId() {
    final r = Random();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'X-FingerBell-Client': clientId,
  };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(config.endpoint(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send(
    () => _client.post(
      config.endpoint(path),
      headers: _headers,
      body: jsonEncode(body ?? const <String, dynamic>{}),
    ),
  );

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(networkFailure);
    } on http.ClientException {
      throw const ApiException(networkFailure);
    }

    Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode >= 400) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      if (error is Map<String, dynamic>) {
        throw ApiException(
          Failure('${error['message'] ?? '요청을 처리하지 못했어요.'}', error['code'] as String?),
          response.statusCode,
        );
      }
      throw ApiException(Failure('요청을 처리하지 못했어요. (${response.statusCode})', 'http'), response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(const Failure('서버 응답 형식이 올바르지 않아요.', 'format'), response.statusCode);
    }
    return decoded;
  }

  void close() => _client.close();
}
