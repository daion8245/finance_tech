import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// 화면 위쪽에 잠깐 떴다 사라지는 안내 (.toast).
class ToastHost extends StatefulWidget {
  final double top;
  final bool centered;

  const ToastHost({super.key, required this.top, this.centered = false});

  @override
  State<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends State<ToastHost> {
  String _message = '';
  bool _visible = false;
  Timer? _timer;

  void show(String message) {
    _timer?.cancel();
    setState(() {
      _message = message;
      _visible = true;
    });
    SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toast = IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -.15),
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13.6),
            decoration: BoxDecoration(color: const Color(0xFF252F40), borderRadius: BorderRadius.circular(14)),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13.6, fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top + widget.top,
          left: 20,
          right: 20,
          child: widget.centered
              ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: toast))
              : toast,
        ),
      ],
    );
  }
}
