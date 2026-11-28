import 'package:flutter/material.dart';

import 'genome.dart';

/// Уровни редкости: 0 — без мутаций, 1..10 — от «1 из 20» до редчайших.
///
/// Пороги идут по реальным ступеням шансов, поэтому каждый уровень
/// достижим: одиночные мутации дают 1–5, пары — 6–8, тройки — 9–10.
int rarityLevel(AgatePassport passport) {
  if (passport.isPlain) return 0;
  for (var i = 0; i < _thresholds.length; i++) {
    if (passport.rarity > _thresholds[i]) return i + 1;
  }
  return 10;
}

/// Цвет уровня: от нейтрального серого к зелёному, синему и золоту.
Color rarityColor(int level) => _colors[level.clamp(0, 10)];

/// Верхние уровни светятся, как LED.
bool rarityGlows(int level) => level >= 8;

const List<double> _thresholds = <double>[
  0.03, // L1: 1 из 20
  0.02, // L2: 1 из 33
  0.01, // L3: 1 из 50
  0.005, // L4: 1 из 100
  0.0015, // L5: 1 из 200
  0.001, // L6: 1 из 667
  0.0006, // L7: 1 из 1 000
  0.0003, // L8: 1 из 1 667
  0.00002, // L9: 1 из 3 333
];

const List<Color> _colors = <Color>[
  Color(0xFF8B8B93), // 0 — без мутаций
  Color(0xFF9AA3AE), // 1 — серый
  Color(0xFF7FB77E), // 2 — зелёный
  Color(0xFF58BFA6), // 3 — бирюза
  Color(0xFF5E97D8), // 4 — синий
  Color(0xFF7C86E0), // 5 — индиго
  Color(0xFFA97FD8), // 6 — фиолетовый
  Color(0xFFCF76C4), // 7 — малиновый
  Color(0xFFE07A8A), // 8 — алый
  Color(0xFFE0A45A), // 9 — янтарный
  Color(0xFFF2D27A), // 10 — золотой
];
