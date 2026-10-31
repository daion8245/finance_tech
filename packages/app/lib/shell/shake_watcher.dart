import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 흔들기 감지를 지원하는 기기인지 (휴대폰 앱 또는 휴대폰 브라우저).
bool get motionSupported =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// 어르신·아이 화면에서 "흔들어서 SOS"가 켜져 있으면 가속도 센서를 듣고,
/// 흔드는 동안 진행 막대를 보여 줍니다.
class ShakeWatcher extends StatefulWidget {
  final Widget child;
  final ShakeDetector Function({required void Function(double) onShake, void Function(double)? onProgress})? detectorFactory;

  const ShakeWatcher({super.key, required this.child, this.detectorFactory});

  @override
  State<ShakeWatcher> createState() => _ShakeWatcherState();
}

class _ShakeWatcherState extends State<ShakeWatcher> {
  late final ShakeDetector _detector;
  double _progress = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final make = widget.detectorFactory ??
        ({required void Function(double) onShake, void Function(double)? onProgress}) =>
            ShakeDetector(onShake: onShake, onProgress: onProgress);
    _detector = make(onShake: _onShake, onProgress: _onProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _disposed = true;
    _detector.stop();
    super.dispose();
  }

  String? get _target {
    final shell = context.read<ShellCubit>().state;
    final family = context.read<FamilyCubit>().state;
    final id = shell.memberId;
    if (id == null || !shell.prefs.shake || !family.isReady) return null;
    final m = family.data.memberOrNull(id);
    if (m == null || m.isFrozen) return null;
    return id;
  }

  void _sync() {
    if (!mounted) return;
    if (_target != null && motionSupported) {
      _detector.start();
    } else if (_detector.active) {
      _detector.stop();
    }
  }

  void _onProgress(double p) {
    if (_disposed || !mounted) return;
    if ((p - _progress).abs() > .04 || p == 0) setState(() => _progress = p);
  }

  void _onShake(double peakG) {
    final id = _target;
    if (id == null) return;
    setState(() => _progress = 0);
    triggerSos(context, id, SosTrigger.shake, intensity: peakG);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ShellCubit, ShellState>(listener: (_, _) => _sync()),
        BlocListener<FamilyCubit, FamilyState>(listener: (_, _) => _sync()),
      ],
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_progress > .12) Positioned(left: 20, right: 20, bottom: 110, child: _ShakeMeter(progress: _progress)),
        ],
      ),
    );
  }
}

class _ShakeMeter extends StatelessWidget {
  final double progress;
  const _ShakeMeter({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      liveRegion: true,
      label: '흔들기 감지 중',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(FbIcons.shake, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('계속 흔들면 모든 계좌가 동결돼요', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              FbRail(fraction: progress, color: Colors.white, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
