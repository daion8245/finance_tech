import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, ShellCubit)> pumpSheet(WidgetTester tester, {String memberId = 'senior'}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository();
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit();
  addTearDown(family.close);
  addTearDown(shell.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(body: SingleChildScrollView(child: TransferSheet(memberId: memberId))),
      ),
    ),
  );
  await tester.pump();
  return (repo, shell);
}

/// 반복 애니메이션(커서 깜빡임, 전화 울림) 때문에 pumpAndSettle 대신 몇 프레임만 진행합니다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('safe transfer to a contact goes straight through', (tester) async {
    final (repo, _) = await pumpSheet(tester);
    expect(find.text('누구에게 보낼까요?'), findsOneWidget);
    await tester.tap(find.textContaining('김사랑', findRichText: true).first);
    await settle(tester);
    expect(find.text('얼마를 보낼까요?'), findsOneWidget);

    await tester.tap(find.text('+5만'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(repo.calls, contains('assess:senior:50000'));
    expect(find.text('안전한 거래로 보여요'), findsOneWidget);

    await tester.tap(find.text('보내기'));
    await settle(tester);
    expect(repo.calls, contains('transfer:senior:50000'));
    expect(find.text('김사랑님께 50,000원을 보냈어요'), findsOneWidget);
  });

  testWidgets('new account shows the high risk check and waits for the guardian', (tester) async {
    final (repo, _) = await pumpSheet(tester);
    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '500000');
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(find.text('사기 위험이 높은 거래예요'), findsOneWidget);
    expect(find.text('처음 보내는 계좌예요'), findsOneWidget);

    repo.snapshotJson = demoSnapshotJson(requests: [pendingTransferJson()]);
    await tester.tap(find.text('보호자에게 확인 요청'));
    await settle(tester);
    expect(find.text('보호자 확인을 기다리고 있어요'), findsOneWidget);
  });

  testWidgets('guardian sends from their own account without waiting for approval', (tester) async {
    final (repo, _) = await pumpSheet(tester, memberId: 'guardian');
    expect(find.text('핑거벨 주거래 통장 · 잔액 3,480,000원'), findsOneWidget);
    expect(find.textContaining('이민준', findRichText: true), findsOneWidget);

    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '500000');
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 위험도는 똑같이 보여 주고, 보호자 요청 대신 본인이 확인하고 보냅니다
    expect(find.text('사기 위험이 높은 거래예요'), findsOneWidget);
    expect(find.text('보호자에게 확인 요청'), findsNothing);
    await tester.tap(find.text('확인했어요, 보내기'));
    await settle(tester);
    expect(repo.calls, contains('transfer:guardian:500000'));
    expect(find.text('이정민님께 500,000원을 보냈어요'), findsOneWidget);
  });

  testWidgets('rejects an empty account number', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('계좌번호는 숫자 10~14자리로 입력해 주세요.'), findsOneWidget);
  });
}
