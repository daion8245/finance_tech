import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../views/view_for.dart';
import 'banners.dart';
import 'scenarios.dart';

typedef NavEntry = (AppTab tab, String label, IconData icon);

const _memberNav = <NavEntry>[
  (AppTab.home, '홈', FbIcons.home),
  (AppTab.history, '내역', FbIcons.list),
  (AppTab.safety, '안심', FbIcons.shield),
  (AppTab.settings, '설정', FbIcons.gear),
];

List<NavEntry> navFor(Persona p) => switch (p) {
  Persona.senior => _memberNav,
  Persona.child => const [
    (AppTab.home, '홈', FbIcons.home),
    (AppTab.history, '용돈', FbIcons.list),
    (AppTab.safety, '안심', FbIcons.shield),
    (AppTab.settings, '설정', FbIcons.gear),
  ],
  // 보호자도 내 계좌(홈·내역)는 똑같이 쓰고, 가족 알림·관리가 더 있습니다.
  Persona.guardian => const [
    (AppTab.home, '홈', FbIcons.home),
    (AppTab.history, '내역', FbIcons.list),
    (AppTab.alerts, '알림', FbIcons.bell),
    (AppTab.safety, '관리', FbIcons.users),
    (AppTab.settings, '설정', FbIcons.gear),
  ],
};

/// 상단의 시연 사용자 전환 (어르신 / 아이 / 보호자).
class PersonaSwitch extends StatelessWidget {
  const PersonaSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final persona = context.select((ShellCubit s) => s.state.persona);
    final shell = context.read<ShellCubit>();
    return Semantics(
      label: '시연할 사용자 선택',
      child: FbSegmented<Persona>(
        compact: true,
        options: [for (final p in Persona.values) (p, p.label)],
        value: persona,
        onChanged: (p) => shell.goto(p, shell.state.tab),
      ),
    );
  }
}

/// 알림 종 (확인할 것이 있으면 빨간 점).
class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.watch<ShellCubit>().state;
    final data = context.watch<FamilyCubit>().state.snapshot;
    final memberId = shell.memberId;
    final dot = data != null &&
        (memberId == null ? data.pending().isNotEmpty : (data.memberOrNull(memberId)?.notices.isNotEmpty ?? false));
    return IconButton(
      tooltip: '알림',
      onPressed: () => context.read<ShellCubit>().switchTab(memberId == null ? AppTab.alerts : AppTab.history),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(FbIcons.bell, color: c.ink2, size: 23),
          if (dot)
            Positioned(
              top: 0,
              right: 1,
              child: Container(width: 7, height: 7, decoration: BoxDecoration(color: c.red, shape: BoxShape.circle)),
            ),
        ],
      ),
    );
  }
}

/// 배너 + 지금 탭의 화면.
class ShellBody extends StatelessWidget {
  final String serverAddress;
  const ShellBody({super.key, required this.serverAddress});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellCubit>().state;
    final family = context.watch<FamilyCubit>().state;
    final banner = bannerFor(context, shell, family);
    final isWeb = FbLayout.isWebOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null)
          Padding(
            padding: EdgeInsets.only(bottom: isWeb ? 12 : 6, top: isWeb ? 0 : 2),
            child: isWeb
                ? Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: banner),
                  )
                : banner,
          ),
        KeyedSubtree(
          key: ValueKey('${shell.persona.name}-${shell.tab.name}'),
          child: viewFor(context, shell, family.data, serverAddress: serverAddress),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 모바일 (1단 + 하단 메뉴)
class MobileLayout extends StatefulWidget {
  final String serverAddress;
  const MobileLayout({super.key, required this.serverAddress});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.watch<ShellCubit>().state;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return BlocListener<ShellCubit, ShellState>(
      listenWhen: (a, b) => a.tab != b.tab || a.persona != b.persona,
      listener: (_, _) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            Container(
              color: c.glass,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 8, 8),
              child: Row(
                children: [
                  Brand(showWordmark: !narrow),
                  const Spacer(),
                  const PersonaSwitch(),
                  const BellButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: ShellBody(serverAddress: widget.serverAddress),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2FFFFFF),
            border: Border(top: BorderSide(color: Color(0xFFEFF1F4))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (final (tab, label, icon) in navFor(shell.persona))
                    Expanded(
                      child: _BottomNavItem(
                        label: label,
                        icon: icon,
                        selected: shell.tab == tab,
                        onTap: () => context.read<ShellCubit>().switchTab(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final color = selected ? c.ink : c.navIdle;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 웹 (16:9, 사이드바 + 2단)
class WebLayout extends StatefulWidget {
  final String serverAddress;
  const WebLayout({super.key, required this.serverAddress});

  @override
  State<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends State<WebLayout> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final size = MediaQuery.sizeOf(context);
    final shell = context.watch<ShellCubit>().state;
    final sidebarWidth = size.width < 1100 ? 200.0 : 232.0;
    final framed = size.width > 1600 || size.height > 900;

    final frame = Row(
      children: [
        Container(
          width: sidebarWidth,
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFEEF0F3))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 34),
                child: Align(alignment: Alignment.centerLeft, child: Brand(size: 20)),
              ),
              for (final (tab, label, icon) in navFor(shell.persona))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SideNavItem(
                    label: label,
                    icon: icon,
                    selected: shell.tab == tab,
                    onTap: () => context.read<ShellCubit>().switchTab(tab),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F2F5)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('바로 시연해 보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.faint)),
                    const SizedBox(height: 6),
                    for (final s in Scenario.values)
                      InkWell(
                        onTap: () => runScenario(context, s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(s.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink2)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFEEF0F3))),
                ),
                child: Row(
                  children: [
                    if (size.width >= 560) ...[
                      Text('시연 사용자', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                      const SizedBox(width: 10),
                    ],
                    const PersonaSwitch(),
                    const Spacer(),
                    const BellButton(),
                  ],
                ),
              ),
              Expanded(
                child: BlocListener<ShellCubit, ShellState>(
                  listenWhen: (a, b) => a.tab != b.tab || a.persona != b.persona,
                  listener: (_, _) {
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  },
                  child: Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(size.width < 1100 ? 26 : 36, 24, size.width < 1100 ? 26 : 36, 48),
                            child: ShellBody(serverAddress: widget.serverAddress),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ColoredBox(
      color: framed ? c.backdrop : c.bg,
      child: Center(
        child: Container(
          width: size.width.clamp(0, 1600),
          height: size.height.clamp(0, 900),
          decoration: BoxDecoration(
            color: c.bg,
            boxShadow: framed ? const [BoxShadow(color: Color(0x242D4468), blurRadius: 70, offset: Offset(0, 24))] : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: Material(color: c.bg, child: frame),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final color = selected ? c.blueStrong : c.muted;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.blueSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: c.soft,
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: color),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
