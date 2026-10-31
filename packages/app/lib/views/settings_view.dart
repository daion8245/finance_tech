import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../shell/scenarios.dart';
import '../shell/shake_watcher.dart';

/// 설정: 큰 글씨·고대비·음성 안내·흔들기 SOS·잔액 숨기기, 서버 연결과 연동 기록.
class SettingsView extends StatefulWidget {
  final String serverAddress;
  const SettingsView({super.key, required this.serverAddress});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  List<IntegrationLogEntry>? _logs;
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final logs = await context.read<FamilyCubit>().integrationLogs(limit: 8);
      if (mounted) setState(() => _logs = logs);
    } on ApiException {
      if (mounted) setState(() => _logs = const []);
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _reset() async {
    final shell = context.read<ShellCubit>();
    try {
      await context.read<FamilyCubit>().resetDemo();
      shell.reset();
      shell.say('처음 상태로 되돌렸어요');
    } on ApiException catch (e) {
      shell.say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.read<ShellCubit>();
    final prefs = context.select((ShellCubit s) => s.state.prefs);
    final live = context.select((FamilyCubit f) => f.state.live);
    final isWeb = FbLayout.isWebOf(context);
    final now = context.read<FamilyCubit>().now();

    FbSettingRow row(PrefKey key, String title, String hint, {bool divider = true}) => FbSettingRow(
      title: title,
      hint: hint,
      value: prefs[key],
      divider: divider,
      onChanged: (v) {
        shell.setPref(key, v);
        if (key == PrefKey.voice && v) shell.say('음성 안내를 켰어요', toast: false);
      },
    );

    return FbView(
      children: [
        const Greeting('설정'),
        FbCard(
          padding: const EdgeInsets.symmetric(horizontal: 21.6, vertical: 6.4),
          child: Column(
            children: [
              row(PrefKey.largeText, '큰 글씨', '글자와 버튼을 더 크게 보여줘요', divider: false),
              row(PrefKey.highContrast, '고대비 모드', '글자와 테두리를 더 진하게 보여줘요'),
              row(PrefKey.voice, '음성 안내', '중요한 안내를 소리로 읽어줘요'),
              row(
                PrefKey.shake,
                '흔들어서 SOS',
                motionSupported ? '휴대폰을 3초 동안 세게 흔들면 바로 동결돼요 (2.5g 이상)' : '이 기기는 흔들기 감지를 지원하지 않아요 · 휴대폰에서 써 보세요',
              ),
              row(PrefKey.hideBalance, '잔액 숨기기', '다른 사람에게 금액이 보이지 않아요'),
            ],
          ),
        ),
        if (!isWeb)
          FbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardTitle('바로 시연해 보기'),
                for (final s in Scenario.values)
                  FbListRow(
                    leading: const TxLogo(icon: FbIcons.sparkle, blue: true),
                    title: Text(s.label),
                    chevron: true,
                    onTap: () => runScenario(context, s),
                  ),
              ],
            ),
          ),
        FbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListHead('서버 연동 기록', action: _loadingLogs ? null : '새로고침', onAction: _loadLogs),
              Row(
                children: [
                  Icon(live ? FbIcons.cloud : FbIcons.cloudOff, size: 16, color: live ? c.blue : c.redStrong),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${widget.serverAddress} · ${live ? '실시간 연결됨' : '실시간 연결 끊김 (3초마다 새로고침)'}',
                      style: FbText.small(c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_logs == null)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_logs!.isEmpty)
                const EmptyText('아직 연동 기록이 없어요')
              else
                for (final l in _logs!)
                  FbListRow(
                    leading: TxLogo(text: _channelShort(l.channel), blue: l.channel == 'OPEN_BANKING'),
                    title: Text(l.message, maxLines: 2),
                    subtitle: '${_channelName(l.channel)} · ${l.action} · ${formatWhen(l.at, now)}',
                  ),
              const SizedBox(height: 4),
              Text('오픈뱅킹·FCM·SMS·ARS는 모의 연동이에요. 실제 요청은 보내지 않아요.', style: FbText.small(c)),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            FbTextButton('처음 상태로 되돌리기', onPressed: _reset),
            FbTextButton(
              '오픈소스 라이선스',
              onPressed: () => showLicensePage(context: context, applicationName: '핑거벨', applicationVersion: '1.0.0'),
            ),
          ],
        ),
        Text(
          '가상 데이터를 쓰는 경진대회 시연용 앱입니다.\n실제 은행·금융 서비스와 연결되지 않습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.7, color: c.faint),
        ),
      ],
    );
  }

  static String _channelShort(String ch) => switch (ch) {
    'OPEN_BANKING' => '은',
    'FCM' => '푸',
    'SMS' => '문',
    'ARS' => '전',
    _ => '?',
  };

  static String _channelName(String ch) => switch (ch) {
    'OPEN_BANKING' => '오픈뱅킹',
    'FCM' => '푸시',
    'SMS' => '문자',
    'ARS' => 'ARS',
    _ => ch,
  };
}
