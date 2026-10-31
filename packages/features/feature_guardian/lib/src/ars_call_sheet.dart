import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'guardian_actions.dart';

/// 보호자가 푸시를 확인하지 않아 서버가 건 ARS 확인 전화 (시연용 화면).
Future<void> openArsCallSheet(BuildContext context, {required String requestId, String? script}) => showFbSheet<void>(
  context,
  builder: (_) => ArsCallSheet(requestId: requestId, script: script),
);

class ArsCallSheet extends StatefulWidget {
  final String requestId;
  final String? script;

  const ArsCallSheet({super.key, required this.requestId, this.script});

  @override
  State<ArsCallSheet> createState() => _ArsCallSheetState();
}

class _ArsCallSheetState extends State<ArsCallSheet> {
  String? _pressed;

  Future<void> _press(String digit) async {
    setState(() => _pressed = digit);
    await answerArs(context, widget.requestId, digit);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final req = context.select((FamilyCubit f) => f.state.snapshot?.request(widget.requestId));
    final done = req != null && !req.isPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: 'ARS 확인 전화'),
        CenterBlock(
          icon: ResultIcon(FbIcons.phone, tone: ResultTone.soft, ringing: !done),
          title: done ? '이미 처리된 요청이에요' : '핑거벨 안심 확인 전화',
          body: widget.script ?? '가족 계좌에서 확인이 필요한 거래가 감지되었습니다. 승인은 1번, 거절은 2번을 눌러주세요.',
        ),
        if (req != null && req.amount > 0) ...[
          const SizedBox(height: 4),
          Text('${req.title} · ${won(req.amount)}', textAlign: TextAlign.center, style: FbText.hint(c)),
        ],
        const SizedBox(height: 22.4),
        if (done)
          FbButton('닫기', onPressed: () => Navigator.of(context).maybePop())
        else
          FbButtonRow(
            children: [
              FbButton.gray('2  거절', busy: _pressed == '2', onPressed: _pressed == null ? () => _press('2') : null),
              FbButton('1  승인', busy: _pressed == '1', onPressed: _pressed == null ? () => _press('1') : null),
            ],
          ),
      ],
    );
  }
}
