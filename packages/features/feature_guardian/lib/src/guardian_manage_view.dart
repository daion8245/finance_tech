import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'guardian_actions.dart';

/// 가족 관리: 동결 해제·원격 동결, 안심 모드, 하루 한도, 수면 안심 모드.
class GuardianManageView extends StatelessWidget {
  final FamilySnapshot data;

  const GuardianManageView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = [for (final m in data.members) ManageCard(key: ValueKey(m.id), member: m, data: data)];
    return FbView(
      wide: true,
      children: [
        const Greeting('가족 관리'),
        if (cards.length >= 2) FbSplit(main: [cards[0]], side: [cards[1], ...cards.skip(2)]) else ...cards,
      ],
    );
  }
}

class ManageCard extends StatefulWidget {
  final Member member;
  final FamilySnapshot data;

  const ManageCard({super.key, required this.member, required this.data});

  @override
  State<ManageCard> createState() => _ManageCardState();
}

class _ManageCardState extends State<ManageCard> {
  double? _dragLimit;

  Member get m => widget.member;

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final family = context.read<FamilyCubit>();
    final range = m.limitRange;
    final limit = (_dragLimit ?? m.dailyLimit.toDouble()).clamp(range.min.toDouble(), range.max.toDouble());
    final divisions = range.step > 0 ? ((range.max - range.min) / range.step).round() : null;

    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FbListRow(
            padding: const EdgeInsets.only(bottom: 8),
            leading: TxLogo.initial(m.name),
            title: Text(m.label),
            subtitle: m.isFrozen ? '출금 동결 중' : '정상 이용 중',
            subtitleStyle: FbText.rowSub(c).copyWith(color: m.isFrozen ? c.redStrong : c.muted),
          ),
          if (m.isFrozen)
            Container(
              margin: const EdgeInsets.only(top: 6.4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('동결 해제까지 ', style: TextStyle(fontSize: 13.6, color: c.ink2)),
                      if (m.frozenUntil != null)
                        CountdownText(
                          until: m.frozenUntil!,
                          now: family.now,
                          style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w800, color: c.ink2),
                        ),
                    ],
                  ),
                  if (m.frozenSource != null) ...[
                    const SizedBox(height: 3),
                    Text('${m.frozenSource!.label}로 동결됨', style: FbText.small(c)),
                  ],
                  const SizedBox(height: 12.8),
                  FbButton(
                    '지금 동결 해제',
                    variant: FbButtonVariant.red,
                    onPressed: () => guardianRun(context, (f) => f.unfreeze(m.id), '${m.relationLabel} 계좌 동결을 해제했어요'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 17.6),
          _FieldLabel('안심 모드'),
          FbSegmented<String>(
            options: [for (final id in m.modes) (id, widget.data.mode(id).short)],
            value: m.mode,
            onChanged: (id) => guardianRun(
              context,
              (f) => f.setMode(m.id, id, byGuardian: true),
              id == m.mode ? '' : '${m.relationLabel}: ${widget.data.mode(id).label}로 바꿨어요',
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.data.mode(m.mode).desc, style: FbText.small(c)),
          const SizedBox(height: 17.6),
          _FieldLabel('하루 사용 한도', value: won(limit.round())),
          Slider(
            value: limit,
            min: range.min.toDouble(),
            max: range.max.toDouble(),
            divisions: divisions,
            label: won(limit.round()),
            semanticFormatterCallback: (v) => won(v.round()),
            onChanged: (v) => setState(() => _dragLimit = v),
            onChangeEnd: (v) async {
              await guardianRun(context, (f) => f.setDailyLimit(m.id, v.round()), '${m.relationLabel} 하루 한도를 ${won(v.round())}으로 바꿨어요');
              if (mounted) setState(() => _dragLimit = null);
            },
          ),
          FbSettingRow(
            title: '수면 안심 모드',
            hint: '23:00~06:00에는 모든 이체를 보호자 확인 후에만 보내요',
            value: m.sleepGuard,
            onChanged: (v) => guardianRun(context, (f) => f.setSleepGuard(m.id, v), v ? '수면 안심 모드를 켰어요' : '수면 안심 모드를 껐어요'),
          ),
          if (!m.isFrozen) ...[
            const SizedBox(height: 4),
            FbButton.gray(
              '원격으로 출금 동결',
              icon: FbIcons.lock,
              onPressed: () => guardianRun(
                context,
                (f) => f.freeze(m.id, SosTrigger.guardian),
                '${m.relationLabel} 계좌 출금을 원격으로 막았어요',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? value;
  const _FieldLabel(this.label, {this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.1, fontWeight: FontWeight.w700, color: c.muted))),
          if (value != null) Text(value!, style: FbText.tabular(TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: c.ink))),
        ],
      ),
    );
  }
}
