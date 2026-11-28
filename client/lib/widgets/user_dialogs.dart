import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/user.dart';
import '../theme/palette.dart';

/// Одна форма на все три сценария: создание, переименование, смена пароля.
/// Поля, которых нет в сценарии, не показываются и не отправляются.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    super.key,
    required this.title,
    required this.showLogin,
    required this.showPassword,
    required this.onSubmit,
    this.initialLogin,
    this.submitLabel = 'Сохранить',
  });

  final String title;
  final bool showLogin;
  final bool showPassword;
  final String? initialLogin;
  final String submitLabel;

  /// Возвращает обновлённого пользователя либо бросает [ApiException].
  final Future<User> Function(String login, String password) onSubmit;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _login =
      TextEditingController(text: widget.initialLogin ?? '');
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.onSubmit(_login.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (widget.showLogin)
                  TextFormField(
                    controller: _login,
                    autofocus: widget.showLogin,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      helperText: '3–32 символа, без пробелов по краям',
                    ),
                    validator: validateLogin,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                if (widget.showLogin && widget.showPassword)
                  const SizedBox(height: 14),
                if (widget.showPassword)
                  TextFormField(
                    controller: _password,
                    autofocus: !widget.showLogin,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      helperText: '8–64 символа, не длиннее 72 байт',
                    ),
                    validator: (value) => validatePassword(value),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Palette.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('ОТМЕНА'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel.toUpperCase()),
        ),
      ],
    );
  }
}

Future<User?> showCreateUserDialog(BuildContext context, ApiClient api) {
  return showDialog<User>(
    context: context,
    builder: (context) => UserFormDialog(
      title: 'Новый камень',
      showLogin: true,
      showPassword: true,
      submitLabel: 'Создать',
      onSubmit: (login, password) =>
          api.createUser(login: login, password: password),
    ),
  );
}

Future<User?> showRenameUserDialog(
  BuildContext context,
  ApiClient api,
  User user,
) {
  return showDialog<User>(
    context: context,
    builder: (context) => UserFormDialog(
      title: 'Переименовать',
      showLogin: true,
      showPassword: false,
      initialLogin: user.login,
      onSubmit: (login, _) => api.updateUser(user.id, login: login),
    ),
  );
}

Future<User?> showChangePasswordDialog(
  BuildContext context,
  ApiClient api,
  User user,
) {
  return showDialog<User>(
    context: context,
    builder: (context) => UserFormDialog(
      title: 'Новый пароль',
      showLogin: false,
      showPassword: true,
      submitLabel: 'Сменить пароль',
      onSubmit: (_, password) => api.updateUser(user.id, password: password),
    ),
  );
}

/// true — пользователь удалён.
Future<bool> confirmDeleteUser(
  BuildContext context,
  ApiClient api,
  User user,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('Удалить камень?'),
      content: SizedBox(
        width: 420,
        child: Text(
          '${user.login} исчезнет безвозвратно: запись удаляется из базы '
          'физически, восстановить её будет нельзя.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ОТМЕНА'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.danger,
            foregroundColor: const Color(0xFF23100F),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('УДАЛИТЬ'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await api.deleteUser(user.id);
    return true;
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
    return false;
  }
}
