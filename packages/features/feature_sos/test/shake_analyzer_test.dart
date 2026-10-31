import 'package:feature_sos/feature_sos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  final t0 = DateTime(2026, 10, 26, 14);
  // 3g 정도로 세게 흔든 값과 가만히 있을 때 값 (m/s²)
  const hard = (0.0, 29.4, 0.0);
  const still = (0.0, 9.8, 0.0);

  ShakeUpdate? feed(ShakeAnalyzer a, (double, double, double) v, int ms) => a.add(v.$1, v.$2, v.$3, t0.add(Duration(milliseconds: ms)));

  test('fires after three seconds of continuous hard shaking', () {
    final a = ShakeAnalyzer();
    ShakeUpdate? last;
    for (var ms = 0; ms <= 3000; ms += 250) {
      last = feed(a, hard, ms);
      if (ms < 3000) expect(last!.fired, isFalse);
    }
    expect(last!.fired, isTrue);
    expect(last.peakG, closeTo(3.0, .05));
  });

  test('a short shake does not fire and resets after a pause', () {
    final a = ShakeAnalyzer();
    for (var ms = 0; ms <= 1500; ms += 250) {
      expect(feed(a, hard, ms)!.fired, isFalse);
    }
    final reset = feed(a, still, 2400);
    expect(reset!.progress, 0);
    expect(a.isShaking, isFalse);
  });

  test('gentle movement never counts', () {
    final a = ShakeAnalyzer();
    for (var ms = 0; ms <= 5000; ms += 100) {
      expect(feed(a, (5.0, 12.0, 3.0), ms), isNull);
    }
  });

  test('cooldown ignores shaking right after firing', () {
    final a = ShakeAnalyzer();
    for (var ms = 0; ms <= 3000; ms += 250) {
      feed(a, hard, ms);
    }
    expect(feed(a, hard, 3250), isNull);
  });

  testWidgets('hold button completes only after the full hold', (tester) async {
    var done = 0;
    double? cancelled;
    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: SosHoldButton(onComplete: () => done++, onCancel: (p) => cancelled = p),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('그대로 누르고 계세요…'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(done, 0);
    expect(cancelled, greaterThan(0));

    final hold = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(done, 1);
    await hold.up();
  });
}
