import 'package:flutter/material.dart';

import '../theme/fb_colors.dart';
import '../theme/fb_text.dart';

/// 켜고 끄는 스위치 (48 × 28).
class FbToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  const FbToggle({super.key, required this.value, required this.label, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      toggled: value,
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? c.blue : const Color(0xFFD1D6DB),
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 회색 바탕 위 탭 버튼 묶음 (.seg, .persona-switch).
class FbSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;
  final Color? background;

  const FbSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final children = [
      for (final (v, label) in options)
        _SegButton(
          label: label,
          selected: v == value,
          compact: compact,
          onTap: () => onChanged(v),
        ),
    ];
    return Container(
      padding: EdgeInsets.all(compact ? 3 : 4),
      decoration: BoxDecoration(
        color: background ?? (compact ? const Color(0xFFE5E9EF) : c.soft),
        borderRadius: BorderRadius.circular(compact ? 11 : 12),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: compact ? children : [for (final w in children) Expanded(child: w)],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _SegButton({required this.label, required this.selected, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 4, vertical: compact ? 6 : 9.6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 8 : 9),
            boxShadow: selected ? const [BoxShadow(color: Color(0x1A141E32), blurRadius: 2, offset: Offset(0, 1))] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 12.5 : 14.1,
              fontWeight: FontWeight.w700,
              color: selected ? c.ink : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 둥근 필터 칩 줄 (.filter-row).
class FbFilterChips extends StatelessWidget {
  final List<(String, String)> items;
  final String active;
  final ValueChanged<String> onSelected;

  const FbFilterChips({super.key, required this.items, required this.active, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (key, label) in items)
          Semantics(
            selected: key == active,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15.2, vertical: 8.8),
                decoration: BoxDecoration(
                  color: key == active ? c.ink : const Color(0xFFE6EAEF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.6,
                    fontWeight: FontWeight.w700,
                    color: key == active ? Colors.white : c.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 라디오 선택 줄 (.option).
class FbOptionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool divider;
  final VoidCallback? onTap;

  const FbOptionRow({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.divider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13.6),
          decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.line)) : null),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: FbText.rowTitle(c)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2.4),
                      Text(subtitle!, style: FbText.small(c)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12.8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 21.6,
                height: 21.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? c.blue : const Color(0xFFD1D6DB), width: selected ? 6.7 : 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 설정 줄: 제목 + 설명 + 스위치 (.setting-row).
class FbSettingRow extends StatelessWidget {
  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;
  final Widget? extra;

  const FbSettingRow({
    super.key,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.divider = true,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15.2),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.line)) : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FbText.rowTitle(c)),
                const SizedBox(height: 3.2),
                Text(hint, style: FbText.rowSub(c)),
                ?extra,
              ],
            ),
          ),
          const SizedBox(width: 12.8),
          FbToggle(value: value, label: title, onChanged: onChanged),
        ],
      ),
    );
  }
}
