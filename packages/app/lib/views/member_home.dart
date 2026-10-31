import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'member_widgets.dart';

/// 어르신 홈: 큰 버튼 [송금] [결제] [조회]와 [SOS] (기획서 3.4).
class SeniorHome extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const SeniorHome({super.key, required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final account = AccountCard(member: member);
    final sos = SosSlot(member: member, data: data);
    final recent = RecentCard(member: member);
    return FbView(
      wide: true,
      children: [
        Greeting('안녕하세요, ${member.name}님'),
        FbSplit(
          main: [account, recent],
          side: [sos, GuardianCard(member: member, data: data)],
          mobile: [account, sos, recent],
        ),
      ],
    );
  }
}

/// 아이 홈: 쓸 수 있는 돈, 오늘 쓴 돈, 지금 안심 모드.
class ChildHome extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const ChildHome({super.key, required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = member;
    final mode = data.mode(m.mode);
    final spent = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Transform.translate(
        offset: const Offset(0, -8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('오늘 쓴 돈', style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: c.muted))),
                Text(
                  '${formatNumber(m.spentToday)} / ${won(m.dailyLimit)}',
                  style: FbText.tabular(TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: c.muted)),
                ),
              ],
            ),
            const SizedBox(height: 7.2),
            FbRail(fraction: m.dailyLimit == 0 ? 0 : m.spentToday / m.dailyLimit),
          ],
        ),
      ),
    );
    final wallet = AccountCard(member: m, title: '쓸 수 있는 돈', extra: spent);
    final modeRow = FbRowLink(
      title: mode.label,
      subtitle: mode.desc,
      onTap: () => context.read<ShellCubit>().switchTab(AppTab.safety),
    );
    final sos = SosSlot(member: m, data: data);
    final recent = RecentCard(member: m);
    return FbView(
      wide: true,
      children: [
        Greeting('안녕, ${m.callName}!'),
        FbSplit(main: [wallet, recent], side: [sos, modeRow], mobile: [wallet, modeRow, sos, recent]),
      ],
    );
  }
}

/// 보호자 본인 계좌: 가족 홈 위에 놓이는 잔액·송금·결제·최근 거래.
List<Widget> guardianBanking(Member me) => [AccountCard(member: me), RecentCard(member: me)];
