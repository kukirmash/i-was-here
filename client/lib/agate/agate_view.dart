import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'painter.dart';

/// Срез агата, детерминированно построенный по created_at пользователя.
///
/// Статический слой запечён в отдельный RepaintBoundary (аналог статического
/// буфера из раздела 6 спецификации), динамический перерисовывается только
/// при движении указателя и содержит блик, иризацию и вспышки кристаллов.
class AgateView extends StatefulWidget {
  const AgateView({
    super.key,
    required this.createdAtMs,
    required this.size,
    this.points = 180,
    this.interactive = true,
    this.now,
  });

  /// Unix timestamp в миллисекундах, UTC.
  final int createdAtMs;

  /// Сторона квадрата в логических пикселях.
  final double size;

  /// Густота контура: 180 для крупного просмотра, 60 для аватарок.
  final int points;

  final bool interactive;

  /// Фиксированное «сейчас» для тестов и снимков.
  final DateTime? now;

  @override
  State<AgateView> createState() => _AgateViewState();
}

class _AgateViewState extends State<AgateView>
    with SingleTickerProviderStateMixin {
  AgateArtwork? _artwork;
  late final Ticker _ticker;
  Offset _light = Offset.zero;
  Offset _target = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _load();
  }

  Future<void> _load() async {
    final artwork = await AgateArtwork.create(
      createdAtMs: widget.createdAtMs,
      points: widget.points,
      now: widget.now,
    );
    if (!mounted) return;
    setState(() => _artwork = artwork);
  }

  @override
  void didUpdateWidget(covariant AgateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createdAtMs != widget.createdAtMs ||
        oldWidget.points != widget.points ||
        oldWidget.now != widget.now) {
      _artwork = null;
      _load();
    }
  }

  void _onTick(Duration _) {
    final next = Offset.lerp(_light, _target, 0.12)!;
    final settled = (next - _target).distance < 0.001;
    _light = settled ? _target : next;
    if (settled) _ticker.stop();
    setState(() {});
  }

  void _moveTo(Offset local) {
    final half = widget.size / 2;
    if (half <= 0) return;
    _target = Offset(
      ((local.dx - half) / half).clamp(-1.0, 1.0),
      ((local.dy - half) / half).clamp(-1.0, 1.0),
    );
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artwork = _artwork;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final interactive = widget.interactive && !reducedMotion;

    if (artwork == null) {
      // Первый кадр до готовности генома: нейтральный силуэт без подписи.
      return SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(painter: _StaticAgatePainter(artwork)),
          ),
          if (interactive)
            MouseRegion(
              onHover: (event) => _moveTo(event.localPosition),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) => _moveTo(event.localPosition),
                onPointerMove: (event) => _moveTo(event.localPosition),
                child: CustomPaint(
                  painter: _DynamicAgatePainter(artwork, _light),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Маленький статичный срез для списков.
class AgateAvatar extends StatelessWidget {
  const AgateAvatar({
    super.key,
    required this.createdAtMs,
    this.size = 56,
  });

  final int createdAtMs;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AgateView(
      createdAtMs: createdAtMs,
      size: size,
      points: 60,
      interactive: false,
    );
  }
}

class _StaticAgatePainter extends CustomPainter {
  _StaticAgatePainter(this.artwork);

  final AgateArtwork artwork;

  @override
  void paint(Canvas canvas, Size size) => artwork.paintStatic(canvas, size);

  @override
  bool shouldRepaint(_StaticAgatePainter oldDelegate) =>
      oldDelegate.artwork != artwork;
}

class _DynamicAgatePainter extends CustomPainter {
  _DynamicAgatePainter(this.artwork, this.light);

  final AgateArtwork artwork;
  final Offset light;

  @override
  void paint(Canvas canvas, Size size) =>
      artwork.paintDynamic(canvas, size, light);

  @override
  bool shouldRepaint(_DynamicAgatePainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.artwork != artwork;
}
