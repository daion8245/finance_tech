import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'member_widgets.dart';

/// 안심 탭: SOS 동결, 보호자, 상황별 안심 모드.
class MemberSafety extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const MemberSafety({super.key, required this.member, required this.data});

  Future<void> _setMode(BuildContext context, String modeId) async {
    final shell = context.read<ShellCubit>();
    try {
      final r = await context.read<FamilyCubit>().setMode(member.id, modeId, byGuardian: false);
      switch (r.status) {
        case 'pending':
          shell.say('보호자에게 모드 변경을 요청했어요');
        case 'done':
          shell.say('${data.mode(modeId).label}로 바꿨어요');
      }
    } on ApiException catch (e) {
      shell.say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = member;
    final waitingMode = data.hasPending(m.id, 'mode');
    final modes = FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('안심 모드'),
          for (var i = 0; i < m.modes.length; i++)
            Builder(
              builder: (context) {
                final mode = data.mode(m.modes[i]);
                return FbOptionRow(
                  title: mode.label,
                  subtitle: mode.schedule.isEmpty ? mode.desc : '${mode.desc} · ${mode.schedule}',
                  selected: m.mode == mode.id,
                  divider: i > 0,
                  onTap: () => _setMode(context, mode.id),
                );
              },
            ),
          if (m.requireApprovalToLoosen)
            Padding(
              padding: const EdgeInsets.only(top: 9.6),
              child: Text(
                waitingMode ? '보호자에게 모드 변경을 요청했어요 · 확인을 기다리는 중' : '일반 모드로 바꾸려면 보호자 확인이 필요해요',
                style: FbText.small(c),
              ),
            ),
          if (m.sleepGuard)
            Padding(
              padding: const EdgeInsets.only(top: 9.6),
              child: Row(
                children: [
                  Icon(FbIcons.moon, size: 15, color: m.sleepActive ? c.blue : c.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.sleepActive ? '수면 안심 모드 작동 중 · 지금은 이체 전에 보호자 확인을 거쳐요' : '수면 안심 모드 · 23:00~06:00 이체는 보호자 확인 후 보내져요',
                      style: FbText.small(c).copyWith(color: m.sleepActive ? c.blue : c.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return FbView(
      wide: true,
      children: [
        const Greeting('안심'),
        FbSplit(
          main: [SosSlot(member: m, data: data, inCard: true), GuardianCard(member: m, data: data)],
          side: [modes],
        ),
      ],
    );
  }
}
