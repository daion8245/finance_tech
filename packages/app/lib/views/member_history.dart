import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'member_widgets.dart';

class MemberHistory extends StatelessWidget {
  final Member member;
  const MemberHistory({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final filter = context.select((ShellCubit s) => s.state.txFilter);
    final now = context.read<FamilyCubit>().now();
    final list = member.ledger.where((t) => filter == 'all' || t.kind == filter).toList();
    return FbView(
      children: [
        Greeting(member.isChild ? '용돈 내역' : '거래 내역'),
        FbFilterChips(
          items: const [('all', '전체'), ('in', '입금'), ('out', '출금')],
          active: filter,
          onSelected: context.read<ShellCubit>().setTxFilter,
        ),
        FbCard.list(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: list.isEmpty
                ? const [EmptyText('해당하는 내역이 없어요')]
                : [for (final t in list) LedgerRow(entry: t, now: now)],
          ),
        ),
      ],
    );
  }
}
