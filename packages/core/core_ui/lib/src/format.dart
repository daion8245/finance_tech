import 'package:flutter/services.dart';

String _group(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 1234567 → "1,234,567"
String formatNumber(int n) => _group(n);

/// 1234567 → "1,234,567원"
String won(int n) => '${_group(n)}원';

String digitsOnly(String v) => v.replaceAll(RegExp(r'\D'), '');

String _two(int n) => n.toString().padLeft(2, '0');

/// "방금 전", "오늘 14:05", "어제 09:30", "10월 3일"
String formatWhen(DateTime at, DateTime now) {
  final a = at.toLocal();
  final n = now.toLocal();
  if (n.difference(a).inSeconds.abs() < 60) return '방금 전';
  final hhmm = '${_two(a.hour)}:${_two(a.minute)}';
  bool sameDay(DateTime x, DateTime y) => x.year == y.year && x.month == y.month && x.day == y.day;
  if (sameDay(a, n)) return '오늘 $hhmm';
  if (sameDay(a, n.subtract(const Duration(days: 1)))) return '어제 $hhmm';
  return '${a.month}월 ${a.day}일';
}

/// 남은 시간 "23:59:58"
String formatCountdown(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${_two(s ~/ 3600)}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

/// 남은 시간 "2:41"
String formatMinSec(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${s ~/ 60}:${_two(s % 60)}';
}

/// 금액 입력칸: 숫자만 받고 세 자리마다 쉼표를 넣습니다.
class ThousandsFormatter extends TextInputFormatter {
  final int maxDigits;
  const ThousandsFormatter({this.maxDigits = 12});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = digitsOnly(newValue.text);
    if (d.length > maxDigits) d = d.substring(0, maxDigits);
    final text = d.isEmpty ? '' : _group(int.parse(d));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// 잔액 숨기기를 켰으면 금액 대신 점을 보여 줍니다.
String wonOrHidden(int n, {required bool hidden}) => hidden ? '••••••원' : won(n);
