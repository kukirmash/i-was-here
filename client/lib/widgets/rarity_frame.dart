import 'package:flutter/material.dart';

import '../agate/rarity.dart';

/// Рамка редкости: цвет зависит от уровня, верхние уровни мягко светятся.
class RarityFrame extends StatelessWidget {
  const RarityFrame({
    super.key,
    required this.level,
    required this.child,
    this.padding = const EdgeInsets.all(8),
  });

  final int level;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (level <= 0) {
      return Padding(padding: padding, child: child);
    }

    final color = rarityColor(level);
    final glow = rarityGlows(level) ? (level - 7) : 0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withAlpha((5 + level * 2).clamp(0, 60)),
        border: Border.all(
          color: color.withAlpha((90 + level * 10).clamp(0, 255)),
          width: (1.0 + level * 0.1).toDouble(),
        ),
        boxShadow: glow > 0
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withAlpha((70 + glow * 25).clamp(0, 200)),
                  blurRadius: (14 + glow * 10).toDouble(),
                  spreadRadius: (glow * 2).toDouble(),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
