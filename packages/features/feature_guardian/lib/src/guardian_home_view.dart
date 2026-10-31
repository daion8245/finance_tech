import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'alert_row.dart';
import 'request_card.dart';

/// 보호자 홈: 기다리는 승인 요청, 내 계좌, 최근 알림, 가족 상태.
class GuardianHomeView extends StatefulWidget {
  final FamilySnapshot data;

  /// 보호자 본인 계좌 카드들 (잔액·송금·결제·최근 거래). 송금·결제 기능은 앱이 연결합니다.
  final List<Widget> banking;

  const GuardianHomeView({super.key, required this.data, this.banking = const []});

  @override
  State<GuardianHomeView> createState() => _GuardianHomeViewState();
}

class _GuardianHomeViewState extends State<GuardianHomeView> {
  final _acked = <String>{};

  /// 화면에 띄운 요청은 "푸시를 확인했다"고 서버에 알려, ARS 전화가 가지 않게 합니다.
  void _acknowledge(List<ApprovalRequest> pending) {
    final ids = [
      for (final r in pending)
        if (r.pushAckAt == null && r.arsCalledAt == null && _acked.add(r.id)) r.id,
    ];
    if (ids.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FamilyCubit>().acknowledge(ids).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final family = context.read<FamilyCubit>();
    final pending = data.pending();
    _acknowledge(pending);
    final now = family.now();

    final requests = [for (final r in pending) RequestCard(key: ValueKey(r.id), request: r, data: data, now: family.now)];
    final alerts = FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHead(
            '최근 알림',
            action: '전체보기',
            onAction: () => context.read<ShellCubit>().switchTab(AppTab.alerts),
          ),
          for (final a in data.alerts.take(5)) AlertRow(alert: a, data: data, now: now),
          if (data.alerts.isEmpty) const EmptyText('아직 알림이 없어요'),
        ],
      ),
    );
    final familyCard = FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListHead('가족'),
          Text('오늘 차단 ${data.blockedToday}건 · AI 위험 판정 ${data.riskyTransfers}건', style: FbText.small(context.fb)),
          for (final m in data.members) _FamilyRow(member: m, data: data),
        ],
      ),
    );

    return FbView(
      wide: true,
      children: [
        Greeting(
          pending.isEmpty ? '가족 모두 안전해요' : '확인할 요청이 ${pending.length}건 있어요',
          sub: '${data.guardian.name}님',
        ),
        // 웹: 왼쪽은 요청과 내 계좌, 오른쪽은 가족 (내 계좌가 없으면 알림을 왼쪽에)
        FbSplit(
          main: [...requests, ...widget.banking, if (widget.banking.isEmpty) alerts],
          side: [familyCard, if (widget.banking.isNotEmpty) alerts],
          mobile: [...requests, ...widget.banking, familyCard, alerts],
        ),
      ],
    );
  }
}

class _FamilyRow extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const _FamilyRow({required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);
    final m = member;
    final detail = m.isChild ? '오늘 ${won(m.spentToday)} 사용' : '잔액 ${wonOrHidden(m.balance, hidden: hidden)}';
    return FbListRow(
      leading: TxLogo.initial(m.name),
      title: Text(m.label),
      subtitle: '${data.mode(m.mode).label} · $detail',
      trailing: Text(
        m.isFrozen ? '동결 중' : '정상',
        style: FbText.note(c).copyWith(color: m.isFrozen ? c.redStrong : c.muted),
      ),
      chevron: true,
      onTap: () => context.read<ShellCubit>().switchTab(AppTab.safety),
    );
  }
}
