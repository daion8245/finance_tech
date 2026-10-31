import 'package:flutter/material.dart';

import '../theme/fb_colors.dart';
import '../theme/fb_text.dart';

enum ResultTone { blue, red, soft }

/// 결과 동그라미 아이콘 (.result-icon). [ringing]이면 전화 울림 고리가 퍼집니다.
class ResultIcon extends StatefulWidget {
  final IconData icon;
  final ResultTone tone;
  final bool ringing;

  const ResultIcon(this.icon, {super.key, this.tone = ResultTone.blue, this.ringing = false});

  @override
  State<ResultIcon> createState() => _ResultIconState();
}

class _ResultIconState extends State<ResultIcon> with SingleTickerProviderStateMixin {
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.ringing) _ring.repeat();
  }

  @override
  void didUpdateWidget(ResultIcon old) {
    super.didUpdateWidget(old);
    if (widget.ringing && !_ring.isAnimating) _ring.repeat();
    if (!widget.ringing) _ring.stop();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final (bg, fg) = switch (widget.tone) {
      ResultTone.blue => (c.blue, Colors.white),
      ResultTone.red => (c.red, Colors.white),
      ResultTone.soft => (c.blueSoft, c.blue),
    };
    final circle = Container(
      width: 60.8,
      height: 60.8,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(widget.icon, color: fg, size: 29),
    );
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.ringing || reduce) return Center(child: circle);
    return Center(
      child: SizedBox(
        width: 60.8,
        height: 60.8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _ring,
              builder: (_, _) => Transform.scale(
                scale: 1 + .6 * _ring.value,
                child: Opacity(
                  opacity: .7 * (1 - _ring.value),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.blue, width: 2)),
                  ),
                ),
              ),
            ),
            circle,
          ],
        ),
      ),
    );
  }
}

/// 가운데 정렬 결과 문구 (.center-block).
class CenterBlock extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? body;

  const CenterBlock({super.key, required this.icon, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12.8, 0, 6.4),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(title, textAlign: TextAlign.center, style: FbText.resultTitle(c)),
          ),
          if (body != null) ...[
            const SizedBox(height: 6.4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 304),
              child: Text(body!, textAlign: TextAlign.center, style: FbText.body(c)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 가느다란 진행 막대 (.rail / .score-rail).
class FbRail extends StatelessWidget {
  final double fraction;
  final Color? color;
  final double height;

  const FbRail({super.key, required this.fraction, this.color, this.height = 6.4});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: c.soft,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 350),
          widthFactor: fraction.clamp(0, 1),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(color: color ?? c.blue, borderRadius: BorderRadius.circular(99)),
          ),
        ),
      ),
    );
  }
}

/// 위험 사유 상자 (.risk-box).
class RiskBox extends StatelessWidget {
  final String title;
  final bool danger;
  final List<String> items;

  const RiskBox({super.key, required this.title, required this.danger, this.items = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14.4),
      decoration: BoxDecoration(color: danger ? c.redSoft : c.soft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: danger ? c.redStrong : c.ink),
          ),
          if (items.isNotEmpty) const SizedBox(height: 5.6),
          for (final item in items) BulletText(item, style: TextStyle(fontSize: 13.1, height: 1.7, color: c.ink2)),
        ],
      ),
    );
  }
}

/// 점(•)이 붙은 한 줄.
class BulletText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const BulletText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final s = style ?? FbText.body(context.fb);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: s),
        Expanded(child: Text(text, style: s)),
      ],
    );
  }
}

/// 빈 목록 안내 (.empty).
class EmptyText extends StatelessWidget {
  final String text;
  const EmptyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 25.6),
    child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.1, color: context.fb.muted)),
  );
}
