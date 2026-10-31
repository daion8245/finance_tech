import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _width(TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: '안녕하세요 핑거벨 ABC 123', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return p.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme uses the bundled Noto Sans KR', () {
    final theme = FbTheme.build();
    expect(theme.textTheme.bodyMedium!.fontFamily, FbTheme.fontFamily);
    expect(FbTheme.build(highContrast: true).textTheme.titleLarge!.fontFamily, FbTheme.fontFamily);
  });

  // 이 가변 글꼴의 기본 굵기는 100(Thin)입니다. FontWeight가 wght 축에 적용되지 않으면
  // 화면 전체가 가늘게 보이므로, 굵기마다 글자 폭이 달라지는지 확인합니다.
  test('FontWeight drives the variable wght axis', () async {
    final bytes = File('assets/fonts/NotoSansKR-VF.ttf').readAsBytesSync();
    await (FontLoader('TestNotoKR')..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)))).load();
    const base = TextStyle(fontFamily: 'TestNotoKR', fontSize: 20);
    final thin = _width(base.copyWith(fontWeight: FontWeight.w100));
    final regular = _width(base.copyWith(fontWeight: FontWeight.w400));
    final bold = _width(base.copyWith(fontWeight: FontWeight.w800));
    final explicitBold = _width(base.copyWith(fontVariations: const [ui.FontVariation('wght', 800)]));
    expect(thin, lessThan(regular));
    expect(regular, lessThan(bold));
    expect(bold, closeTo(explicitBold, .01));
  });

  test('the OFL license ships next to the font', () {
    final text = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains("Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'."));
  });
}
