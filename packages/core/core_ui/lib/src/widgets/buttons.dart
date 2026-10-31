import 'package:flutter/material.dart';

import '../theme/fb_colors.dart';
import '../theme/fb_text.dart';
import '../theme/fb_theme.dart';

enum FbButtonVariant { primary, gray, red, white, ghostWhite }

/// 시안의 .btn. 누르면 살짝 작아집니다.
class FbButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final FbButtonVariant variant;
  final IconData? icon;
  final bool busy;

  const FbButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = FbButtonVariant.primary,
    this.icon,
    this.busy = false,
  });

  const FbButton.gray(this.label, {super.key, this.onPressed, this.icon, this.busy = false})
    : variant = FbButtonVariant.gray;

  @override
  State<FbButton> createState() => _FbButtonState();
}

class _FbButtonState extends State<FbButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final (bg, fg) = switch (widget.variant) {
      FbButtonVariant.primary => (c.blue, Colors.white),
      FbButtonVariant.gray => (c.soft, c.ink2),
      FbButtonVariant.red => (c.red, Colors.white),
      FbButtonVariant.white => (Colors.white, c.redStrong),
      FbButtonVariant.ghostWhite => (Colors.white.withValues(alpha: .16), Colors.white),
    };
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? '${widget.label}, 처리 중' : null,
      child: AnimatedScale(
        scale: _down ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: enabled || widget.busy ? 1 : .45,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (v) => setState(() => _down = v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 49.6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.busy)
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                      else if (widget.icon != null)
                        Icon(widget.icon, size: 19, color: fg),
                      if (widget.busy || widget.icon != null) const SizedBox(width: 6),
                      Flexible(
                        child: ExcludeSemantics(
                          excluding: widget.busy,
                          child: Text(
                            widget.label,
                            style: FbText.button.copyWith(color: fg),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 나란히 놓인 버튼들. [flex]로 너비 비율을 정합니다.
class FbButtonRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;

  const FbButtonRow({super.key, required this.children, this.flex});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(flex: flex?[i] ?? 1, child: children[i]),
      ],
    ],
  );
}

/// 회색 글자 버튼 (.text-btn, .more-btn).
class FbTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;

  const FbTextButton(this.label, {super.key, this.onPressed, this.color, this.fontSize = 13.8});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? c.muted,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minimumSize: const Size(44, 36),
        textStyle: TextStyle(fontFamily: FbTheme.fontFamily, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
