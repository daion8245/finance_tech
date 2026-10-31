import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'alert_row.dart';

/// 가족 알림 전체 목록.
class GuardianAlertsView extends StatelessWidget {
  final FamilySnapshot data;

  const GuardianAlertsView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final filter = context.select((ShellCubit s) => s.state.alertFilter);
    final now = context.read<FamilyCubit>().now();
    final list = data.alerts.where((a) => filter == 'all' || a.status == 'pending').toList();
    return FbView(
      children: [
        const Greeting('가족 알림'),
        FbFilterChips(
          items: const [('all', '전체'), ('pending', '확인 필요')],
          active: filter,
          onSelected: context.read<ShellCubit>().setAlertFilter,
        ),
        FbCard.list(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: list.isEmpty
                ? const [EmptyText('확인할 알림이 없어요')]
                : [for (final a in list) AlertRow(alert: a, data: data, now: now)],
          ),
        ),
      ],
    );
  }
}
