import 'dart:async';
import 'dart:math' as math;

import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_guardian/feature_guardian.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'feedback_service.dart';
import 'layouts.dart';
import 'shake_watcher.dart';
import 'startup_views.dart';
import 'toast.dart';

/// 앱 셸: 서버 연결 → 웹/모바일 레이아웃 → 그 위의 SOS 화면·토스트.
/// 실시간 이벤트에 반응하고(다른 기기 알림, ARS 전화), 피드백 요청을 진동·음성으로 내보냅니다.
class AppShell extends StatefulWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  final String serverAddress;

  const AppShell({super.key, required this.serverAddress});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  final _toast = GlobalKey<ToastHostState>();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    final shell = context.read<ShellCubit>();
    _subs
      ..add(shell.feedback.listen(_onFeedback))
      ..add(context.read<FamilyCubit>().events.listen(_onEvent));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _shake.dispose();
    super.dispose();
  }

  void _onFeedback(FeedbackRequest f) {
    final prefs = context.read<ShellCubit>().state.prefs;
    final out = context.read<FeedbackOutput>();
    if (f.toast) _toast.currentState?.show(f.message);
    if (prefs.haptics && f.vibrate.isNotEmpty) out.vibrate(f.vibrate);
    if (prefs.voice && f.speak) out.speak(f.message);
  }

  /// 서버 이벤트에 반응합니다. 이 기기에서 한 일은 이미 안내했으므로 건너뜁니다.
  void _onEvent(FamilyEvent e) {
    if (!mounted) return;
    final shell = context.read<ShellCubit>();
    final persona = shell.state.persona;
    switch (e.type) {
      case 'ars_call':
        if (persona == Persona.guardian && e.requestId != null) {
          final nav = AppShell.navigatorKey.currentContext;
          if (nav != null) openArsCallSheet(nav, requestId: e.requestId!, script: e.script);
          shell.say(e.script ?? 'ARS 확인 전화가 왔어요', toast: false, vibrate: const [300, 150, 300, 150, 300]);
        } else {
          shell.say('${e.message} (보호자 화면에서 받을 수 있어요)');
        }
      case 'reset':
        if (!e.fromThisDevice) {
          shell.reset();
          shell.say(e.message);
        }
      default:
        if (e.fromThisDevice || e.message.isEmpty) return;
        const forGuardian = {'request', 'freeze', 'blocked', 'expired', 'transfer', 'payment', 'mode'};
        const forMember = {'decision', 'freeze', 'unfreeze', 'mode', 'limit', 'deposit'};
        final family = context.read<FamilyCubit>().state;
        final mine = family.isReady ? family.data.accountOf(persona)?.id : persona.memberId;
        if (persona == Persona.guardian && forGuardian.contains(e.type)) {
          shell.say(e.message, vibrate: e.type == 'freeze' ? sosVibration : const [60]);
        } else if (mine != null && mine == e.memberId && forMember.contains(e.type)) {
          shell.say(e.message, vibrate: const [60]);
        }
    }
  }

  void _closeSheets() {
    AppShell.navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ShellCubit, ShellState>(
          listenWhen: (a, b) => a.closeSheetsTick != b.closeSheetsTick,
          listener: (_, _) => _closeSheets(),
        ),
        BlocListener<ShellCubit, ShellState>(
          listenWhen: (a, b) => a.shakeTick != b.shakeTick,
          listener: (_, _) => _shake.forward(from: 0),
        ),
      ],
      child: BlocBuilder<FamilyCubit, FamilyState>(
        buildWhen: (a, b) => a.status != b.status || (a.snapshot == null) != (b.snapshot == null),
        builder: (context, state) {
          if (state.snapshot == null) {
            return state.status == FamilyStatus.error
                ? ConnectionErrorView(
                    message: state.failure?.message ?? '',
                    serverAddress: widget.serverAddress,
                    onRetry: context.read<FamilyCubit>().load,
                  )
                : const LoadingView();
          }
          final isWeb = FbLayout.isWebOf(context);
          // 토스트·흔들기 막대처럼 레이아웃 바깥에 뜨는 글자도 테마 글꼴을 쓰도록 Material로 감쌉니다.
          return Material(
            type: MaterialType.transparency,
            child: ShakeWatcher(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeOffset(_shake.value), 0),
                        child: Transform.rotate(angle: _shakeOffset(_shake.value) / 400, child: child),
                      ),
                      child: isWeb
                          ? WebLayout(serverAddress: widget.serverAddress)
                          : MobileLayout(serverAddress: widget.serverAddress),
                    ),
                  ),
                  const Positioned.fill(child: SosLayer()),
                  Positioned.fill(child: ToastHost(key: _toast, top: isWeb ? 84 : 64, centered: isWeb)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 시안의 shake 키프레임 (0.45초 × 2회)을 흉내낸 좌우 흔들림.
  static double _shakeOffset(double t) {
    if (t == 0 || t == 1) return 0;
    final damp = 1 - t * .5;
    return math.sin(t * math.pi * 8) * 10 * damp;
  }
}

/// SOS 동결 완료 화면 (ShellState.sosMemberId가 있을 때).
class SosLayer extends StatelessWidget {
  const SosLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final memberId = context.select((ShellCubit s) => s.state.sosMemberId);
    if (memberId == null) return const SizedBox.shrink();
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        final m = state.snapshot?.memberOrNull(memberId);
        if (m == null) return const SizedBox.shrink();
        final shell = context.read<ShellCubit>();
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, _) => shell.closeSos(),
          child: SosOverlay(
            member: m,
            guardianName: state.data.guardian.name,
            now: context.read<FamilyCubit>().now,
            onCallGuardian: () => shell.say('(시연) 보호자 ${state.data.guardian.name}님께 전화를 연결해요'),
            onClose: shell.closeSos,
          ),
        );
      },
    );
  }
}
