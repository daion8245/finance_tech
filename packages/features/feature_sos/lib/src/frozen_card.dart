import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// 동결 중일 때 SOS 버튼 자리에 보이는 카드.
class FrozenCard extends StatelessWidget {
  final Member member;
  final DateTime Function() now;
  final bool waitingForGuardian;
  final VoidCallback? onRequestUnfreeze;

  const FrozenCard({
    super.key,
    required this.member,
    required this.now,
    required this.waitingForGuardian,
    this.onRequestUnfreeze,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return FbCard(
      color: c.redSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(FbIcons.lock, size: 19, color: c.redStrong),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '모든 계좌 출금이 멈춰 있어요',
                  style: TextStyle(fontSize: 16.8, fontWeight: FontWeight.w800, color: c.redStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '자동 해제까지 '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: member.frozenUntil == null
                      ? const SizedBox.shrink()
                      : CountdownText(
                          until: member.frozenUntil!,
                          now: now,
                          style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w800, color: c.ink2),
                        ),
                ),
                const TextSpan(text: '\n입금은 그대로 받을 수 있어요.'),
              ],
            ),
            style: TextStyle(fontSize: 13.6, height: 1.6, color: c.ink2),
          ),
          const SizedBox(height: 17.6),
          FbButton(
            waitingForGuardian ? '보호자 확인 대기 중' : '보호자에게 해제 요청',
            variant: FbButtonVariant.white,
            onPressed: waitingForGuardian ? null : onRequestUnfreeze,
          ),
        ],
      ),
    );
  }
}
