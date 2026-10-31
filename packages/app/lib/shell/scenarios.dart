import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell.dart';

/// 발표용 바로 시연 시나리오 (시안의 "바로 시연해 보기").
enum Scenario {
  shake('흔들어서 SOS 동결'),
  phishing('낯선 계좌로 50만원 송금'),
  game('등교 모드에서 게임 결제');

  final String label;
  const Scenario(this.label);
}

const phishingAccount = NewAccount(bank: '국민', number: '12345678907788', name: '이정민');

Future<void> runScenario(BuildContext context, Scenario s) async {
  final shell = context.read<ShellCubit>();
  final family = context.read<FamilyCubit>();
  // 시트는 Navigator 아래의 context로 엽니다.
  BuildContext nav() => AppShell.navigatorKey.currentContext ?? context;

  try {
    switch (s) {
      case Scenario.shake:
        shell.goto(Persona.senior, AppTab.home);
        if (family.state.data.member('senior').isFrozen) {
          shell.say('이미 동결되어 있어요 · 설정에서 처음 상태로 되돌려 보세요');
          return;
        }
        shell.playShake();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final ctx = nav();
        if (ctx.mounted) await triggerSos(ctx, 'senior', SosTrigger.shake, intensity: 2.8);
      case Scenario.phishing:
        shell.goto(Persona.senior, AppTab.home);
        const draft = TransferDraft(newAccount: phishingAccount, amount: 500000);
        final preview = await family.assessTransfer('senior', draft);
        final ctx = nav();
        if (ctx.mounted) await openTransferSheet(ctx, 'senior', draft: draft, preview: preview);
      case Scenario.game:
        shell.goto(Persona.child, AppTab.home);
        if (family.state.data.member('child').mode != 'school') {
          await family.setMode('child', 'school', byGuardian: true);
        }
        final result = await family.pay('child', 'c-game');
        final ctx = nav();
        if (ctx.mounted) await openPaySheet(ctx, 'child', result: result);
    }
  } on ApiException catch (e) {
    shell.say(e.message);
  }
}
