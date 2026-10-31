import 'package:flutter/material.dart';

import 'fb_colors.dart';

/// Material 3 테마. 앱에 넣은 Noto Sans KR(가변 글꼴)을 씁니다.
/// FontWeight가 글꼴의 wght 축(100~900)에 그대로 적용됩니다.
abstract final class FbTheme {
  /// core_ui 패키지에 들어 있는 글꼴 이름 (pubspec의 family).
  static const fontFamily = 'packages/core_ui/NotoSansKR';
  static const fontFallback = ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'];

  static ThemeData build({bool highContrast = false}) {
    final c = highContrast ? FbColors.highContrast : FbColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.blue,
      primary: c.blue,
      onPrimary: Colors.white,
      error: c.red,
      surface: c.card,
      onSurface: c.ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      textTheme: base.textTheme.apply(
        bodyColor: c.ink,
        displayColor: c.ink,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
      ),
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.4, vertical: 13.6),
        hintStyle: TextStyle(color: c.faint, fontSize: 16),
        border: border(const Color(0xFFE5E8EB)),
        enabledBorder: border(highContrast ? c.line : const Color(0xFFE5E8EB)),
        focusedBorder: border(c.blue),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.blue,
        inactiveTrackColor: c.soft,
        thumbColor: c.blue,
        overlayColor: c.blue.withValues(alpha: .12),
        trackHeight: 5,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: const Color(0xFF252F40), borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
