import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('won groups thousands', () {
    expect(won(0), '0원');
    expect(won(2350000), '2,350,000원');
    expect(won(-12400), '-12,400원');
  });

  test('formatWhen uses relative Korean labels', () {
    final now = DateTime(2026, 10, 26, 14, 0);
    expect(formatWhen(now.subtract(const Duration(seconds: 20)), now), '방금 전');
    expect(formatWhen(DateTime(2026, 10, 26, 9, 5), now), '오늘 09:05');
    expect(formatWhen(DateTime(2026, 10, 25, 22, 30), now), '어제 22:30');
    expect(formatWhen(DateTime(2026, 10, 3, 8), now), '10월 3일');
  });

  test('countdowns never go negative', () {
    expect(formatCountdown(const Duration(hours: 23, minutes: 59, seconds: 58)), '23:59:58');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00:00');
    expect(formatMinSec(const Duration(seconds: 161)), '2:41');
  });

  test('ThousandsFormatter keeps only digits', () {
    const f = ThousandsFormatter();
    final v = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '50a0000'));
    expect(v.text, '500,000');
  });

  testWidgets('FbSplit stacks the mobile order on narrow layouts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: const FbLayout(
          isWeb: false,
          child: FbSplit(main: [Text('A')], side: [Text('B')], mobile: [Text('B'), Text('A')]),
        ),
      ),
    );
    final b = tester.getTopLeft(find.text('B'));
    final a = tester.getTopLeft(find.text('A'));
    expect(b.dy, lessThan(a.dy));
  });

  testWidgets('FbSplit puts columns side by side on the web', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: const FbLayout(isWeb: true, child: FbSplit(main: [Text('A')], side: [Text('B')])),
      ),
    );
    expect(tester.getTopLeft(find.text('B')).dx, greaterThan(tester.getTopLeft(find.text('A')).dx));
  });
}
