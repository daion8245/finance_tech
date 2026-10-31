import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 송금 시트를 엽니다. 동결 중이면 열지 않고 안내만 합니다.
///
/// [preview]를 주면 AI 안심 점검 단계부터 시작합니다 (시연 시나리오용).
Future<void> openTransferSheet(
  BuildContext context,
  String memberId, {
  TransferDraft draft = const TransferDraft(),
  TransferPreview? preview,
}) async {
  final family = context.read<FamilyCubit>();
  if (family.state.isReady && family.state.data.member(memberId).isFrozen) {
    context.read<ShellCubit>().say('계좌가 동결되어 보낼 수 없어요. 보호자에게 해제를 요청하세요.');
    return;
  }
  await showFbSheet<void>(
    context,
    builder: (_) => TransferSheet(memberId: memberId, initialDraft: draft, initialPreview: preview),
  );
}

enum TransferStep { who, amount, check, waiting, done }

String maskDigits(String digits) {
  final d = digitsOnly(digits);
  return d.length < 8 ? d : '${d.substring(0, 3)}-••••-${d.substring(d.length - 4)}';
}

class TransferSheet extends StatefulWidget {
  final String memberId;
  final TransferDraft initialDraft;
  final TransferPreview? initialPreview;

  const TransferSheet({super.key, required this.memberId, this.initialDraft = const TransferDraft(), this.initialPreview});

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  late TransferStep _step;
  late TransferDraft _draft;
  late bool _newMode;
  TransferPreview? _preview;
  TransferResult? _result;
  String? _requestId;
  String? _error;
  bool _busy = false;

  final _number = TextEditingController();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _bank;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _preview = widget.initialPreview;
    _newMode = _draft.newAccount != null;
    _step = _preview != null ? TransferStep.check : TransferStep.who;
    final na = _draft.newAccount;
    if (na != null) {
      _bank = na.bank;
      _number.text = na.number;
      _name.text = na.name;
    }
    if (_draft.amount > 0) _amount.text = formatNumber(_draft.amount);
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _go(TransferStep step) => setState(() {
    _step = step;
    _error = null;
  });

  ShellCubit get _shell => context.read<ShellCubit>();
  FamilyCubit get _family => context.read<FamilyCubit>();

  // ---------------------------------------------------------------- 동작
  void _pickContact(Contact c) => setState(() {
    _draft = _draft.copyWith(contactId: c.id);
    _step = TransferStep.amount;
    _error = null;
  });

  void _submitNewAccount(List<String> banks) {
    final digits = digitsOnly(_number.text);
    final name = _name.text.trim();
    if (digits.length < 10 || digits.length > 14) {
      setState(() => _error = '계좌번호는 숫자 10~14자리로 입력해 주세요.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = '받는 분 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      _draft = TransferDraft(newAccount: NewAccount(bank: _bank ?? banks.first, number: digits, name: name), amount: _draft.amount);
      _step = TransferStep.amount;
      _error = null;
    });
  }

  void _addAmount(int add, int balance) {
    final now = int.tryParse(digitsOnly(_amount.text)) ?? 0;
    final next = add < 0 ? balance : (now + add).clamp(0, balance);
    _amount.text = formatNumber(next);
  }

  Future<void> _check() async {
    final amount = int.tryParse(digitsOnly(_amount.text)) ?? 0;
    if (amount <= 0) {
      setState(() => _error = '1원 이상 금액을 입력해 주세요.');
      return;
    }
    _draft = _draft.copyWith(amount: amount);
    setState(() => _busy = true);
    try {
      final preview = await _family.assessTransfer(widget.memberId, _draft);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _step = TransferStep.check;
        _busy = false;
        _error = null;
      });
      if (preview.risk.level == RiskLevel.high) {
        final next = preview.risk.needsApproval ? '보호자 확인이 필요해요.' : '보내기 전에 한 번 더 확인해 주세요.';
        _shell.say('사기 위험이 높은 거래예요. $next', toast: false, vibrate: const [120, 60, 120]);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final result = await _family.submitTransfer(widget.memberId, _draft);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
        _requestId = result.request?.id;
        _step = result.isPending ? TransferStep.waiting : TransferStep.done;
      });
      if (result.isPending) {
        _shell.say('보호자에게 확인을 요청했어요', toast: false, vibrate: const [60]);
      } else {
        _shell.say('${won(result.amount)}을 보냈어요', toast: false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _shell.say(e.message, vibrate: const [80, 40, 80]);
    }
  }

  void _close() => Navigator.of(context).maybePop();

  // ---------------------------------------------------------------- 화면
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
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              TransferStep.who => _who(member, data, hidden),
              TransferStep.amount => _amountStep(member),
              TransferStep.check => _checkStep(data),
              TransferStep.waiting => _waiting(data, state),
              TransferStep.done => _done(member, hidden),
            },
          ),
        );
      },
    );
  }

  Widget _who(Member m, FamilySnapshot data, bool hidden) {
    final c = context.fb;
    final banks = data.banks.isEmpty ? const ['핑거벨'] : data.banks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '누구에게 보낼까요?', onClose: _close),
        Text('${m.account.name} · 잔액 ${wonOrHidden(m.balance, hidden: hidden)}', style: FbText.hint(c)),
        const SizedBox(height: 8),
        for (final contact in m.contacts)
          FbListRow(
            leading: TxLogo.initial(contact.name),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: contact.name),
                  TextSpan(text: '  ${contact.relation}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            subtitle: '${contact.bank} ${contact.number}',
            chevron: true,
            onTap: () => _pickContact(contact),
          ),
        if (!_newMode)
          FbListRow(
            leading: const TxLogo(icon: FbIcons.plus, blue: true),
            title: Text('새 계좌로 보내기', style: TextStyle(color: c.blue)),
            onTap: () => setState(() => _newMode = true),
          )
        else ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: banks.contains(_bank) ? _bank : banks.first,
            items: [for (final b in banks) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => _bank = v,
            decoration: const InputDecoration(labelText: '은행'),
          ),
          const SizedBox(height: 12.8),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
            decoration: const InputDecoration(hintText: '계좌번호 (숫자만)', labelText: '계좌번호'),
          ),
          const SizedBox(height: 12.8),
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '받는 분 이름', labelText: '받는 분 이름', counterText: ''),
            onSubmitted: (_) => _submitNewAccount(banks),
          ),
          _ErrorText(_error),
          FbButton('다음', onPressed: () => _submitNewAccount(banks)),
        ],
      ],
    );
  }

  ({String name, String bank, String number, bool isNew}) _recipient(Member m) {
    final contact = _draft.contactId == null ? null : m.contact(_draft.contactId!);
    if (contact != null) return (name: contact.name, bank: contact.bank, number: contact.number, isNew: false);
    final na = _draft.newAccount;
    return (name: na?.name ?? '', bank: na?.bank ?? '', number: maskDigits(na?.number ?? ''), isNew: true);
  }

  Widget _amountStep(Member m) {
    final c = context.fb;
    final r = _recipient(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '얼마를 보낼까요?', onBack: () => _go(TransferStep.who), onClose: _close),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: r.name, style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: '님 · ${r.bank} ${r.number}'),
              if (r.isNew) TextSpan(text: ' · 새 계좌', style: TextStyle(color: c.redStrong)),
            ],
          ),
          style: FbText.hint(c),
        ),
        const SizedBox(height: 19.2),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.blue, width: 2))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsFormatter()],
                  style: FbText.balance(c),
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: FbText.balance(c).copyWith(color: c.faint),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              Text('원', style: TextStyle(fontSize: 22.4, fontWeight: FontWeight.w700, color: c.ink)),
            ],
          ),
        ),
        const SizedBox(height: 14.4),
        Row(
          children: [
            for (final (v, label) in const [(10000, '+1만'), (50000, '+5만'), (100000, '+10만'), (-1, '전액')]) ...[
              if (v != 10000) const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _addAmount(v, m.balance),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9.6),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: c.ink2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text('보낼 수 있는 금액 ${won(m.balance)}', style: FbText.hint(c)),
        _ErrorText(_error),
        FbButton('다음', busy: _busy, onPressed: _check),
      ],
    );
  }

  Widget _checkStep(FamilySnapshot data) {
    final c = context.fb;
    final p = _preview!;
    final risk = p.risk;
    final safe = risk.isSafe;
    final model = risk.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(onBack: () => _go(TransferStep.amount), onClose: _close),
        Row(
          children: [
            Icon(FbIcons.sparkle, size: 15, color: c.blue),
            const SizedBox(width: 4.8),
            Text('AI 안심 점검', style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: c.blue)),
          ],
        ),
        const SizedBox(height: 6.4),
        Semantics(
          liveRegion: true,
          child: Text(
            risk.level.title,
            style: TextStyle(
              fontSize: 21.6,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: safe ? c.ink : c.redStrong,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: Text('위험도', style: TextStyle(fontSize: 13.1, fontWeight: FontWeight.w600, color: c.muted))),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${risk.score}점', style: TextStyle(fontWeight: FontWeight.w800, color: safe ? c.ink : c.redStrong)),
                  const TextSpan(text: ' / 100'),
                ],
              ),
              style: TextStyle(fontSize: 13.1, fontWeight: FontWeight.w600, color: c.muted),
            ),
          ],
        ),
        const SizedBox(height: 7.2),
        FbRail(fraction: risk.score / 100, color: safe ? c.blue : c.red, height: 7.2),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14.4),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: risk.signals.isEmpty
                ? [Text('평소 거래와 다른 점이 없어요', style: TextStyle(fontSize: 13.8, height: 1.75, color: c.ink2))]
                : [for (final s in risk.signals) BulletText(s.label, style: TextStyle(fontSize: 13.8, height: 1.75, color: c.ink2))],
          ),
        ),
        if (model != null) ...[
          const SizedBox(height: 8),
          Text(
            'Isolation Forest 모델 · 최근 거래 ${model.trainedOn}건으로 학습${model.anomaly ? ' · 이상 패턴 감지' : ''}',
            style: FbText.small(c),
          ),
        ],
        if (risk.level == RiskLevel.high) ...[
          const SizedBox(height: 12.8),
          Text(
            risk.needsApproval
                ? '전화로 송금을 재촉받고 있다면 지금 전화를 끊고 보호자에게 먼저 연락하세요.'
                : '전화로 송금을 재촉받고 있다면 지금 전화를 끊고 받는 분을 직접 확인하세요.',
            style: TextStyle(fontSize: 13.4, height: 1.6, color: c.redStrong, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        _SummaryLine('받는 분', '${p.recipient.name} · ${p.recipient.bank}'),
        const SizedBox(height: 9.6),
        _SummaryLine('보낼 금액', won(p.amount)),
        if (risk.needsApproval) ...[
          const SizedBox(height: 12),
          Text('보호자 ${data.guardian.name}님이 확인한 뒤 보내져요. (앱 알림 → ARS 전화)', style: FbText.hint(c)),
        ],
        const SizedBox(height: 22.4),
        FbButtonRow(
          flex: const [10, 18],
          children: [
            FbButton.gray('취소', onPressed: _close),
            FbButton(
              risk.needsApproval
                  ? '보호자에게 확인 요청'
                  : safe
                  ? '보내기'
                  : '확인했어요, 보내기',
              busy: _busy,
              onPressed: _send,
            ),
          ],
        ),
      ],
    );
  }

  Widget _waiting(FamilySnapshot data, FamilyState state) {
    final c = context.fb;
    final req = _requestId == null ? null : data.request(_requestId!);
    if (req != null && !req.isPending) {
      final ok = req.status == 'approved';
      final (title, body) = switch (req.status) {
        'approved' => ('보호자가 승인했어요', '송금을 마쳤어요.'),
        'rejected' => ('보호자가 거절했어요', '돈은 나가지 않았어요.'),
        'expired' => ('보호자 응답이 없어 취소했어요', '3분 안에 확인되지 않아 돈은 나가지 않았어요.'),
        'cancelled' => ('송금 요청이 취소됐어요', 'SOS 동결로 요청을 멈췄어요. 돈은 나가지 않았어요.'),
        _ => ('처리하지 못했어요', req.failReason ?? '돈은 나가지 않았어요.'),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(onClose: _close),
          CenterBlock(
            icon: ResultIcon(ok ? FbIcons.check : FbIcons.close, tone: ok ? ResultTone.blue : ResultTone.red),
            title: title,
            body: '${req.title} · ${won(req.amount)}\n$body',
          ),
          const SizedBox(height: 22.4),
          FbButton('확인', onPressed: _close),
        ],
      );
    }
    final ars = req?.arsCalledAt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(onClose: _close),
        CenterBlock(
          icon: const ResultIcon(FbIcons.phone, tone: ResultTone.soft, ringing: true),
          title: '보호자 확인을 기다리고 있어요',
          body: ars
              ? '${data.guardian.name}님께 ARS 확인 전화를 걸었어요.\n승인되면 바로 보내드릴게요.'
              : '${data.guardian.name}님께 앱 알림을 보냈어요.\n승인되면 바로 보내드릴게요.',
        ),
        if (req?.expiresAt != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('답이 없으면 자동 취소 · ', style: FbText.hint(c)),
              CountdownText(
                until: req!.expiresAt!,
                now: context.read<FamilyCubit>().now,
                format: formatMinSec,
                style: FbText.hint(c).copyWith(fontWeight: FontWeight.w800, color: c.ink2),
              ),
            ],
          ),
        const SizedBox(height: 22.4),
        FbButton('보호자 화면에서 확인하기 (시연)', onPressed: () => _shell.goto(Persona.guardian, AppTab.home)),
        const SizedBox(height: 8),
        FbButton.gray('닫기', onPressed: _close),
      ],
    );
  }

  Widget _done(Member m, bool hidden) {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(onClose: _close),
        CenterBlock(
          icon: const ResultIcon(FbIcons.check),
          title: '${r.recipient?.name ?? ''}님께 ${won(r.amount)}을 보냈어요',
          body: '남은 잔액 ${wonOrHidden(m.balance, hidden: hidden)}',
        ),
        const SizedBox(height: 22.4),
        FbButton('확인', onPressed: _close),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String? text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 11),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text ?? '',
        style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: context.fb.redStrong),
      ),
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14.4, color: c.muted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w700, color: c.ink),
          ),
        ),
      ],
    );
  }
}
