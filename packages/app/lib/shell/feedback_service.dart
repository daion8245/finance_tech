import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 진동과 음성 안내(TTS). 테스트에서는 아무것도 하지 않는 구현을 씁니다.
abstract interface class FeedbackOutput {
  Future<void> vibrate(List<int> pattern);
  Future<void> speak(String text);
}

class SilentFeedback implements FeedbackOutput {
  const SilentFeedback();

  @override
  Future<void> vibrate(List<int> pattern) async {}

  @override
  Future<void> speak(String text) async {}
}

/// 실제 기기 출력. 진동 패턴은 [켜짐, 쉼, 켜짐, ...] (ms)이고, 켜짐 구간마다 햅틱을 한 번 줍니다.
class DeviceFeedback implements FeedbackOutput {
  FlutterTts? _tts;
  bool _ttsReady = false;

  @override
  Future<void> vibrate(List<int> pattern) async {
    for (var i = 0; i < pattern.length; i += 2) {
      final on = pattern[i];
      try {
        if (on >= 200) {
          await HapticFeedback.heavyImpact();
        } else if (on >= 60) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
      } catch (_) {
        return; // 진동을 지원하지 않는 기기
      }
      final rest = on + (i + 1 < pattern.length ? pattern[i + 1] : 0);
      if (i + 2 < pattern.length) await Future<void>.delayed(Duration(milliseconds: rest));
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      final tts = _tts ??= FlutterTts();
      if (!_ttsReady) {
        await tts.setLanguage('ko-KR');
        await tts.setSpeechRate(kIsWeb ? 0.95 : 0.5);
        _ttsReady = true;
      }
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('[FingerBell] 음성 안내 실패: $e');
    }
  }
}
