import 'package:flutter/material.dart';

import '../agate/agate_view.dart';
import '../agate/genome.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../theme/palette.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: Palette.danger),
            child: const Text('УДАЛИТЬ'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: <Widget>[
              _StoneStage(createdAtMs: _user.createdAtMs),
              const SizedBox(height: 8),
              Text(
                _user.login,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 44),
              const Divider(),
              _Fact(label: 'Зрелость', value: '${passport.maturityPercent}%'),
              _Fact(label: 'Луна', value: passport.moonPhase),
              _Fact(label: 'Время суток', value: passport.timeOfDay),
              _Fact(label: 'Сезон', value: passport.season),
              _Fact(
                label: 'Редкость',
                value: passport.rarityLabel,
                accent: true,
              ),
              if (!passport.isPlain) ...<Widget>[
                _Fact(
                  label: 'Мутации',
                  value: passport.mutations.map((m) => m.title).join(' · '),
                ),
              ],
              const Divider(),
              const SizedBox(height: 32),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _rename,
                      child: const Text('Переименовать'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _changePassword,
                      child: const Text('Сменить пароль'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: accent ? Palette.accent : Palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Камень на едва заметном свечении: единственный визуальный акцент экрана.
class _StoneStage extends StatelessWidget {
  const _StoneStage({required this.createdAtMs});

  final int createdAtMs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 340,
            height: 340,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x1AFFFFFF), Color(0x00000000)],
              ),
            ),
          ),
          AgateView(
            createdAtMs: createdAtMs,
            size: 336,
            interactive: true,
          ),
        ],
      ),
    );
  }
}
