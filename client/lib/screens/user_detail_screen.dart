import 'package:flutter/material.dart';

import '../agate/agate_view.dart';
import '../agate/genome.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../widgets/user_dialogs.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.api,
    required this.user,
  });

  final ApiClient api;
  final User user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late User _user = widget.user;

  Future<void> _rename() async {
    final updated = await showRenameUserDialog(context, widget.api, _user);
    if (updated != null && mounted) setState(() => _user = updated);
  }

  Future<void> _changePassword() async {
    final updated =
        await showChangePasswordDialog(context, widget.api, _user);
    if (updated != null && mounted) {
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль обновлён')),
      );
    }
  }

  Future<void> _delete() async {
    final deleted = await confirmDeleteUser(context, widget.api, _user);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final genome = AgateGenome.fromTimestamp(_user.createdAtMs);
    final passport = genome.passport();

    return Scaffold(
      appBar: AppBar(
        title: Text(_user.login),
        actions: <Widget>[
          IconButton(
            onPressed: _delete,
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          _StoneStage(createdAtMs: _user.createdAtMs),
          const SizedBox(height: 20),
          _PassportCard(passport: passport),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rename,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Переименовать'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Пароль'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Камень на мягком свечении: визуальный центр экрана.
class _StoneStage extends StatelessWidget {
  const _StoneStage({required this.createdAtMs});

  final int createdAtMs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x227E8DA8), Color(0x00000000)],
              ),
            ),
          ),
          AgateView(
            createdAtMs: createdAtMs,
            size: 320,
            interactive: true,
          ),
        ],
      ),
    );
  }
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({required this.passport});

  final AgatePassport passport;

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
          Row(
            children: <Widget>[
              Text('Паспорт камня', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                passport.rarityLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFD8C08A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _StatTile(
                label: 'Зрелость',
                value: '${passport.maturityPercent}%',
              ),
              const SizedBox(width: 10),
              _StatTile(label: 'Луна', value: passport.moonPhase),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _StatTile(label: 'Время', value: passport.timeOfDay),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _StatTile(label: 'Сезон', value: passport.season),
            ],
          ),
          const SizedBox(height: 16),
          if (passport.isPlain)
            Text(
              'Чистый камень без включений: так и должно быть.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: passport.mutations
                  .map(
                    (m) => Tooltip(
                      message: m.description,
                      child: Chip(label: Text(m.title)),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF272C35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Expanded(child: tile);
  }
}
