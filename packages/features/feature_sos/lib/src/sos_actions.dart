import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 강한 진동 3회 (기획서 3.1).
const sosVibration = [400, 120, 400, 120, 400];

/// SOS 동결을 서버에 요청하고 결과 화면을 띄웁니다.
Future<void> triggerSos(BuildContext context, String memberId, SosTrigger trigger, {double? intensity}) async {
  final family = context.read<FamilyCubit>();
  final shell = context.read<ShellCubit>();
  if (family.state.isReady && family.state.data.memberOrNull(memberId)?.isFrozen == true) {
    shell.say('이미 모든 계좌가 동결되어 있어요');
    return;
  }
  try {
    final result = await family.freeze(memberId, trigger, intensity: intensity);
    if (result.alreadyFrozen) {
      shell.say('이미 모든 계좌가 동결되어 있어요');
      return;
    }
    shell.showSos(memberId);
    shell.say('모든 계좌의 출금을 막았어요. 보호자에게 알렸어요.', toast: false, vibrate: sosVibration);
  } on ApiException catch (e) {
    shell.say('동결 요청을 보내지 못했어요. ${e.message}', vibrate: const [80, 40, 80]);
  }
}

/// 동결된 사용자가 보호자에게 해제를 요청합니다.
Future<void> requestUnfreeze(BuildContext context, String memberId) async {
  final shell = context.read<ShellCubit>();
  try {
    await context.read<FamilyCubit>().requestUnfreeze(memberId);
    shell.say('보호자에게 동결 해제를 요청했어요');
  } on ApiException catch (e) {
    shell.say(e.message);
  }
}
