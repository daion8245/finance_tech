import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 내 계좌: 잔액과 [송금] [결제] [조회]. 어르신·아이·보호자 모두 같은 은행 기능을 씁니다.
/// 아이는 결제를 앞에 두고, [extra](오늘 쓴 돈 등)를 잔액 아래에 붙입니다.
class AccountCard extends StatelessWidget {
  final Member member;
  final String? title;
  final Widget? extra;

  const AccountCard({super.key, required this.member, this.title, this.extra});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = member;
    void send() => openTransferSheet(context, m.id);
    void pay() => openPaySheet(context, m.id);
    void history() => context.read<ShellCubit>().switchTab(AppTab.history);
    final buttons = m.isChild
        ? [FbButton('결제', onPressed: pay), FbButton.gray('보내기', onPressed: send), FbButton.gray('내역', onPressed: history)]
        : [
            FbButton('송금', onPressed: send),
            FbButton.gray('결제', onPressed: pay),
            FbButton.gray(m.isGuardian ? '내역' : '조회', onPressed: history),
          ];
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? m.account.name, style: FbText.label(c)),
          BalanceLine(m.balance),
          ?extra,
          FbButtonRow(children: buttons),
        ],
      ),
    );
  }
}

/// 거래 내역 한 줄. 보호 조치(동결·차단·거절)는 방패 아이콘과 태그로 보여 줍니다.
class LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final DateTime now;

  const LedgerRow({super.key, required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final t = entry;
    if (t.isProtect) {
      return FbListRow(
        leading: TxLogo(icon: t.tag == '해제' ? FbIcons.unlock : FbIcons.shield),
        title: Text(t.title),
        subtitle: '${formatWhen(t.at, now)} · ${t.desc}',
        trailing: Text(t.tag ?? '보호', style: FbText.note(c).copyWith(color: t.isDanger ? c.redStrong : c.muted)),
      );
    }
    final incoming = t.amount > 0;
    return FbListRow(
      leading: TxLogo.initial(t.title),
      title: Text(t.title),
      subtitle: formatWhen(t.at, now),
      trailing: Text(
        '${incoming ? '+' : '-'}${won(t.amount.abs())}',
        style: FbText.amount(c).copyWith(color: incoming ? c.blue : c.ink),
      ),
    );
  }
}

/// 잔액 + 눈 모양 버튼 (잔액 숨기기).
class BalanceLine extends StatelessWidget {
  final int balance;
  const BalanceLine(this.balance, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 7.2, 0, 20),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              label: hidden ? '잔액 숨김' : '잔액 ${won(balance)}',
              excludeSemantics: true,
              child: Text(wonOrHidden(balance, hidden: hidden), style: FbText.balance(c)),
            ),
          ),
          IconButton(
            tooltip: hidden ? '잔액 보기' : '잔액 숨기기',
            onPressed: () => context.read<ShellCubit>().togglePref(PrefKey.hideBalance),
            icon: Icon(hidden ? FbIcons.eyeOff : FbIcons.eye, color: c.faint, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 최근 거래 3건.
class RecentCard extends StatelessWidget {
  final Member member;
  const RecentCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final now = context.read<FamilyCubit>().now();
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHead('최근 거래', action: '전체보기', onAction: () => context.read<ShellCubit>().switchTab(AppTab.history)),
          for (final t in member.ledger.take(3)) LedgerRow(entry: t, now: now),
          if (member.ledger.isEmpty) const EmptyText('아직 거래가 없어요'),
        ],
      ),
    );
  }
}

/// 보호자 카드: 누가 확인하는지와 전화 버튼.
class GuardianCard extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const GuardianCard({super.key, required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final g = data.guardian;
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('보호자'),
          FbListRow(
            padding: const EdgeInsets.only(top: 8),
            leading: TxLogo.initial(g.name, blue: true),
            title: Text('${g.name} (${member.guardianRelation})'),
            subtitle: '처음 보내는 계좌나 ${won(member.approvalThreshold)} 이상은 보호자 확인 후 진행돼요',
            trailing: Material(
              color: c.blueSoft,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: '보호자에게 전화',
                onPressed: () => context.read<ShellCubit>().say('(시연) 보호자 ${g.name}님께 전화를 연결해요'),
                icon: Icon(FbIcons.phone, color: c.blue, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SOS 버튼, 또는 동결 중이면 동결 카드.
class SosSlot extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;
  final bool inCard;

  const SosSlot({super.key, required this.member, required this.data, this.inCard = false});

  @override
  Widget build(BuildContext context) {
    if (member.isFrozen) {
      return FrozenCard(
        member: member,
        now: context.read<FamilyCubit>().now,
        waitingForGuardian: data.hasPending(member.id, 'unfreeze'),
        onRequestUnfreeze: () => requestUnfreeze(context, member.id),
      );
    }
    final shell = context.read<ShellCubit>();
    final button = SosHoldButton(
      onStart: () => shell.say('', toast: false, vibrate: const [30], speak: false),
      onCancel: (_) => shell.say('조금 더 길게 눌러 주세요 (2초)', speak: false, vibrate: const []),
      onComplete: () => triggerSos(context, member.id, SosTrigger.longPress),
    );
    if (!inCard) return button;
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('SOS 계좌 동결', desc: '길게 누르거나 휴대폰을 3초 동안 세게 흔들면 모든 계좌 출금이 24시간 멈추고, 보호자에게 바로 알려요.'),
          button,
        ],
      ),
    );
  }
}
