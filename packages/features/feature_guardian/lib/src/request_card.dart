import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'guardian_actions.dart';

/// 보호자 콜백 승인 카드: 누가, 얼마를, 왜 위험한지 보여 주고 승인/거절을 받습니다.
class RequestCard extends StatefulWidget {
  final ApprovalRequest request;
  final FamilySnapshot data;
  final DateTime Function() now;

  const RequestCard({super.key, required this.request, required this.data, required this.now});

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool? _busy; // true: 승인 중, false: 거절 중

  Future<void> _decide(bool approve) async {
    setState(() => _busy = approve);
    await decideRequest(context, widget.request.id, approve: approve);
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final r = widget.request;
    final m = widget.data.memberOrNull(r.memberId);
    final risk = r.risk;
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${m?.label ?? ''}님의 요청 · ${formatWhen(r.createdAt, widget.now())}',
            style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w600, color: c.muted),
          ),
          const SizedBox(height: 5.6),
          Text(r.amount > 0 ? won(r.amount) : r.title, style: FbText.bigAmount(c)),
          const SizedBox(height: 2.4),
          Text(r.amount > 0 ? '${r.title} · ${r.detail}' : r.detail, style: TextStyle(fontSize: 13.8, color: c.ink2)),
          const SizedBox(height: 16),
          if (risk != null) ...[
            RiskBox(
              title: 'AI 위험도 ${risk.score}점 · ${risk.level.label}',
              danger: !risk.isSafe,
              items: [for (final s in risk.signals) s.label],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(r.arsCalledAt != null ? FbIcons.phone : FbIcons.bell, size: 15, color: c.muted),
              const SizedBox(width: 5),
              Text(r.arsCalledAt != null ? 'ARS 전화 · 앱 알림' : '앱 알림', style: FbText.small(c)),
              if (r.expiresAt != null) ...[
                Text(' · 자동 취소까지 ', style: FbText.small(c)),
                CountdownText(
                  until: r.expiresAt!,
                  now: widget.now,
                  format: formatMinSec,
                  style: FbText.small(c).copyWith(fontWeight: FontWeight.w800, color: c.ink2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          FbButtonRow(
            children: [
              FbButton.gray('거절', busy: _busy == false, onPressed: _busy == null ? () => _decide(false) : null),
              FbButton('승인', busy: _busy == true, onPressed: _busy == null ? () => _decide(true) : null),
            ],
          ),
        ],
      ),
    );
  }
}
