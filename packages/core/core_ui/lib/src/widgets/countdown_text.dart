import 'dart:async';

import 'package:flutter/widgets.dart';

import '../format.dart';

/// 남은 시간을 1초마다 다시 그립니다. [now]는 서버 기준 현재 시각입니다.
class CountdownText extends StatefulWidget {
  final DateTime until;
  final DateTime Function() now;
  final String Function(Duration) format;
  final TextStyle? style;

  const CountdownText({
    super.key,
    required this.until,
    required this.now,
    this.format = formatCountdown,
    this.style,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(widget.now());
    return Text(
      widget.format(left.isNegative ? Duration.zero : left),
      style: (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
