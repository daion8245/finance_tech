import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_guardian/feature_guardian.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, FamilyCubit)> pump(WidgetTester tester, Widget Function(FamilySnapshot) view,
    {Map<String, dynamic>? snapshot, bool web = false}) async {
  tester.view.physicalSize = web ? const Size(1400, 900) : const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider(create: (_) => ShellCubit())],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: FbLayout(
            isWeb: web,
            child: SingleChildScrollView(
              child: BlocBuilder<FamilyCubit, FamilyState>(builder: (_, s) => view(s.data)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (repo, family);
}

void main() {
  testWidgets('home shows the pending request with the AI risk reasons and acknowledges it', (tester) async {
    final (repo, _) = await pump(
      tester,
      (d) => GuardianHomeView(data: d),
      snapshot: demoSnapshotJson(requests: [pendingTransferJson()]),
    );
    expect(find.text('확인할 요청이 1건 있어요'), findsOneWidget);
    expect(find.text('500,000원'), findsOneWidget);
    expect(find.text('AI 위험도 79점 · 위험'), findsOneWidget);
    expect(find.text('처음 보내는 계좌예요'), findsOneWidget);
    await tester.pump();
    expect(repo.calls, contains('ack:req-1'));

    await tester.tap(find.text('거절'));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, contains('decide:req-1:reject'));
  });

  testWidgets('home says everyone is safe without requests', (tester) async {
    await pump(tester, (d) => GuardianHomeView(data: d));
    expect(find.text('가족 모두 안전해요'), findsOneWidget);
    expect(find.text('어머니 김순자'), findsOneWidget);
  });

  testWidgets('manage view unfreezes and changes modes', (tester) async {
    final (repo, _) = await pump(tester, (d) => GuardianManageView(data: d), snapshot: demoSnapshotJson(seniorFrozen: true));
    expect(find.text('출금 동결 중'), findsOneWidget);
    await tester.tap(find.text('지금 동결 해제'));
    await tester.pump();
    expect(repo.calls, contains('unfreeze:senior'));

    await tester.tap(find.text('일반').last);
    await tester.pump();
    expect(repo.calls, contains('mode:child:normal:guardian'));
  });

  testWidgets('manage view works in the two column web layout', (tester) async {
    await pump(tester, (d) => GuardianManageView(data: d), web: true);
    expect(find.byType(ManageCard), findsNWidgets(2));
    expect(find.text('원격으로 출금 동결'), findsNWidgets(2));
  });
}
