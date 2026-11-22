import 'package:flutter/material.dart';

import '../agate/genome.dart';

/// Справочник: из чего складывается камень и какие у него бывают мутации.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Информация')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _Section(
            title: 'Как читается камень',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Срез агата строится только по времени регистрации и не '
                  'хранится на сервере: у одного и того же момента всегда '
                  'получается один и тот же камень.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const _Hint(
                  title: 'Время суток',
                  text: 'Задаёт базовый тон: ночь — индиго, утро — персик, '
                      'день — сапфир, вечер — аметист.',
                ),
                const _Hint(
                  title: 'Сезон',
                  text: 'Меняет контраст и температуру колец.',
                ),
                const _Hint(
                  title: 'Возраст',
                  text: 'Чем старше запись, тем плотнее сходятся кольца.',
                ),
                const _Hint(
                  title: 'Луна',
                  text: 'Полнолуние делает камень молочным: включается '
                      '«Лунный кварц».',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Мутации',
            subtitle: 'Редкость указана для одной мутации. Встречаются '
                'одновременно, поэтому итоговая редкость перемножается.',
            child: Column(
              children: mutationCatalog
                  .map(
                    (m) => _MutationTile(
                      title: m.title,
                      description: m.description,
                      chance: m.chance,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Редкость',
            child: Text(
              'Шанс камня — произведение шансов всех его мутаций. '
              'Один признак 5% — это 1 из 20, а вместе с признаком 3% — '
              'уже 1 из 667. Камень без мутаций встречается чаще всего.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1A1E25), Color(0xFF12151A)],
        ),
        border: Border.all(color: const Color(0xFF2A2F38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD8C08A),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: <TextSpan>[
                  TextSpan(
                    text: '$title. ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutationTile extends StatelessWidget {
  const _MutationTile({
    required this.title,
    required this.description,
    required this.chance,
  });

  final String title;
  final String description;
  final double chance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14171D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF272C35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _oneIn(chance),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFD8C08A),
                ),
              ),
              Text(
                _percent(chance),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
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
