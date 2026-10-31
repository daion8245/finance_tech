import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shell/app_shell.dart';
import 'shell/feedback_service.dart';

/// 앱 전체. 가족 상태(FamilyCubit)와 셸 상태(ShellCubit)는 Navigator 위에 두어
/// 바텀 시트·모달에서도 읽을 수 있게 합니다.
class FingerBellApp extends StatelessWidget {
  final FamilyCubit family;
  final ShellCubit shell;
  final FeedbackOutput feedback;
  final String serverAddress;

  const FingerBellApp({
    super.key,
    required this.family,
    required this.shell,
    required this.feedback,
    required this.serverAddress,
  });

  /// 어르신 화면은 기본 글자를 한 단계 크게 (16 → 17px), 큰 글씨는 1.12배.
  static double textFactor(ShellState s) =>
      (s.persona == Persona.senior ? 17 / 16 : 1.0) * (s.prefs.largeText ? 1.12 : 1.0);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
      child: RepositoryProvider<FeedbackOutput>.value(
        value: feedback,
        child: BlocBuilder<ShellCubit, ShellState>(
          buildWhen: (a, b) => a.prefs != b.prefs || a.persona != b.persona,
          builder: (context, s) => MaterialApp(
            title: '핑거벨',
            debugShowCheckedModeBanner: false,
            theme: FbTheme.build(highContrast: s.prefs.highContrast),
            locale: const Locale('ko', 'KR'),
            supportedLocales: const [Locale('ko', 'KR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            navigatorKey: AppShell.navigatorKey,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final scale = mq.textScaler.scale(1) * textFactor(s);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                child: FbLayout(isWeb: mq.size.width >= webBreakpoint, child: child ?? const SizedBox.shrink()),
              );
            },
            home: AppShell(serverAddress: serverAddress),
          ),
        ),
      ),
    );
  }
}
