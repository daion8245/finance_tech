import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, ShellCubit)> pumpApp(WidgetTester tester, {required Size size, Map<String, dynamic>? snapshot}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit();
  await tester.pumpWidget(
    FingerBellApp(family: family, shell: shell, feedback: const SilentFeedback(), serverAddress: 'http://127.0.0.1:8765'),
  );
  await settle(tester);
  return (repo, shell);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('mobile layout shows the senior home with bottom navigation', (tester) async {
    await pumpApp(tester, size: const Size(400, 860));
    expect(find.text('안녕하세요, 김순자님'), findsOneWidget);
    expect(find.text('2,350,000원'), findsOneWidget);
    expect(find.text('계좌 동결'), findsOneWidget);
    expect(find.text('안심'), findsOneWidget); // 하단 메뉴
    // 어르신도 송금·결제·조회를 모두 씁니다
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('조회'), findsOneWidget);
    expect(find.text('바로 시연해 보기'), findsNothing); // 웹 사이드바 전용
  });

  testWidgets('web layout has the sidebar, scenarios and two columns', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900));
    expect(find.text('시연 사용자'), findsOneWidget);
    expect(find.text('바로 시연해 보기'), findsOneWidget);
    expect(find.text('낯선 계좌로 50만원 송금'), findsOneWidget);
    expect(find.text('보호자'), findsWidgets); // 보호자 카드는 웹 2단에서만 홈에 보임
    final account = tester.getTopLeft(find.text('핑거벨 입출금 통장'));
    final sos = tester.getTopLeft(find.text('계좌 동결'));
    expect(sos.dx, greaterThan(account.dx));
  });

  testWidgets('switching to the guardian shows the approval request', (tester) async {
    final (_, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(requests: [pendingTransferJson()]),
    );
    expect(find.textContaining('보호자 확인 대기 중', findRichText: true), findsOneWidget); // 어르신 화면 배너
    await tester.tap(find.text('보호자').first);
    await settle(tester);
    expect(shell.state.persona, Persona.guardian);
    expect(find.text('확인할 요청이 1건 있어요'), findsOneWidget);
    expect(find.text('AI 위험도 79점 · 위험'), findsOneWidget);
  });

  testWidgets('guardian banks from their own account like everyone else', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.goto(Persona.guardian, AppTab.home);
    await settle(tester);
    expect(find.text('핑거벨 주거래 통장'), findsOneWidget);
    expect(find.text('3,480,000원'), findsOneWidget);
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('가족 모두 안전해요'), findsOneWidget); // 가족 보호 기능은 그대로
    expect(find.text('알림'), findsOneWidget); // 하단 메뉴: 홈 · 내역 · 알림 · 관리 · 설정

    shell.switchTab(AppTab.history);
    await settle(tester);
    expect(find.text('거래 내역'), findsOneWidget);
    expect(find.text('김순자님께 송금'), findsOneWidget);

    shell.switchTab(AppTab.alerts);
    await settle(tester);
    expect(find.text('가족 알림'), findsOneWidget);
  });

  testWidgets('child home shows the school mode and spending rail', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.goto(Persona.child, AppTab.home);
    await settle(tester);
    expect(find.text('안녕, 민준!'), findsOneWidget);
    expect(find.text('등교 모드'), findsOneWidget);
    expect(find.text('8,500 / 20,000원'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('보내기'), findsOneWidget);
  });

  testWidgets('frozen senior sees the frozen card instead of the SOS button', (tester) async {
    await pumpApp(tester, size: const Size(400, 860), snapshot: demoSnapshotJson(seniorFrozen: true));
    expect(find.text('모든 계좌 출금이 멈춰 있어요'), findsOneWidget);
    expect(find.text('보호자에게 해제 요청'), findsOneWidget);
  });

  testWidgets('settings toggles high contrast and large text', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.switchTab(AppTab.settings);
    await settle(tester);
    expect(find.text('고대비 모드'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is FbToggle && w.label == '고대비 모드'));
    await settle(tester);
    expect(shell.state.prefs.highContrast, isTrue);
    expect(find.text('바로 시연해 보기'), findsOneWidget); // 모바일은 설정에 시나리오가 있음
  });

  testWidgets('connection error screen offers a retry', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFamilyRepository()..failNetwork = true;
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    await tester.pumpWidget(
      FingerBellApp(family: family, shell: ShellCubit(), feedback: const SilentFeedback(), serverAddress: 'http://10.0.0.9:8000'),
    );
    await settle(tester);
    expect(find.text('서버에 연결할 수 없어요'), findsOneWidget);
    expect(find.text('http://10.0.0.9:8000'), findsOneWidget);
    repo.failNetwork = false;
    await tester.tap(find.text('다시 시도'));
    await settle(tester);
    expect(find.text('안녕하세요, 김순자님'), findsOneWidget);
  });
}
