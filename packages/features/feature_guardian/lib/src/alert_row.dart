import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

const alertLabels = {
  'ok': '정상',
  'pending': '확인 필요',
  'blocked': '차단',
  'approved': '승인',
  'rejected': '거절',
  'frozen': '동결',
  'failed': '실패',
  'cancelled': '취소',
  'expired': '시간 초과',
};

const dangerStatuses = {'pending', 'blocked', 'rejected', 'frozen', 'expired'};

/// 가족 알림 한 줄.
class AlertRow extends StatelessWidget {
  final FamilyAlert alert;
  final FamilySnapshot data;
  final DateTime now;

  const AlertRow({super.key, required this.alert, required this.data, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = data.memberOrNull(alert.memberId);
    final parts = [m?.relationLabel ?? '', formatWhen(alert.at, now), if (alert.amount > 0) won(alert.amount)];
    return FbListRow(
      leading: TxLogo.initial(m?.name ?? '?'),
      title: Text(alert.title),
      subtitle: parts.where((p) => p.isNotEmpty).join(' · '),
      trailing: Text(
        alertLabels[alert.status] ?? '',
        style: FbText.note(c).copyWith(color: dangerStatuses.contains(alert.status) ? c.redStrong : c.muted),
      ),
    );
  }
}
