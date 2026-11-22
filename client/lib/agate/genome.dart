import 'dart:math' as math;

import 'prng.dart';

/// Версия генома. Никогда не меняется для уже выданных камней: новые признаки
/// добавляются новым солёным потоком, а не правкой существующего.
const int agateGenomeVersion = 1;

/// Идентификаторы мутаций (раздел 3.3 спецификации).
abstract final class MutationId {
  static const String kintsugi = 'kintsugi';
  static const String doubleGeode = 'double_geode';
  static const String mossDendrites = 'moss_dendrites';
  static const String iridescence = 'iridescence';
  static const String eyeAgate = 'eye_agate';
  static const String albino = 'albino';
  static const String obsidian = 'obsidian';
  static const String inclusion = 'inclusion';
}

class AgateHarmonic {
  const AgateHarmonic(this.k, this.amplitude, this.phase);

  final int k;
  final double amplitude;
  final double phase;
}

class MutationInfo {
  const MutationInfo({
    required this.id,
    required this.title,
    required this.chance,
    required this.description,
  });

  final String id;
  final String title;
  final double chance;
  final String description;
}

/// Базовые шансы из таблицы 3.3. Порядок и значения фиксированы версией генома.
const List<MutationInfo> mutationCatalog = <MutationInfo>[
  MutationInfo(
    id: MutationId.kintsugi,
    title: 'Кинцуги',
    chance: 0.05,
    description: 'Золотые жилы-трещины от края к центру',
  ),
  MutationInfo(
    id: MutationId.doubleGeode,
    title: 'Двойная жеода',
    chance: 0.03,
    description: 'Две сросшиеся кристаллические полости',
  ),
  MutationInfo(
    id: MutationId.mossDendrites,
    title: 'Моховые дендриты',
    chance: 0.03,
    description: 'Ветвистые фрактальные включения в средних слоях',
  ),
  MutationInfo(
    id: MutationId.iridescence,
    title: 'Иризация',
    chance: 0.02,
    description: 'Радужный перелив, реагирующий на свет',
  ),
  MutationInfo(
    id: MutationId.eyeAgate,
    title: 'Глазчатый агат',
    chance: 0.02,
    description: 'Круглое «око» с радиальными лучами',
  ),
  MutationInfo(
    id: MutationId.albino,
    title: 'Лунный кварц',
    chance: 0.01,
    description: 'Полное обесцвечивание, молочная палитра',
  ),
  MutationInfo(
    id: MutationId.obsidian,
    title: 'Обсидиан',
    chance: 0.01,
    description: 'Почти чёрная порода с раскалённой жилой',
  ),
  MutationInfo(
    id: MutationId.inclusion,
    title: 'Инклюз',
    chance: 0.005,
    description: 'Застывший артефакт внутри полупрозрачного слоя',
  ),
];

const double _dayMs = 86400000;
const double _synodicDays = 29.530588853;

/// Паспорт генома для карточки профиля.
class AgatePassport {
  const AgatePassport({
    required this.timeOfDay,
    required this.season,
    required this.maturityPercent,
    required this.moonPhase,
    required this.mutations,
    required this.rarity,
  });

  final String timeOfDay;
  final String season;
  final int maturityPercent;
  final String moonPhase;
  final List<MutationInfo> mutations;
  final double rarity;

  bool get isPlain => mutations.isEmpty;

  /// «1 из 2 000» либо «без мутаций».
  String get rarityLabel {
    if (mutations.isEmpty) return 'без мутаций';
    final n = (1 / rarity).round();
    return '1 из ${_groupThousands(n)}';
  }

  static String _groupThousands(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u2009');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Геном камня: макро-гены (время), микро-гены (солёные потоки) и мутации.
///
/// Порядок обращений к потокам — часть формата. Менять его нельзя: у всех
/// существующих пользователей камни изменятся. Именно поэтому все параметры
/// генома вычисляются здесь, один раз и в одном месте.
class AgateGenome {
  AgateGenome._({
    required this.createdAtMs,
    required this.nowMs,
    required this.baseHue,
    required this.seasonFactor,
    required this.ageFactor,
    required this.moonPhase,
    required this.harmonicCount,
    required this.roughness,
    required this.squeezeX,
    required this.rotation,
    required this.baseRings,
    required this.visibleRings,
    required this.geodeRadius,
    required this.geodeShiftX,
    required this.geodeShiftY,
    required this.hueSpread,
    required this.layerContrast,
    required this.harmonics,
    required this.mutations,
    required this.twinAngle,
    required this.twinDistance,
  });

  factory AgateGenome.fromTimestamp(int createdAtMs, {DateTime? now}) {
    final nowMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final createdUtc = DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true);

    final hour = createdUtc.hour + createdUtc.minute / 60.0;
    final baseHue = baseHueFor(hour);

    final dayOfYear = createdUtc.difference(DateTime.utc(createdUtc.year)).inDays;
    final seasonFactor = math.cos(2 * math.pi * dayOfYear / 365);

    final ageDays = (nowMs - createdAtMs) / _dayMs;
    final ageFactor =
        ageDays <= 0 ? 0.0 : math.min(1.0, math.log(1 + ageDays) / math.ln2 / 9.0);

    final moonPhase = _moonPhase(createdAtMs);

    // --- v1:geo: микро-гены в порядке таблицы 3.2, затем гармоники контура ---
    final geo = AgateRandom(agateSeed(createdAtMs, 'v1:geo'));
    final harmonicCount = geo.nextInt(4, 7);
    final roughness = geo.range(0.12, 0.28);
    final squeezeX = geo.range(0.82, 1.18);
    final rotation = geo.range(0, 2 * math.pi);
    final baseRings = geo.nextInt(12, 26);
    final geodeRadius = geo.range(0.16, 0.34);
    final geodeShiftX = geo.range(-0.12, 0.12);
    final geodeShiftY = geo.range(-0.12, 0.12);

    // Спецификация не фиксирует амплитуды гармоник — берём их из того же
    // потока сразу после генов (документированный порядок не сдвигается).
    final harmonics = <AgateHarmonic>[];
    for (var i = 0; i < harmonicCount; i++) {
      final k = 2 + i;
      final amplitude = roughness * geo.range(0.35, 1.0) / math.sqrt(k);
      harmonics.add(AgateHarmonic(k, amplitude, geo.range(0, 2 * math.pi)));
    }

    // --- v1:color ---
    final color = AgateRandom(agateSeed(createdAtMs, 'v1:color'));
    final hueSpread = color.range(18, 65);
    final layerContrast = color.range(0.35, 0.85);

    // --- v1:mut: 8 независимых бросков в порядке спецификации ---
    final mut = AgateRandom(agateSeed(createdAtMs, 'v1:mut'));
    final rollKintsugi = mut.next();
    final rollDouble = mut.next();
    final rollMoss = mut.next();
    final rollIridescence = mut.next();
    final rollEye = mut.next();
    final rollAlbino = mut.next();
    final rollObsidian = mut.next();
    final rollInclusion = mut.next();

    final mutations = <String>[];
    if (rollKintsugi < 0.05) mutations.add(MutationId.kintsugi);
    if (rollDouble < 0.03) mutations.add(MutationId.doubleGeode);
    if (rollMoss < 0.03) mutations.add(MutationId.mossDendrites);
    if (rollEye < 0.02 && !mutations.contains(MutationId.doubleGeode)) {
      mutations.add(MutationId.eyeAgate);
    }
    if (rollAlbino < 0.01) mutations.add(MutationId.albino);
    if (rollObsidian < 0.01 && !mutations.contains(MutationId.albino)) {
      mutations.add(MutationId.obsidian);
    }
    if (rollIridescence < 0.02 && !mutations.contains(MutationId.albino)) {
      mutations.add(MutationId.iridescence);
    }
    if (rollInclusion < 0.005) mutations.add(MutationId.inclusion);

    // Календарные аномалии (раздел 3.3): ровно в полночь UTC и в полнолуние.
    if (createdUtc.hour == 0 &&
        createdUtc.minute == 0 &&
        !mutations.contains(MutationId.albino)) {
      if (!mutations.contains(MutationId.obsidian)) {
        mutations.add(MutationId.obsidian);
      }
    }
    if ((moonPhase - 0.5).abs() <= 0.015 &&
        !mutations.contains(MutationId.obsidian)) {
      if (!mutations.contains(MutationId.albino)) {
        mutations.add(MutationId.albino);
      }
    }

    final visibleRings = (baseRings * (0.45 + 0.55 * ageFactor))
        .round()
        .clamp(2, baseRings);

    // Двойная жеода: направление и разнесение центров. Поток тот же, но
    // обращаемся к нему только у таких камней — остальные камни не меняются.
    double? twinAngle;
    double? twinDistance;
    if (mutations.contains(MutationId.doubleGeode)) {
      twinAngle = geo.range(0, 2 * math.pi);
      twinDistance = geo.range(0.38, 0.48);
    }

    return AgateGenome._(
      createdAtMs: createdAtMs,
      nowMs: nowMs,
      baseHue: baseHue,
      seasonFactor: seasonFactor,
      ageFactor: ageFactor,
      moonPhase: moonPhase,
      harmonicCount: harmonicCount,
      roughness: roughness,
      squeezeX: squeezeX,
      rotation: rotation,
      baseRings: baseRings,
      visibleRings: visibleRings,
      geodeRadius: geodeRadius,
      geodeShiftX: geodeShiftX,
      geodeShiftY: geodeShiftY,
      hueSpread: hueSpread,
      layerContrast: layerContrast,
      harmonics: harmonics,
      mutations: mutations,
      twinAngle: twinAngle,
      twinDistance: twinDistance,
    );
  }

  final int createdAtMs;
  final int nowMs;

  final double baseHue; // 0..360
  final double seasonFactor; // -1..1
  final double ageFactor; // 0..1
  final double moonPhase; // 0..1, 0.5 — полнолуние

  final int harmonicCount;
  final double roughness;
  final double squeezeX;
  final double rotation;
  final int baseRings;
  final int visibleRings;
  final double geodeRadius;
  final double geodeShiftX;
  final double geodeShiftY;
  final double hueSpread;
  final double layerContrast;
  final List<AgateHarmonic> harmonics;
  final List<String> mutations;

  /// Только для double_geode.
  final double? twinAngle;
  final double? twinDistance;

  bool has(String mutationId) => mutations.contains(mutationId);

  bool get isAlbino => has(MutationId.albino);
  bool get isObsidian => has(MutationId.obsidian);

  double get geodeShiftRadius =>
      math.sqrt(geodeShiftX * geodeShiftX + geodeShiftY * geodeShiftY);

  /// Базовый тон по суточному циклу: кусочно-линейная интерполяция
  /// между опорными точками из таблицы 3.1.
  static double baseHueFor(double hourUtc) {
    const stops = <List<double>>[
      [2.5, 215], // индиго/бирюза
      [7.5, 25], // персик/розовый кварц
      [13.5, 185], // сапфир/нефрит
      [19.5, 285], // аметист/янтарь
      [23.0, 230], // глубокий кобальт
    ];

    for (var i = 0; i < stops.length; i++) {
      final t0 = stops[i][0];
      final h0 = stops[i][1];
      final next = stops[(i + 1) % stops.length];
      final t1 = i + 1 == stops.length ? next[0] + 24 : next[0];
      final t = hourUtc >= t0 ? hourUtc : hourUtc + 24;
      if (t >= t0 && t <= t1) {
        final k = (t - t0) / (t1 - t0);
        return _lerpHue(h0, next[1], k);
      }
    }
    return 215;
  }

  static double _lerpHue(double a, double b, double t) {
    final delta = ((b - a) % 360 + 540) % 360 - 180; // короткий путь по кругу
    return (a + delta * t + 360) % 360;
  }

  static double _moonPhase(int createdAtMs) {
    final reference = DateTime.utc(2000, 1, 6, 18, 14).millisecondsSinceEpoch;
    final days = (createdAtMs - reference) / _dayMs;
    final phase = (days % _synodicDays) / _synodicDays;
    return phase < 0 ? phase + 1 : phase;
  }

  AgatePassport passport() {
    final createdUtc = DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true);
    final infos = mutationCatalog
        .where((m) => mutations.contains(m.id))
        .toList(growable: false);

    var rarity = 1.0;
    for (final m in infos) {
      rarity *= m.chance;
    }

    return AgatePassport(
      timeOfDay: _timeOfDayLabel(createdUtc.hour),
      season: _seasonLabel(createdUtc.month),
      maturityPercent: (ageFactor * 100).round(),
      moonPhase: _moonLabel(moonPhase),
      mutations: infos,
      rarity: rarity,
    );
  }

  static String _timeOfDayLabel(int hour) {
    if (hour < 5) return 'Ночь · индиго и бирюза';
    if (hour < 10) return 'Утро · персик и розовый кварц';
    if (hour < 17) return 'День · сапфир и нефрит';
    if (hour < 22) return 'Вечер · аметист и янтарь';
    return 'Поздняя ночь · глубокий кобальт';
  }

  static String _seasonLabel(int month) {
    if (month == 12 || month <= 2) return 'Зима · резкие границы колец';
    if (month <= 5) return 'Весна · мягкие переливы';
    if (month <= 8) return 'Лето · тёплое ядро';
    return 'Осень · холодная корка';
  }

  static String _moonLabel(double phase) {
    if (phase < 0.03 || phase > 0.97) return 'Новолуние';
    if (phase < 0.22) return 'Молодая луна';
    if (phase < 0.28) return 'Первая четверть';
    if (phase < 0.47) return 'Растущая луна';
    if (phase < 0.53) return 'Полнолуние';
    if (phase < 0.72) return 'Убывающая луна';
    if (phase < 0.78) return 'Последняя четверть';
    return 'Старая луна';
  }
}
