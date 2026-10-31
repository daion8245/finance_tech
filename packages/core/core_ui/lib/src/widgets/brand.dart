import 'package:flutter/material.dart';

import '../theme/fb_colors.dart';
import '../theme/fb_icons.dart';

/// 파란 종 모양 브랜드 마크 + "핑거벨" 글자.
class Brand extends StatelessWidget {
  final bool showWordmark;
  final double size;

  const Brand({super.key, this.showWordmark = true, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      label: '핑거벨',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(9)),
            child: const Icon(FbIcons.bell, size: 17, color: Colors.white),
          ),
          if (showWordmark) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Text(
                '핑거벨',
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -.8, color: c.ink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
