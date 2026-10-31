import 'dart:async';

import 'package:core_family/core_family.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_prefs.dart';

/// 화면 탭. [alerts](가족 알림)는 보호자에게만 있습니다.
enum AppTab {
  home,
  history,
  alerts,
  safety,
  settings;

  /// 이 사용자에게 없는 탭이면 가장 가까운 탭으로 바꿉니다 (가족 알림 → 내역).
  AppTab availableFor(Persona p) => this == alerts && p != Persona.guardian ? history : this;
}

/// 토스트·진동·음성 안내 요청. 실제 출력은 앱 셸이 설정(AppPrefs)에 맞춰 합니다.
class FeedbackRequest {
  final String message;
  final bool toast;

  /// 진동 패턴 (ms, 진동/쉼 반복). 비어 있으면 진동하지 않습니다.
  final List<int> vibrate;
  final bool speak;

  const FeedbackRequest(this.message, {this.toast = true, this.vibrate = const [40], this.speak = true});
}

class ShellState {
  final Persona persona;
  final AppTab tab;
  final String txFilter; // all / in / out
  final String alertFilter; // all / pending
  final AppPrefs prefs;

  /// SOS 동결 완료 화면을 띄운 사용자.
  final String? sosMemberId;

  /// 늘어날 때마다 화면 흔들림 애니메이션을 한 번 재생합니다 (시연용).
  final int shakeTick;

  /// 늘어날 때마다 열려 있는 시트를 닫습니다.
  final int closeSheetsTick;

  const ShellState({
    this.persona = Persona.senior,
    this.tab = AppTab.home,
    this.txFilter = 'all',
    this.alertFilter = 'all',
    this.prefs = const AppPrefs(),
    this.sosMemberId,
    this.shakeTick = 0,
    this.closeSheetsTick = 0,
  });

  bool get isGuardian => persona == Persona.guardian;
  String? get memberId => persona.memberId;

  ShellState copyWith({
    Persona? persona,
    AppTab? tab,
    String? txFilter,
    String? alertFilter,
    AppPrefs? prefs,
    String? sosMemberId,
    bool clearSos = false,
    int? shakeTick,
    int? closeSheetsTick,
  }) => ShellState(
    persona: persona ?? this.persona,
    tab: tab ?? this.tab,
    txFilter: txFilter ?? this.txFilter,
    alertFilter: alertFilter ?? this.alertFilter,
    prefs: prefs ?? this.prefs,
    sosMemberId: clearSos ? null : (sosMemberId ?? this.sosMemberId),
    shakeTick: shakeTick ?? this.shakeTick,
    closeSheetsTick: closeSheetsTick ?? this.closeSheetsTick,
  );
}

class ShellCubit extends Cubit<ShellState> {
  final _feedback = StreamController<FeedbackRequest>.broadcast();

  ShellCubit([super.initial = const ShellState()]);

  Stream<FeedbackRequest> get feedback => _feedback.stream;

  void switchTab(AppTab tab) => emit(state.copyWith(tab: tab));

  /// 사용자를 바꿉니다 (시연용 역할 전환). 열린 시트와 SOS 화면은 닫습니다.
  void goto(Persona persona, [AppTab? tab]) => emit(
    ShellState(
      persona: persona,
      tab: (tab ?? state.tab).availableFor(persona),
      prefs: state.prefs,
      shakeTick: state.shakeTick,
      closeSheetsTick: state.closeSheetsTick + 1,
    ),
  );

  void setTxFilter(String filter) => emit(state.copyWith(txFilter: filter));
  void setAlertFilter(String filter) => emit(state.copyWith(alertFilter: filter));

  void setPref(PrefKey key, bool value) => emit(state.copyWith(prefs: state.prefs.set(key, value)));
  void togglePref(PrefKey key) => setPref(key, !state.prefs[key]);

  void showSos(String memberId) => emit(state.copyWith(sosMemberId: memberId, closeSheetsTick: state.closeSheetsTick + 1));
  void closeSos() => emit(state.copyWith(clearSos: true));

  void closeSheets() => emit(state.copyWith(closeSheetsTick: state.closeSheetsTick + 1));

  void playShake() => emit(state.copyWith(shakeTick: state.shakeTick + 1));

  void say(String message, {bool toast = true, List<int> vibrate = const [40], bool speak = true}) {
    if (!_feedback.isClosed) _feedback.add(FeedbackRequest(message, toast: toast, vibrate: vibrate, speak: speak));
  }

  /// 처음 상태(어르신 홈, 기본 설정)로 돌아갑니다.
  void reset() => emit(ShellState(shakeTick: state.shakeTick, closeSheetsTick: state.closeSheetsTick + 1));

  @override
  Future<void> close() async {
    await _feedback.close();
    return super.close();
  }
}
