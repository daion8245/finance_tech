import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the demo snapshot', () {
    final s = FamilySnapshot.fromJson(demoSnapshotJson(requests: [pendingTransferJson()]));
    final senior = s.member('senior');
    expect(senior.label, '어머니 김순자');
    expect(senior.accounts, hasLength(2));
    expect(s.member('child').callName, '민준');
    expect(s.pending('senior').single.risk!.level, RiskLevel.high);
    expect(s.mode('school').restricted, isTrue);
    expect(s.member('child').merchant('c-game')!.check.code, 'mode');
  });

  test('loads, then refreshes when a server event arrives', () async {
    final repo = FakeFamilyRepository();
    final cubit = FamilyCubit(repo);
    await cubit.start();
    expect(cubit.state.isReady, isTrue);
    expect(cubit.state.live, isTrue);

    final calls = repo.calls.length;
    repo.snapshotJson = demoSnapshotJson(seniorFrozen: true);
    final next = cubit.events.first;
    repo.emitEvent(const FamilyEvent(type: 'freeze', memberId: 'senior'));
    final event = await next;
    expect(event.type, 'freeze');
    expect(repo.calls.length, greaterThan(calls));
    expect(cubit.state.data.member('senior').isFrozen, isTrue);
    await cubit.close();
  });

  test('actions refresh the state afterwards', () async {
    final repo = FakeFamilyRepository();
    final cubit = FamilyCubit(repo);
    await cubit.start();
    repo.calls.clear();
    await cubit.freeze('senior', SosTrigger.longPress);
    expect(repo.calls, ['freeze:senior:LONG_PRESS', 'fetchState']);
    await cubit.close();
  });

  test('keeps the last snapshot when the server goes away', () async {
    final repo = FakeFamilyRepository();
    final cubit = FamilyCubit(repo);
    await cubit.start();
    repo.failNetwork = true;
    await cubit.refresh();
    expect(cubit.state.isReady, isTrue);
    expect(cubit.state.reachable, isFalse);
    await cubit.close();
  });

  test('first load failure shows the error state', () async {
    final repo = FakeFamilyRepository()..failNetwork = true;
    final cubit = FamilyCubit(repo);
    await cubit.start();
    expect(cubit.state.status, FamilyStatus.error);
    expect(cubit.state.failure!.code, 'network');
    await cubit.close();
  });
}
