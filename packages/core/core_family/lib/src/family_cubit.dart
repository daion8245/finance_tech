import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_errors/core_errors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'family_repository.dart';
import 'models.dart';
import 'results.dart';

enum FamilyStatus { loading, ready, error }

class FamilyState {
  final FamilyStatus status;
  final FamilySnapshot? snapshot;
  final Failure? failure;

  /// 실시간(WebSocket) 연결 여부. 끊겨 있으면 주기적으로 다시 불러옵니다.
  final bool live;

  /// 마지막 불러오기가 성공했는지.
  final bool reachable;

  /// 서버 시각 - 기기 시각. 동결·승인 남은 시간을 서버 기준으로 셉니다.
  final Duration skew;

  const FamilyState({
    this.status = FamilyStatus.loading,
    this.snapshot,
    this.failure,
    this.live = false,
    this.reachable = true,
    this.skew = Duration.zero,
  });

  FamilySnapshot get data => snapshot!;
  bool get isReady => status == FamilyStatus.ready && snapshot != null;

  FamilyState copyWith({
    FamilyStatus? status,
    FamilySnapshot? snapshot,
    Failure? failure,
    bool clearFailure = false,
    bool? live,
    bool? reachable,
    Duration? skew,
  }) => FamilyState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    failure: clearFailure ? null : (failure ?? this.failure),
    live: live ?? this.live,
    reachable: reachable ?? this.reachable,
    skew: skew ?? this.skew,
  );
}

/// 가족 전체 상태. 서버가 기준이고, 바뀔 때마다(실시간 이벤트·요청 후) 다시 불러옵니다.
class FamilyCubit extends Cubit<FamilyState> {
  final FamilyRepository _repo;

  /// 실시간 연결이 끊겼을 때 다시 불러오는 간격. null이면 주기적으로 불러오지 않습니다 (테스트용).
  final Duration? pollInterval;

  final _events = StreamController<FamilyEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _poll;
  Future<void>? _refreshing;
  bool _refreshAgain = false;

  FamilyCubit(this._repo, {this.pollInterval = const Duration(seconds: 3)}) : super(const FamilyState());

  /// 서버에서 일어난 일 (다른 기기에서 생긴 일 포함). 토스트·ARS 화면 같은 일회성 반응에 씁니다.
  Stream<FamilyEvent> get events => _events.stream;

  /// 서버 기준 현재 시각.
  DateTime now() => DateTime.now().add(state.skew);

  Future<void> start() async {
    _subs
      ..add(_repo.events.listen(_onEvent))
      ..add(_repo.connection.listen((live) {
        if (isClosed) return;
        emit(state.copyWith(live: live));
        if (live) refresh(); // 끊긴 사이에 놓친 변경을 따라잡습니다
      }));
    _repo.connect();
    final every = pollInterval;
    if (every != null) {
      _poll = Timer.periodic(every, (_) {
        if (!state.live && state.status != FamilyStatus.loading) refresh();
      });
    }
    await load();
  }

  Future<void> load() async {
    emit(state.copyWith(status: FamilyStatus.loading, clearFailure: true));
    try {
      _apply(await _repo.fetchState());
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(status: FamilyStatus.error, failure: e.failure, reachable: false));
    }
  }

  /// 겹쳐 들어온 새로고침은 하나로 합칩니다.
  Future<void> refresh() {
    if (_refreshing != null) {
      _refreshAgain = true;
      return _refreshing!;
    }
    return _refreshing = _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    do {
      _refreshAgain = false;
      try {
        _apply(await _repo.fetchState());
      } on ApiException catch (e) {
        if (isClosed) return;
        if (state.snapshot == null) {
          emit(state.copyWith(status: FamilyStatus.error, failure: e.failure, reachable: false));
        } else {
          emit(state.copyWith(reachable: false));
        }
        return;
      }
    } while (_refreshAgain && !isClosed);
  }

  void _apply(FamilySnapshot snapshot) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: FamilyStatus.ready,
        snapshot: snapshot,
        clearFailure: true,
        reachable: true,
        skew: snapshot.serverTime.difference(DateTime.now()),
      ),
    );
  }

  Future<void> _onEvent(FamilyEvent event) async {
    await refresh();
    if (!_events.isClosed) _events.add(event);
  }

  Future<T> _act<T>(Future<T> Function() action) async {
    final result = await action();
    await refresh();
    return result;
  }

  // ---------------------------------------------------------------- SOS
  Future<FreezeResult> freeze(String memberId, SosTrigger trigger, {double? intensity}) =>
      _act(() => _repo.freeze(memberId, trigger, intensity: intensity));

  Future<void> requestUnfreeze(String memberId) => _act(() => _repo.requestUnfreeze(memberId));

  Future<void> unfreeze(String memberId) => _act(() => _repo.unfreeze(memberId, state.data.guardian.id));

  // ---------------------------------------------------------------- 송금 · 결제
  Future<TransferPreview> assessTransfer(String memberId, TransferDraft draft) => _repo.assessTransfer(memberId, draft);

  Future<TransferResult> submitTransfer(String memberId, TransferDraft draft) =>
      _act(() => _repo.submitTransfer(memberId, draft));

  Future<PaymentResult> pay(String memberId, String merchantId) => _act(() => _repo.pay(memberId, merchantId));

  Future<PaymentResult> requestPayment(String memberId, String merchantId) =>
      _act(() => _repo.requestPayment(memberId, merchantId));

  // ---------------------------------------------------------------- 모드 · 한도
  Future<ModeChangeResult> setMode(String memberId, String modeId, {required bool byGuardian}) =>
      _act(() => _repo.setMode(memberId, modeId, byGuardian: byGuardian));

  Future<void> setDailyLimit(String memberId, int value) => _act(() => _repo.setDailyLimit(memberId, value));

  Future<void> setSleepGuard(String memberId, bool enabled) => _act(() => _repo.setSleepGuard(memberId, enabled));

  // ---------------------------------------------------------------- 보호자
  Future<DecisionResult> decide(String requestId, {required bool approve}) =>
      _act(() => _repo.decide(requestId, state.data.guardian.id, approve: approve));

  Future<void> acknowledge(List<String> requestIds) async {
    if (requestIds.isEmpty || !state.isReady) return;
    await _repo.acknowledge(state.data.guardian.id, requestIds);
  }

  Future<DecisionResult> answerArs(String requestId, String digit) => _act(() => _repo.answerArs(requestId, digit));

  Future<void> dismissNotice(String memberId, String noticeId) => _act(() => _repo.dismissNotice(memberId, noticeId));

  // ---------------------------------------------------------------- 기타
  Future<List<IntegrationLogEntry>> integrationLogs({int limit = 30}) => _repo.integrationLogs(limit: limit);

  Future<void> resetDemo() => _act(_repo.resetDemo);

  @override
  Future<void> close() async {
    _poll?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _events.close();
    return super.close();
  }
}
