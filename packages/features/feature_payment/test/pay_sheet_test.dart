import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FakeFamilyRepository> pumpSheet(WidgetTester tester, {String memberId = 'child'}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository();
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider(create: (_) => ShellCubit())],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(body: SingleChildScrollView(child: PaySheet(memberId: memberId))),
      ),
    ),
  );
  await tester.pump();
  return repo;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('lists merchants with the mode verdict', (tester) async {
    await pumpSheet(tester);
    expect(find.text('등교 모드 · 교통·문구점·편의점·서점·식당만 결제돼요'), findsOneWidget);
    expect(find.text('결제 가능'), findsOneWidget);
    expect(find.text('사용 불가'), findsOneWidget);
  });

  testWidgets('blocked game payment can be sent to the guardian', (tester) async {
    final repo = await pumpSheet(tester);
    await tester.tap(find.text('게임 아이템 상점'));
    await settle(tester);
    expect(repo.calls, contains('pay:child:c-game'));
    expect(find.text('지금 모드에서는 결제할 수 없어요'), findsOneWidget);

    await tester.tap(find.text('보호자에게 요청하기'));
    await settle(tester);
    expect(repo.calls, contains('requestPayment:child:c-game'));
    expect(find.text('보호자 확인을 기다려요'), findsOneWidget);
  });

  testWidgets('allowed payment completes', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('버스·지하철'));
    await settle(tester);
    expect(find.text('1,450원 결제했어요'), findsOneWidget);
  });

  testWidgets('guardian pays from their own account', (tester) async {
    final repo = await pumpSheet(tester, memberId: 'guardian');
    expect(find.text('핑거벨 주거래 통장 · 잔액 3,480,000원'), findsOneWidget);
    await tester.tap(find.text('행복마트'));
    await settle(tester);
    expect(repo.calls, contains('pay:guardian:g-mart'));
    expect(find.text('52,300원 결제했어요'), findsOneWidget);
  });
}
