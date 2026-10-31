import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final config = ApiConfig(Uri.parse('http://127.0.0.1:8765/'));

  test('endpoint and websocket urls', () {
    expect(config.endpoint('/state').toString(), 'http://127.0.0.1:8765/api/v1/state');
    expect(config.websocket.toString(), 'ws://127.0.0.1:8765/api/v1/ws');
    expect(ApiConfig(Uri.parse('https://demo.example.com')).websocket.scheme, 'wss');
  });

  test('decodes Korean JSON and sends the client id', () async {
    late http.Request seen;
    final api = FingerBellApi(
      config,
      clientId: 'device-1',
      client: MockClient((req) async {
        seen = req;
        return http.Response.bytes(utf8.encode('{"status":"동결"}'), 200);
      }),
    );
    final body = await api.post('/security/sos-freeze', {'user_id': 'senior'});
    expect(body['status'], '동결');
    expect(seen.headers['X-FingerBell-Client'], 'device-1');
    expect(jsonDecode(seen.body), {'user_id': 'senior'});
  });

  test('maps the error envelope to ApiException', () async {
    final api = FingerBellApi(
      config,
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"error":{"code":"frozen","message":"계좌가 동결되어 있어 보낼 수 없어요."}}'),
          400,
        ),
      ),
    );
    await expectLater(
      api.post('/transaction/transfer'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'frozen').having((e) => e.statusCode, 'status', 400)),
    );
  });

  test('network failure becomes a friendly message', () async {
    final api = FingerBellApi(config, client: MockClient((_) async => throw http.ClientException('refused')));
    await expectLater(api.get('/state'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network')));
  });
}
