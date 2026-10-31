import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'shake_analyzer.dart';

/// sensors_plus 가속도 스트림을 [ShakeAnalyzer]에 연결합니다.
/// 센서가 없는 기기(데스크톱 브라우저 등)에서는 [supported]가 false가 됩니다.
class ShakeDetector {
  final ShakeAnalyzer analyzer;
  final void Function(double peakG) onShake;
  final void Function(double progress)? onProgress;
  /// 테스트에서 가짜 센서 값을 넣을 때 씁니다.
  final Stream<AccelerometerEvent> Function()? source;

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _supported = true;

  ShakeDetector({
    required this.onShake,
    this.onProgress,
    ShakeAnalyzer? analyzer,
    this.source,
  }) : analyzer = analyzer ?? ShakeAnalyzer();

  bool get active => _sub != null;
  bool get supported => _supported;

  void start() {
    if (_sub != null || !_supported) return;
    final Stream<AccelerometerEvent> stream;
    try {
      stream = source?.call() ??
          (kIsWeb ? accelerometerEventStream() : accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval));
    } catch (_) {
      _supported = false;
      return;
    }
    _sub = stream.listen(
      (e) {
        final update = analyzer.add(e.x, e.y, e.z, DateTime.now());
        if (update == null) return;
        onProgress?.call(update.progress);
        if (update.fired) onShake(update.peakG);
      },
      onError: (_) {
        // 센서를 쓸 수 없는 기기
        _supported = false;
        stop();
      },
      cancelOnError: true,
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    analyzer.reset();
    onProgress?.call(0);
  }
}
