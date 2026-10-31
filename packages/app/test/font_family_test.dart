import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면에 그려진 글자 중 앱에 넣은 한글 글꼴을 쓰지 않는 것을 모읍니다.
/// 글꼴 이름이 빠지면 웹은 한글을 네모로 그립니다 (인터넷 글꼴을 쓰지 않으므로).
List<String> textsWithoutBundledFont(WidgetTester tester) {
  final missing = <String>[];
  for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    void visit(InlineSpan span, String? inherited) {
      final family = span.style?.fontFamily ?? inherited;
      if (span is TextSpan) {
        final text = span.text ?? '';
        if (text.trim().isNotEmpty && family != FbTheme.fontFamily) missing.add('$text ($family)');
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, family);
        }
      }
    }

    final root = p.text;
    final rootFamily = root.style?.fontFamily;
    // 아이콘은 MaterialIcons 글꼴을 씁니다.
    if (rootFamily == 'MaterialIcons') continue;
    visit(root, rootFamily);
  }
  return missing;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (label, size) in const [('mobile', Size(400, 860)), ('web', Size(1440, 900))]) {
    testWidgets('every screen uses the bundled Korean font ($label)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final family = FamilyCubit(
        FakeFamilyRepository(demoSnapshotJson(requests: [pendingTransferJson()])),
        pollInterval: null,
      );
      await family.start();
      final shell = ShellCubit();
      await tester.pumpWidget(
        FingerBellApp(family: family, shell: shell, feedback: const SilentFeedback(), serverAddress: 'http://127.0.0.1:8765'),
      );
      await settle(tester);

      final problems = <String>[];
      for (final persona in Persona.values) {
        for (final tab in AppTab.values) {
          shell.goto(persona, tab);
          await settle(tester);
          problems.addAll(textsWithoutBundledFont(tester).map((t) => '${persona.name}/${tab.name}: $t'));
        }
      }
      expect(problems, isEmpty);
    });
  }
}
