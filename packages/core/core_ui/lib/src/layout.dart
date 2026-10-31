import 'package:flutter/widgets.dart';

/// 화면 폭이 이 값 이상이면 웹(사이드바 + 2단) 레이아웃을 씁니다.
const webBreakpoint = 900.0;

/// 지금 그리는 레이아웃이 웹(16:9 2단)인지 모바일(1단)인지 알려 줍니다.
class FbLayout extends InheritedWidget {
  final bool isWeb;

  const FbLayout({super.key, required this.isWeb, required super.child});

  static bool isWebOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FbLayout>()?.isWeb ?? false;

  @override
  bool updateShouldNotify(FbLayout oldWidget) => oldWidget.isWeb != isWeb;
}

/// 화면 본문. 웹은 카드 사이 16px, 모바일은 12px 간격으로 쌓습니다.
class FbView extends StatelessWidget {
  final List<Widget> children;

  /// 2단(FbSplit)이 없는 화면은 웹에서 760px까지만 넓어집니다.
  final bool wide;

  const FbView({super.key, required this.children, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final web = FbLayout.isWebOf(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _gap(children, web ? 16 : 12),
    );
    if (!web || wide) return column;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: column),
    );
  }
}

/// 웹은 메인/사이드 2단, 모바일은 [mobile] 순서로 한 줄에 쌓습니다.
class FbSplit extends StatelessWidget {
  final List<Widget> main;
  final List<Widget> side;
  final List<Widget>? mobile;

  const FbSplit({super.key, required this.main, required this.side, this.mobile});

  @override
  Widget build(BuildContext context) {
    if (!FbLayout.isWebOf(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _gap(mobile ?? [...main, ...side], 12),
      );
    }
    Widget col(List<Widget> items) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(items, 16));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 145, child: col(main)),
        const SizedBox(width: 16),
        Expanded(flex: 100, child: col(side)),
      ],
    );
  }
}

List<Widget> _gap(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
];
