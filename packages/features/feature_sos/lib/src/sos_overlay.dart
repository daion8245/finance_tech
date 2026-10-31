import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// SOS 동결 직후 화면 전체를 덮는 빨간 안내 화면.
class SosOverlay extends StatefulWidget {
  final Member member;
  final String guardianName;
  final DateTime Function() now;
  final VoidCallback onCallGuardian;
  final VoidCallback onClose;

  const SosOverlay({
    super.key,
    required this.member,
    required this.guardianName,
    required this.now,
    required this.onCallGuardian,
    required this.onClose,
  });

  @override
  State<SosOverlay> createState() => _SosOverlayState();
}

class _SosOverlayState extends State<SosOverlay> with SingleTickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
  final _closeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeFocus.requestFocus());
  }

  @override
  void dispose() {
    _in.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = widget.member;
    final count = m.accounts.length;
    const line = TextStyle(color: Colors.white, fontSize: 14.1, fontWeight: FontWeight.w600);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _in, curve: const Interval(0, .6)),
      child: Material(
        color: c.red,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Semantics(
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: '모든 계좌 출금을 막았어요',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(parent: _in, curve: Curves.easeOutBack),
                        child: Container(
                          width: 73.6,
                          height: 73.6,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(FbIcons.lock, size: 34, color: c.red),
                        ),
                      ),
                      const SizedBox(height: 25.6),
                      const Text(
                        '모든 계좌 출금을\n막았어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 27.2, height: 1.3, fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
                      const SizedBox(height: 9.6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('자동 해제까지 ', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 14.4)),
                          if (m.frozenUntil != null)
                            CountdownText(
                              until: m.frozenUntil!,
                              now: widget.now,
                              style: const TextStyle(color: Colors.white, fontSize: 14.4, fontWeight: FontWeight.w800),
                            ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 25.6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          border: Border.symmetric(horizontal: BorderSide(color: Color(0x40FFFFFF))),
                        ),
                        child: Column(
                          children: [
                            _CheckLine(count > 1 ? '모든 계좌($count개) 출금 정지' : '${m.account.name} 출금 정지', line),
                            const SizedBox(height: 8),
                            _CheckLine('보호자 ${widget.guardianName}님께 알림 완료', line),
                          ],
                        ),
                      ),
                      const Text(
                        '입금은 그대로 받을 수 있어요.\n보이스피싱이 의심되면 경찰 112 · 금융감독원 1332에 신고하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5, height: 1.65),
                      ),
                      const SizedBox(height: 22.4),
                      SizedBox(
                        width: double.infinity,
                        child: FbButton(
                          '보호자에게 전화하기',
                          icon: FbIcons.phone,
                          variant: FbButtonVariant.white,
                          onPressed: widget.onCallGuardian,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Focus(
                          focusNode: _closeFocus,
                          child: FbButton('확인', variant: FbButtonVariant.ghostWhite, onPressed: widget.onClose),
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

class _CheckLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _CheckLine(this.text, this.style);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(FbIcons.check, size: 16, color: Colors.white),
      const SizedBox(width: 6.4),
      Flexible(child: Text(text, style: style, textAlign: TextAlign.center)),
    ],
  );
}
