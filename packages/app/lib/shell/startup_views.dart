import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Brand(size: 22),
          const SizedBox(height: 24),
          SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: context.fb.blue)),
        ],
      ),
    ),
  );
}

/// 백엔드에 연결하지 못했을 때. 주소와 실행 방법을 함께 보여 줍니다.
class ConnectionErrorView extends StatelessWidget {
  final String message;
  final String serverAddress;
  final VoidCallback onRetry;

  const ConnectionErrorView({super.key, required this.message, required this.serverAddress, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: Brand(size: 20)),
                  CenterBlock(
                    icon: const ResultIcon(FbIcons.cloudOff, tone: ResultTone.red),
                    title: '서버에 연결할 수 없어요',
                    body: message,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('서버 주소', style: FbText.small(c)),
                        SelectableText(serverAddress, style: FbText.rowTitle(c)),
                        const SizedBox(height: 10),
                        Text('저장소 루트에서 백엔드를 먼저 실행하세요', style: FbText.small(c)),
                        SelectableText('.\\run-backend.ps1', style: FbText.rowTitle(c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FbButton('다시 시도', icon: FbIcons.reset, onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
