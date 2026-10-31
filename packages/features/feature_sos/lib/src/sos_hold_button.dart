import 'package:core_ui/core_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 빨간 SOS 버튼. [holdDuration] (기본 2초) 동안 누르고 있으면 [onComplete]가 불립니다.
/// 누르는 동안 왼쪽부터 어두운 막이 차오르고 SOS 배지가 두근거립니다.
class SosHoldButton extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onStart;
  final void Function(double progress)? onCancel;
  final Duration holdDuration;
  final String hint;

  const SosHoldButton({
    super.key,
    required this.onComplete,
    this.onStart,
    this.onCancel,
    this.holdDuration = const Duration(seconds: 2),
    this.hint = '위급할 때 길게 누르세요 · 흔들어도 돼요',
  });

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton> with TickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _complete();
    });
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _holding = false;

  @override
  void dispose() {
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _begin() {
    if (_holding) return;
    setState(() => _holding = true);
    _pulse.repeat(reverse: true);
    _hold.forward(from: 0);
    widget.onStart?.call();
  }

  void _cancel() {
    if (!_holding) return;
    final progress = _hold.value;
    _stop();
    if (progress < 1) widget.onCancel?.call(progress);
  }

  void _stop() {
    _hold.stop();
    _hold.value = 0;
    _pulse.stop();
    _pulse.value = 0;
    if (mounted) setState(() => _holding = false);
  }

  void _complete() {
    _stop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final seconds = widget.holdDuration.inMilliseconds / 1000;
    return Semantics(
      button: true,
      label: 'SOS 계좌 동결. ${seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1)}초간 길게 누르세요',
      onLongPress: widget.onComplete,
      excludeSemantics: true,
      child: Focus(
        onKeyEvent: (node, event) {
          final key = event.logicalKey;
          if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.space) return KeyEventResult.ignored;
          if (event is KeyDownEvent) _begin();
          if (event is KeyUpEvent) _cancel();
          return KeyEventResult.handled;
        },
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == kPrimaryButton || e.kind == PointerDeviceKind.touch) _begin();
          },
          onPointerUp: (_) => _cancel(),
          onPointerCancel: (_) => _cancel(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: c.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18.4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    left: -20,
                    right: -20,
                    top: -18.4,
                    bottom: -18.4,
                    child: AnimatedBuilder(
                      animation: _hold,
                      builder: (_, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _hold.value,
                        child: const ColoredBox(color: Color(0x47640A0A)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                        child: Container(
                          width: 51.2,
                          height: 51.2,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Text('SOS', style: TextStyle(color: c.red, fontWeight: FontWeight.w900, fontSize: 14.7)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '계좌 동결',
                              style: TextStyle(color: Colors.white, fontSize: 19.2, fontWeight: FontWeight.w800, letterSpacing: -.5),
                            ),
                            const SizedBox(height: 3.2),
                            Text(
                              _holding ? '그대로 누르고 계세요…' : widget.hint,
                              style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.8, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
