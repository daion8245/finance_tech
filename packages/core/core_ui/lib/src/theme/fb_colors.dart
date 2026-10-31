import 'package:flutter/material.dart';

/// 색 토큰. 파랑은 기본 동작, 빨강은 SOS·위험에만 씁니다.
@immutable
class FbColors extends ThemeExtension<FbColors> {
  final Color blue;
  final Color blueStrong;
  final Color blueSoft;
  final Color red;
  final Color redStrong;
  final Color redSoft;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color faint;
  final Color line;
  final Color bg;
  final Color card;
  final Color soft;
  final Color glass;
  final Color navIdle;
  final Color backdrop;

  /// 고대비 모드에서 카드에 두르는 테두리 (없으면 null).
  final Color? cardBorder;

  const FbColors({
    required this.blue,
    required this.blueStrong,
    required this.blueSoft,
    required this.red,
    required this.redStrong,
    required this.redSoft,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.faint,
    required this.line,
    required this.bg,
    required this.card,
    required this.soft,
    required this.glass,
    required this.navIdle,
    required this.backdrop,
    this.cardBorder,
  });

  static const light = FbColors(
    blue: Color(0xFF3182F6),
    blueStrong: Color(0xFF1B64DA),
    blueSoft: Color(0xFFE8F3FF),
    red: Color(0xFFF04452),
    redStrong: Color(0xFFD0293A),
    redSoft: Color(0xFFFFF0F1),
    ink: Color(0xFF191F28),
    ink2: Color(0xFF4E5968),
    muted: Color(0xFF8B95A1),
    faint: Color(0xFFB0B8C1),
    line: Color(0xFFF2F4F6),
    bg: Color(0xFFF3F5F8),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF2F4F6),
    glass: Color(0xEBF3F5F8),
    navIdle: Color(0xFFB0B8C1),
    backdrop: Color(0xFFECEFF4),
  );

  static const highContrast = FbColors(
    blue: Color(0xFF0B55D6),
    blueStrong: Color(0xFF063B9C),
    blueSoft: Color(0xFFDCE9FF),
    red: Color(0xFFC8102E),
    redStrong: Color(0xFF9E0B22),
    redSoft: Color(0xFFFFE3E7),
    ink: Color(0xFF000000),
    ink2: Color(0xFF14181E),
    muted: Color(0xFF2E353F),
    faint: Color(0xFF4A525C),
    line: Color(0xFF8A929C),
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFE6EAEF),
    glass: Color(0xF5FFFFFF),
    navIdle: Color(0xFF4A525C),
    backdrop: Color(0xFFFFFFFF),
    cardBorder: Color(0xFF1B1F24),
  );

  static FbColors of(BuildContext context) => Theme.of(context).extension<FbColors>() ?? light;

  @override
  FbColors copyWith() => this;

  @override
  FbColors lerp(ThemeExtension<FbColors>? other, double t) {
    if (other is! FbColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FbColors(
      blue: l(blue, other.blue),
      blueStrong: l(blueStrong, other.blueStrong),
      blueSoft: l(blueSoft, other.blueSoft),
      red: l(red, other.red),
      redStrong: l(redStrong, other.redStrong),
      redSoft: l(redSoft, other.redSoft),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      line: l(line, other.line),
      bg: l(bg, other.bg),
      card: l(card, other.card),
      soft: l(soft, other.soft),
      glass: l(glass, other.glass),
      navIdle: l(navIdle, other.navIdle),
      backdrop: l(backdrop, other.backdrop),
      cardBorder: t < .5 ? cardBorder : other.cardBorder,
    );
  }
}

extension FbColorsContext on BuildContext {
  FbColors get fb => FbColors.of(this);
}
