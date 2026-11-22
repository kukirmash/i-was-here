import 'package:flutter/material.dart';

import '../agate/agate_view.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../widgets/user_dialogs.dart';
import 'info_screen.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final List<User> _users = <User>[];
  int? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.listUsers();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(page.users);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.listUsers(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _users.addAll(page.users);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _snack(error.message);
    }
  }

  Future<void> _create() async {
    final created = await showCreateUserDialog(context, widget.api);
    if (created == null || !mounted) return;
    _snack('Пользователь ${created.login} создан');
    await _reload();
  }

  Future<void> _open(User user) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => UserDetailScreen(api: widget.api, user: user),
      ),
    );
    if (mounted) await _reload();
  }

  void _openInfo() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (context) => const InfoScreen()),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I Was Here'),
        actions: <Widget>[
          IconButton(
            onPressed: _openInfo,
            tooltip: 'Информация',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Новый камень'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return _MessageState(
        message: error,
        actionLabel: 'Повторить',
        onAction: _reload,
      );
    }

    if (_users.isEmpty) {
      return _MessageState(
        message: 'Здесь пока пусто.\nПервый камень появится после регистрации.',
        actionLabel: 'Создать камень',
        onAction: _create,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = _users[index];
                  return _UserCard(
                    user: user,
                    onTap: () => _open(user),
                  );
                },
                childCount: _users.length,
              ),
            ),
          ),
          if (_nextCursor != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: _loadMore,
                          child: const Text('Показать ещё'),
                        ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1A1E25), Color(0xFF12151A)],
        ),
        border: Border.all(color: const Color(0xFF2A2F38)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: AgateView(
                      createdAtMs: user.createdAtMs,
                      size: 150,
                      points: 120,
                      interactive: false,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.login,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: const Color(0xFFF1EEE7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.onAction,
    required this.actionLabel,
  });

  final String message;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
