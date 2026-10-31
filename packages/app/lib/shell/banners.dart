import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 상단 배너는 한 번에 하나만 보여 줍니다 (우선순위: 연결 끊김 → 결과 알림 → 대기 → 동결).
Widget? bannerFor(BuildContext context, ShellState shell, FamilyState family) {
  final c = context.fb;
  final data = family.data;
  final shellCubit = context.read<ShellCubit>();

  if (!family.reachable) {
    return FbBanner(
      title: '서버와 연결이 끊겼어요',
      sub: '다시 연결하는 중이에요 · 마지막으로 받은 상태를 보여 주고 있어요',
      titleColor: c.redStrong,
      leading: Icon(FbIcons.cloudOff, size: 18, color: c.redStrong),
      actionLabel: '다시 시도',
      onAction: context.read<FamilyCubit>().refresh,
    );
  }

  final memberId = shell.memberId;
  if (memberId == null) {
    final n = data.pending().length;
    if (n == 0 || shell.tab == AppTab.home) return null;
    return FbBanner(
      live: true,
      title: '승인 요청 $n건이 기다리고 있어요',
      actionLabel: '확인',
      onTap: () => shellCubit.switchTab(AppTab.home),
    );
  }

  final m = data.memberOrNull(memberId);
  if (m == null) return null;

  if (m.notices.isNotEmpty) {
    final n = m.notices.first;
    final (title, sub) = switch (n.status) {
      'approved' => ('보호자가 승인했어요', '${n.title} 완료'),
      'rejected' => ('보호자가 거절했어요', '${n.title}은 진행하지 않았어요'),
      'expired' => ('보호자 응답이 없어 취소했어요', n.reason),
      'failed' => ('처리하지 못했어요', n.reason),
      _ => ('알림', n.title),
    };
    return FbBanner(
      title: title,
      sub: sub,
      titleColor: n.status == 'approved' ? c.blue : c.redStrong,
      onClose: () async {
        try {
          await context.read<FamilyCubit>().dismissNotice(m.id, n.id);
        } on ApiException catch (e) {
          shellCubit.say(e.message);
        }
      },
    );
  }

  final pending = data.pending(m.id);
  if (pending.isNotEmpty) {
    final p = pending.first;
    return FbBanner(
      live: true,
      title: '보호자 확인 대기 중',
      sub: '${p.title}${p.amount > 0 ? ' · ${won(p.amount)}' : ''}',
      actionLabel: '보호자 화면',
      onAction: () => shellCubit.goto(Persona.guardian, AppTab.home),
    );
  }

  if (m.isFrozen && shell.tab != AppTab.home && shell.tab != AppTab.safety && m.frozenUntil != null) {
    return FbBanner(
      title: '출금 동결 중',
      titleColor: c.redStrong,
      leading: Icon(FbIcons.lock, size: 18, color: c.redStrong),
      sub: '해제까지 ${formatCountdown(m.frozenUntil!.difference(context.read<FamilyCubit>().now()))}',
      onTap: () => shellCubit.switchTab(AppTab.home),
    );
  }
  return null;
}
