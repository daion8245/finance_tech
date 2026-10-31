import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 결제 시트를 엽니다. [result]를 주면 결과 화면부터 보여 줍니다 (시연 시나리오용).
Future<void> openPaySheet(BuildContext context, String memberId, {PaymentResult? result}) => showFbSheet<void>(
  context,
  builder: (_) => PaySheet(memberId: memberId, initialResult: result),
);

/// 결제처 옆에 붙는 상태 표시 (글자, 강조 종류).
const payLabels = {
  'ok': ('결제 가능', 'accent'),
  'mode': ('사용 불가', 'danger'),
  'frozen': ('동결 중', 'danger'),
  'balance': ('잔액 부족', ''),
  'limit': ('한도 초과', ''),
  'approval': ('보호자 확인', ''),
};

const payTitles = {
  'mode': '지금 모드에서는 결제할 수 없어요',
  'limit': '오늘 한도를 넘었어요',
  'approval': '보호자 확인이 필요해요',
  'frozen': '계좌가 동결되어 있어요',
  'balance': '잔액이 부족해요',
  'duplicate': '이미 요청했어요',
  'merchant': '결제할 수 없어요',
};

class PaySheet extends StatefulWidget {
  final String memberId;
  final PaymentResult? initialResult;

  const PaySheet({super.key, required this.memberId, this.initialResult});

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  PaymentResult? _result;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  ShellCubit get _shell => context.read<ShellCubit>();

  Future<void> _pay(Merchant m) async {
    setState(() => _busyId = m.id);
    try {
      final r = await context.read<FamilyCubit>().pay(widget.memberId, m.id);
      if (!mounted) return;
      setState(() {
        _result = r;
        _busyId = null;
      });
      _shell.say(r.ok ? '${won(r.merchant.amount)} 결제했어요' : r.message, toast: false, vibrate: r.ok ? const [40] : const [80, 40, 80]);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _shell.say(e.message);
    }
  }

  Future<void> _request(Merchant m) async {
    setState(() => _busyId = m.id);
    try {
      final r = await context.read<FamilyCubit>().requestPayment(widget.memberId, m.id);
      if (!mounted) return;
      setState(() {
        _result = r;
        _busyId = null;
      });
      if (r.isPending) _shell.say('보호자에게 확인을 요청했어요', toast: false, vibrate: const [60]);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _shell.say(e.message);
    }
  }

  void _back() => setState(() => _result = null);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        final data = state.data;
        final member = data.memberOrNull(widget.memberId);
        if (member == null) return const EmptyText('사용자를 찾을 수 없어요');
        final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _result == null
              ? KeyedSubtree(key: const ValueKey('list'), child: _list(member, data, hidden))
              : KeyedSubtree(key: const ValueKey('result'), child: _resultView(member, data, _result!)),
        );
      },
    );
  }

  Widget _list(Member m, FamilySnapshot data, bool hidden) {
    final c = context.fb;
    final mode = data.mode(m.mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: '결제하기'),
        // 보호자 본인 계좌에는 안심 모드가 없으므로 잔액을 보여 줍니다
        Text(
          m.isGuardian ? '${m.account.name} · 잔액 ${wonOrHidden(m.balance, hidden: hidden)}' : '${mode.label} · ${mode.desc}',
          style: FbText.hint(c),
        ),
        const SizedBox(height: 6),
        for (final merchant in m.merchants)
          Builder(
            builder: (context) {
              final (label, tone) = payLabels[merchant.check.code] ?? ('', '');
              final color = tone == 'accent' ? c.blue : tone == 'danger' ? c.redStrong : c.muted;
              return FbListRow(
                leading: TxLogo.initial(merchant.name),
                title: Text(merchant.name),
                subtitle: '${merchant.categoryLabel} · ${won(merchant.amount)}',
                trailing: _busyId == merchant.id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(label, style: FbText.note(c).copyWith(color: color)),
                onTap: _busyId == null ? () => _pay(merchant) : null,
              );
            },
          ),
      ],
    );
  }

  Widget _resultView(Member m, FamilySnapshot data, PaymentResult r) {
    final merchant = r.merchant;
    final pending = r.isPending;
    final (icon, tone, ringing, title, body) = pending
        ? (FbIcons.phone, ResultTone.soft, true, '보호자 확인을 기다려요', '${data.guardian.name}님께 앱 알림을 보냈어요. 답이 없으면 ARS 전화를 걸어요.')
        : r.ok
        ? (FbIcons.check, ResultTone.blue, false, '${won(merchant.amount)} 결제했어요', '${merchant.name} · 남은 돈 ${won(m.balance)}')
        : (FbIcons.lock, ResultTone.red, false, payTitles[r.code] ?? '결제할 수 없어요', r.message);

    final List<Widget> actions;
    if (!r.ok && r.canRequest) {
      actions = [
        FbButton('보호자에게 요청하기', busy: _busyId == merchant.id, onPressed: () => _request(merchant)),
        FbButton.gray('돌아가기', onPressed: _back),
      ];
    } else if (pending) {
      actions = [
        FbButton('보호자 화면에서 확인하기 (시연)', onPressed: () => _shell.goto(Persona.guardian, AppTab.home)),
        FbButton.gray('돌아가기', onPressed: _back),
      ];
    } else {
      actions = [FbButton('다른 결제 해보기', onPressed: _back)];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(onBack: _back),
        CenterBlock(icon: ResultIcon(icon, tone: tone, ringing: ringing), title: title, body: body),
        const SizedBox(height: 22.4),
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 8), actions[i]],
      ],
    );
  }
}
