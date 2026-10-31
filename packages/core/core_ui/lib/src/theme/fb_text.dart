import 'package:flutter/widgets.dart';

import 'fb_colors.dart';

/// 글자 스타일. 크기는 시안의 rem 값을 16px 기준으로 옮겼습니다.
/// 큰 글씨·어르신 화면 확대는 앱 셸이 MediaQuery 글자 배율로 적용합니다.
abstract final class FbText {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle greet(FbColors c) =>
      TextStyle(fontSize: 24.8, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.35, color: c.ink);
  static TextStyle greetSub(FbColors c) => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted);
  static TextStyle cardTitle(FbColors c) =>
      TextStyle(fontSize: 16.8, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.ink);
  static TextStyle cardDesc(FbColors c) => TextStyle(fontSize: 13.8, height: 1.6, color: c.ink2);
  static TextStyle more(FbColors c) => TextStyle(fontSize: 13.1, fontWeight: FontWeight.w700, color: c.muted);
  static TextStyle label(FbColors c) => TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600, color: c.ink2);
  static TextStyle balance(FbColors c) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.2,
    color: c.ink,
    fontFeatures: _tabular,
  );
  static TextStyle bigAmount(FbColors c) =>
      TextStyle(fontSize: 25.6, fontWeight: FontWeight.w800, letterSpacing: -1, color: c.ink, fontFeatures: _tabular);
  static TextStyle rowTitle(FbColors c) => TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: c.ink);
  static TextStyle rowSub(FbColors c) => TextStyle(fontSize: 12.5, height: 1.45, color: c.muted);
  static TextStyle amount(FbColors c) =>
      TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: c.ink, fontFeatures: _tabular);
  static TextStyle note(FbColors c) => TextStyle(fontSize: 13.1, fontWeight: FontWeight.w700, color: c.muted);
  static TextStyle small(FbColors c) => TextStyle(fontSize: 12.8, height: 1.55, color: c.muted);
  static TextStyle hint(FbColors c) => TextStyle(fontSize: 13.1, height: 1.6, color: c.muted);
  static TextStyle body(FbColors c) => TextStyle(fontSize: 14.1, height: 1.6, color: c.ink2);
  static TextStyle button = const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static TextStyle sheetTitle(FbColors c) =>
      TextStyle(fontSize: 20.8, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: c.ink);
  static TextStyle resultTitle(FbColors c) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink, height: 1.35);
  static TextStyle tabular(TextStyle s) => s.copyWith(fontFeatures: _tabular);
}
