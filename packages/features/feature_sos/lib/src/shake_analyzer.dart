import 'dart:math' as math;

const standardGravity = 9.80665;

class ShakeUpdate {
  /// 0~1. 1이 되면 SOS가 발동합니다.
  final double progress;
  final bool fired;

  /// 이번 흔들기에서 잰 가장 큰 가속도 (g).
  final double peakG;

  const ShakeUpdate(this.progress, {this.fired = false, this.peakG = 0});
}

/// 가속도 센서 값으로 "격렬한 흔들기"를 판정합니다 (기획서 3.1).
///
/// 3축 가속도 합이 [thresholdG] (기본 2.5g)를 넘는 순간이 [maxGap] 이내 간격으로
/// [sustain] (기본 3초) 동안 이어지면 발동합니다. 발동 뒤 [cooldown] 동안은 무시합니다.
/// 센서와 분리된 순수 로직이라 테스트에서 값을 직접 넣어 확인할 수 있습니다.
class ShakeAnalyzer {
  final double thresholdG;
  final Duration sustain;
  final Duration maxGap;
  final Duration cooldown;

  DateTime? _start;
  DateTime? _lastPeak;
  DateTime? _lastFire;
  double _peakG = 0;

  ShakeAnalyzer({
    this.thresholdG = 2.5,
    this.sustain = const Duration(seconds: 3),
    this.maxGap = const Duration(milliseconds: 700),
    this.cooldown = const Duration(seconds: 5),
  });

  bool get isShaking => _start != null;

  static double magnitudeG(double x, double y, double z) => math.sqrt(x * x + y * y + z * z) / standardGravity;

  /// 센서 값 하나를 넣습니다. 진행 상황이 바뀌면 [ShakeUpdate]를, 아니면 null을 돌려줍니다.
  ShakeUpdate? add(double x, double y, double z, DateTime t) {
    if (_lastFire != null && t.difference(_lastFire!) < cooldown) return null;
    final g = magnitudeG(x, y, z);

    if (g >= thresholdG) {
      if (_lastPeak == null || t.difference(_lastPeak!) > maxGap) {
        _start = t;
        _peakG = 0;
      }
      _lastPeak = t;
      _peakG = math.max(_peakG, g);
      final progress = t.difference(_start!).inMilliseconds / sustain.inMilliseconds;
      if (progress >= 1) {
        final peak = _peakG;
        _lastFire = t;
        reset();
        return ShakeUpdate(1, fired: true, peakG: peak);
      }
      return ShakeUpdate(progress.clamp(0, 1), peakG: _peakG);
    }

    if (_lastPeak != null && t.difference(_lastPeak!) > maxGap) {
      reset();
      return const ShakeUpdate(0);
    }
    return null;
  }

  void reset() {
    _start = null;
    _lastPeak = null;
    _peakG = 0;
  }
}
