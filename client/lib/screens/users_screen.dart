import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../agate/agate_view.dart';
import '../agate/genome.dart';
import '../agate/rarity.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../theme/palette.dart';
import '../widgets/rarity_frame.dart';
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
  final Map<int, AgatePassport> _passports = <int, AgatePassport>{};

  AgatePassport _passportFor(User user) => _passports.putIfAbsent(
        user.id,
        () => AgateGenome.fromTimestamp(user.createdAtMs).passport(),
      );

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
        _passports.clear();
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
        title: const Text('I WAS HERE'),
        actions: <Widget>[
          TextButton(
            onPressed: _openInfo,
            child: const Text('ИНФОРМАЦИЯ'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    final error = _error;
    if (error != null) {
      return _StateView(
        key: const ValueKey('error'),
        title: 'Не удалось загрузить',
        message: error,
        actionLabel: 'Повторить',
        onAction: _reload,
      );
    }

    if (_users.isEmpty) {
      return _StateView(
        key: const ValueKey('empty'),
        title: 'Пока пусто',
        message: 'Первый камень появится, когда кто-то зарегистрируется.',
        actionLabel: 'Создать камень',
        onAction: _create,
      );
    }

    return RefreshIndicator(
      key: const ValueKey('grid'),
      onRefresh: _reload,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          const horizontal = 24.0;
          final available = constraints.maxWidth - horizontal * 2;
          final columns = (available / 230).floor().clamp(2, 6);
          final itemWidth = (available - gap * (columns - 1)) / columns;
          final itemHeight = itemWidth / 0.72;

          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _Header(onCreate: _create)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontal),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final user in _users)
                        SizedBox(
                          width: itemWidth,
                          height: itemHeight,
                          child: _StonePlate(
                            user: user,
                            passport: _passportFor(user),
                            onTap: () => _open(user),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_nextCursor != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Center(
                      child: _loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 1.6),
                            )
                          : TextButton(
                              onPressed: _loadMore,
                              child: const Text('ПОКАЗАТЬ ЕЩЁ'),
                            ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      child: Column(
        children: <Widget>[
          Text(
            'Срез Агата',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge,
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Агат — слоистый халцедон: концентрические полосы, тонкие '
              'переливы и кристаллическая сердцевина. Каждый срез здесь '
              'рождается из момента регистрации и не повторяется.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Создать камень'),
          ),
        ],
      ),
    );
  }
}

class _StonePlate extends StatefulWidget {
  const _StonePlate({
    required this.user,
    required this.passport,
    required this.onTap,
  });

  final User user;
  final AgatePassport passport;
  final VoidCallback onTap;

  @override
  State<_StonePlate> createState() => _StonePlateState();
}

class _StonePlateState extends State<_StonePlate> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = rarityLevel(widget.passport);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: RarityFrame(
          level: level,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        math.min(constraints.maxWidth, constraints.maxHeight) *
                            0.92;
                    final size = side.clamp(56.0, 190.0).toDouble();
                    return Center(
                      child: AnimatedScale(
                        scale: _hover ? 1.035 : 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AgateView(
                          createdAtMs: widget.user.createdAtMs,
                          size: size,
                          points: 120,
                          interactive: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: theme.textTheme.labelLarge!.copyWith(
                  color: _hover ? Palette.accent : Palette.body,
                ),
                child: Text(
                  widget.user.login,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 26),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
