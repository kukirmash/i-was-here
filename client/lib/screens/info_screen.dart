import 'package:flutter/material.dart';

import '../agate/agate_view.dart';
import '../agate/genome.dart';
import '../agate/rarity.dart';
import '../theme/palette.dart';
import '../widgets/rarity_frame.dart';

/// Справочник: из чего складывается камень и какие у него бывают мутации.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  /// Декоративный образец: тот же генератор, но без привязки к пользователю.
  /// 2026-05-17T13:40Z.
  static const int _sampleMs = 1779025200000;

  /// Моменты, у камней которых ровно одна конкретная мутация.
  static const Map<String, int> _mutationSamples = <String, int>{
    MutationId.kintsugi: 1577838024680,
    MutationId.doubleGeode: 1577838943190,
    MutationId.mossDendrites: 1577837106170,
    MutationId.iridescence: 1577843719442,
    MutationId.eyeAgate: 1577858476836,
    MutationId.albino: 1577840290338,
    MutationId.obsidian: 1577836800000,
    MutationId.inclusion: 1577841453784,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            children: <Widget>[
              Text('СПРАВКА', style: theme.textTheme.labelSmall),
              const SizedBox(height: 16),
              Text('Как устроен камень', style: theme.textTheme.displaySmall),
              const SizedBox(height: 18),
              Text(
                'Срез строится только по времени регистрации и нигде не '
                'хранится: один и тот же момент всегда даёт один и тот же '
                'рисунок.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 36),
              const Center(
                child: AgateView(
                  createdAtMs: _sampleMs,
                  size: 190,
                  points: 130,
                  interactive: true,
                ),
              ),
              const SizedBox(height: 44),
              const Divider(),
              const SizedBox(height: 24),
              Text('01 — ОСНОВА', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              const _Row(label: 'Время суток', value: 'цвет: ночь — индиго, утро — персик, день — сапфир, вечер — аметист'),
              const _Row(label: 'Сезон', value: 'контраст и температура колец'),
              const _Row(label: 'Возраст', value: 'плотность: чем старше запись, тем теснее кольца'),
              const _Row(label: 'Луна', value: 'полнолуние включает молочный «Лунный кварц»'),
              const Divider(),
              const SizedBox(height: 24),
              Text('02 — МУТАЦИИ', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(
                'Шанс указан для одной мутации; признаки независимы, поэтому '
                'итоговая редкость перемножается.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...mutationCatalog.map((m) => _MutationRow(info: m)),
              const Divider(),
              const SizedBox(height: 24),
              Text('03 — РЕДКОСТЬ', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              Text(
                'Редкость камня — произведение шансов всех его мутаций. '
                'Один признак 5% — это «1 из 20», вместе с признаком 3% — '
                'уже «1 из 667». Камень без мутаций встречается чаще всего.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 18,
                children: <Widget>[
                  _RaritySample(createdAtMs: 1577838024680),
                  _RaritySample(createdAtMs: 1577837106170),
                  _RaritySample(createdAtMs: 1577843719442),
                  _RaritySample(createdAtMs: 1577836800000),
                  _RaritySample(createdAtMs: 1577841453784),
                  _RaritySample(createdAtMs: 1577857129688),
                  _RaritySample(createdAtMs: 1577847087312),
                  _RaritySample(createdAtMs: 1577847454716),
                  _RaritySample(createdAtMs: 1577856823518),
                  _RaritySample(createdAtMs: 1578315894816),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Десять уровней: от серого к зелёному, синему и золоту. '
                'С восьмого уровня камень светится, как LED, на десятом — '
                'сильнее всего.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _MutationRow extends StatelessWidget {
  const _MutationRow({required this.info});

  final MutationInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        children: <Widget>[
          AgateView(
            createdAtMs: InfoScreen._mutationSamples[info.id]!,
            size: 72,
            points: 90,
            interactive: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(info.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  info.description,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _oneIn(info.chance),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Palette.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(_percent(info.chance), style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

String _percent(double chance) {
  final percent = chance * 100;
  final text = percent >= 1
      ? percent.round().toString()
      : percent.toStringAsFixed(1).replaceAll('.', ',');
  return '$text%';
}

String _oneIn(double chance) {
  final n = (1 / chance).round();
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u2009');
    buffer.write(digits[i]);
  }
  return '1 из $buffer';
}

class _RaritySample extends StatelessWidget {
  const _RaritySample({required this.createdAtMs});

  final int createdAtMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passport = AgateGenome.fromTimestamp(createdAtMs).passport();
    final level = rarityLevel(passport);

    return SizedBox(
      width: 116,
      child: Column(
        children: <Widget>[
          RarityFrame(
            level: level,
            child: AgateView(
              createdAtMs: createdAtMs,
              size: 86,
              points: 90,
              interactive: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(passport.rarityLabel, style: theme.textTheme.labelSmall),
          Text(
            'уровень $level',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
