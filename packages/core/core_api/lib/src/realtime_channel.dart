import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef SocketConnector = WebSocketChannel Function(Uri uri);

/// 서버 실시간 이벤트(WebSocket). 끊기면 1초부터 최대 10초 간격으로 다시 연결합니다.
class RealtimeChannel {
  final Uri uri;
  final SocketConnector _connect;
  final Duration pingInterval;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _isConnected = false;
  bool _disposed = false;

  RealtimeChannel(this.uri, {SocketConnector? connector, this.pingInterval = const Duration(seconds: 25)})
    : _connect = connector ?? WebSocketChannel.connect;

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<bool> get connection => _connected.stream;
  bool get isConnected => _isConnected;

  void connect() {
    if (_disposed || _channel != null) return;
    _retry?.cancel();
    final WebSocketChannel channel;
    try {
      channel = _connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    channel.ready.then((_) {
      if (_channel != channel) return;
      _attempt = 0;
      _setConnected(true);
      _ping?.cancel();
      _ping = Timer.periodic(pingInterval, (_) => _safeSend('ping'));
    }, onError: (_) => _drop(channel));

    _sub = channel.stream.listen(
      (data) {
        if (data is! String) return;
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) _events.add(decoded);
        } on FormatException {
          // 알 수 없는 메시지는 무시합니다
        }
      },
      onError: (_) => _drop(channel),
      onDone: () => _drop(channel),
      cancelOnError: true,
    );
  }

  void _safeSend(String text) {
    try {
      _channel?.sink.add(text);
    } catch (_) {}
  }

  void _drop(WebSocketChannel channel) {
    if (_channel != channel) return;
    _sub?.cancel();
    _sub = null;
    _ping?.cancel();
    _channel = null;
    _setConnected(false);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _attempt = (_attempt + 1).clamp(1, 10);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _attempt), connect);
  }

  void _setConnected(bool value) {
    if (_isConnected == value) return;
    _isConnected = value;
    if (!_connected.isClosed) _connected.add(value);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _ping?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _events.close();
    await _connected.close();
  }
}
