import 'package:flutter/material.dart';

import '../theme/fb_colors.dart';
import '../theme/fb_icons.dart';
import '../theme/fb_text.dart';
import '../theme/fb_theme.dart';

/// 동그란 머리글자/아이콘 (.tx-logo).
class TxLogo extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final bool blue;
  final double size;

  const TxLogo({super.key, this.text, this.icon, this.blue = false, this.size = 40});

  /// 이름의 첫 글자.
  factory TxLogo.initial(String name, {bool blue = false}) =>
      TxLogo(text: name.trim().isEmpty ? '?' : name.trim().characters.first, blue: blue);

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final fg = blue ? c.blue : c.ink2;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: blue ? c.blueSoft : c.soft, shape: BoxShape.circle),
        child: icon != null
            ? Icon(icon, size: size * .44, color: fg)
            : Text(text ?? '', style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}

/// 목록 한 줄 (.tx-item / .row-btn). [onTap]이 있으면 누를 수 있고 끝에 화살표가 붙습니다.
class FbListRow extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final EdgeInsets padding;

  const FbListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.padding = const EdgeInsets.symmetric(vertical: 13.6),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 13.6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: FbText.rowTitle(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3.2),
                  Text(subtitle!, style: subtitleStyle ?? FbText.rowSub(c)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (chevron) ...[const SizedBox(width: 6), Icon(FbIcons.chevron, size: 19, color: c.faint)],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
  }
}

/// 카드처럼 생긴 이동 줄 (.row-link).
class FbRowLink extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? leading;

  const FbRowLink({super.key, required this.title, this.subtitle, this.onTap, this.leading});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 21.6, vertical: 17.6),
          decoration: c.cardBorder != null
              ? BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: c.cardBorder!, width: 2))
              : null,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 13.6)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15.7, fontWeight: FontWeight.w700, color: c.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3.2),
                      Text(subtitle!, style: FbText.small(c)),
                    ],
                  ],
                ),
              ),
              Icon(FbIcons.chevron, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단 안내 배너 (.banner). 한 번에 하나만 보여 줍니다.
class FbBanner extends StatelessWidget {
  final String title;
  final String? sub;
  final Color? titleColor;
  final bool live;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final Widget? leading;

  const FbBanner({
    super.key,
    required this.title,
    this.sub,
    this.titleColor,
    this.live = false,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.onClose,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12.8, 12, 12.8),
            child: Row(
              children: [
                if (live) ...[const LiveDot(), const SizedBox(width: 9.6)],
                if (leading != null) ...[leading!, const SizedBox(width: 9.6)],
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: TextStyle(fontWeight: FontWeight.w700, color: titleColor ?? c.ink),
                        ),
                        if (sub != null) TextSpan(text: '\n$sub', style: TextStyle(color: c.muted)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.4, height: 1.45),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction ?? onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: c.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(44, 32),
                      textStyle: const TextStyle(fontFamily: FbTheme.fontFamily, fontSize: 12.8, fontWeight: FontWeight.w700),
                    ),
                    child: Text(actionLabel!),
                  ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: '알림 닫기',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(FbIcons.close, size: 16, color: c.faint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 깜빡이는 파란 점 (.live-dot).
class LiveDot extends StatefulWidget {
  final Color? color;
  const LiveDot({super.key, this.color});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color ?? context.fb.blue, shape: BoxShape.circle),
    );
    if (reduce) return dot;
    return FadeTransition(opacity: Tween(begin: 1.0, end: .3).animate(_c), child: dot);
  }
}
