import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goto keeps prefs, resets filters and closes sheets', () {
    final shell = ShellCubit()
      ..togglePref(PrefKey.largeText)
      ..setTxFilter('in')
      ..showSos('senior');
    final before = shell.state.closeSheetsTick;
    shell.goto(Persona.guardian, AppTab.history);
    expect(shell.state.persona, Persona.guardian);
    expect(shell.state.tab, AppTab.history);
    expect(shell.state.txFilter, 'all');
    expect(shell.state.sosMemberId, isNull);
    expect(shell.state.prefs.largeText, isTrue);
    expect(shell.state.closeSheetsTick, before + 1);
  });

  test('feedback requests are streamed', () async {
    final shell = ShellCubit();
    final next = shell.feedback.first;
    shell.say('보호자에게 알렸어요', vibrate: const [200, 100, 200]);
    final f = await next;
    expect(f.message, '보호자에게 알렸어요');
    expect(f.vibrate, [200, 100, 200]);
    await shell.close();
  });

  test('reset goes back to the senior home with default prefs', () {
    final shell = ShellCubit()
      ..goto(Persona.child, AppTab.settings)
      ..togglePref(PrefKey.highContrast)
      ..reset();
    expect(shell.state.persona, Persona.senior);
    expect(shell.state.tab, AppTab.home);
    expect(shell.state.prefs.highContrast, isFalse);
  });

  test('switching away from the guardian moves the alerts tab to history', () {
    final shell = ShellCubit()..goto(Persona.guardian, AppTab.alerts);
    expect(shell.state.tab, AppTab.alerts);
    shell.goto(Persona.senior);
    expect(shell.state.tab, AppTab.history);
  });
}
