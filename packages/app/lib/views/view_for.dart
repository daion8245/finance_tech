import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:feature_guardian/feature_guardian.dart';
import 'package:flutter/widgets.dart';

import 'member_history.dart';
import 'member_home.dart';
import 'member_safety.dart';
import 'settings_view.dart';

/// 사용자 × 탭 → 화면. 홈·내역(내 계좌)은 누구나 같고, 보호자는 가족 알림·관리 탭이 더 있습니다.
Widget viewFor(BuildContext context, ShellState shell, FamilySnapshot data, {required String serverAddress}) {
  final memberId = shell.memberId;
  if (shell.tab == AppTab.settings) return SettingsView(serverAddress: serverAddress);
  if (memberId == null) {
    final me = data.guardian.banking;
    return switch (shell.tab) {
      AppTab.home => GuardianHomeView(data: data, banking: me == null ? const [] : guardianBanking(me)),
      AppTab.history when me != null => MemberHistory(member: me),
      AppTab.history || AppTab.alerts => GuardianAlertsView(data: data),
      _ => GuardianManageView(data: data),
    };
  }
  final member = data.member(memberId);
  return switch (shell.tab) {
    AppTab.home => member.isChild ? ChildHome(member: member, data: data) : SeniorHome(member: member, data: data),
    AppTab.history || AppTab.alerts => MemberHistory(member: member),
    _ => MemberSafety(member: member, data: data),
  };
}
