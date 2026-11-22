import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'genome.dart';
import 'geometry.dart';
import 'prng.dart';

/// Цветовые правила: базовый тон, сезон, зрелость и мутации палитры.
/// Все значения детерминированы — никаких случайных чисел здесь не нужно.
class _Palette {
  _Palette(this.g);

  final AgateGenome g;

  Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(
        1,
        (h % 360 + 360) % 360,
        s.clamp(0.0, 1.0),
        l.clamp(0.0, 1.0),
      ).toColor();

  Color crust() {
    final hue = g.baseHue + 10;
    if (g.isAlbino) return _hsl(hue, 0.05, 0.84);
    if (g.isObsidian) return _hsl(hue, 0.16, 0.07);
    return _hsl(hue, 0.18, 0.14);
  }

  Color crustEdge() {
    if (g.isAlbino) return _hsl(g.baseHue, 0.04, 0.95);
    if (g.isObsidian) return _hsl(g.baseHue + 30, 0.22, 0.16);
    return _hsl(g.baseHue + 20, 0.28, 0.22);
  }

  Color ring(int index, int count, double depth, {required bool milky}) {
    final t = count <= 1 ? 0.0 : index / (count - 1);
    final hue = g.baseHue + g.hueSpread * (t - 0.5) + math.sin(index * 1.7) * 6;

    if (g.isAlbino) {
      final l = milky ? 0.93 : 0.70 + 0.12 * t;
      return _hsl(hue, 0.03 + 0.03 * t, l);
    }
    if (g.isObsidian) {
      final l = milky ? 0.13 : 0.04 + 0.06 * t;
      return _hsl(hue, 0.08 + 0.08 * t, l);
    }

    final contrast = g.layerContrast;
    final l = milky
        ? 0.60 + 0.20 * contrast
        : 0.48 - 0.22 * contrast + 0.12 * t;
    final s = 0.42 + 0.18 * (1 - t);
    return _hsl(hue, s, l);
  }

  Color sugar() => g.isAlbino
      ? _hsl(g.baseHue, 0.02, 0.97)
      : _hsl(g.baseHue + 20, 0.08, 0.92);

  Color crystal(double brightness) => _hsl(
        g.baseHue + 35,
        g.isAlbino ? 0.02 : 0.10,
        0.58 + 0.34 * brightness,
      );

  Color gold() => _hsl(44, 0.75, 0.55);
  Color goldLight() => _hsl(52, 0.95, 0.80);
  Color crack() => _hsl(g.baseHue, 0.25, 0.10);
  Color moss() => _hsl(96, 0.36, 0.30);
  Color neon() => _hsl(18, 0.95, 0.60);
  Color inclusion() => g.isAlbino ? _hsl(0, 0, 0.92) : _hsl(48, 0.55, 0.72);
}

/// Готовая картинка камня: геном, геометрия и запечённые пути.
///
/// Статический слой рисуется один раз в отдельном RepaintBoundary — это и
/// есть буфер из раздела 6 спецификации: Flutter кэширует его как текстуру,
/// поэтому 60 FPS динамики не пересчитывают кольца и кристаллы.
class AgateArtwork {
  AgateArtwork(this.genome, this.geometry)
      : _palette = _Palette(genome),
        outerPath = _stonePath(geometry),
        crustPath = agateSmoothPath(geometry.crustInner),
        innerPath = agateSmoothPath(geometry.inner);

  static Future<AgateArtwork> create({
    required int createdAtMs,
    int points = 180,
    DateTime? now,
  }) async {
    final genome = AgateGenome.fromTimestamp(createdAtMs, now: now);
    final geometry = buildAgateGeometry(genome, points: points);
    return AgateArtwork(genome, geometry);
  }

  final AgateGenome genome;
  final AgateGeometry geometry;
  final _Palette _palette;

  final Path outerPath;
  final Path crustPath;
  final Path innerPath;

  late final List<Offset> _midRing = _ringNear(0.70);
  late final List<Offset> _innerRing = _ringNear(0.25);
  late final List<Offset> _accentRing = _ringNear(0.65);

  List<Offset> _ringNear(double depth) {
    final rings = geometry.rings;
    if (rings.isEmpty) return geometry.crustInner;
    var best = rings.first;
    for (final ring in rings) {
      if ((ring.depth - depth).abs() < (best.depth - depth).abs()) best = ring;
    }
    return best.points;
  }

  /// Полный статический слой (раздел 5).
  void paintStatic(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 * 0.92;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(radius);

    _paintShadow(canvas);
    _paintCrust(canvas);
    _paintRings(canvas);
    _paintGeode(canvas);
    _paintMoss(canvas);
    _paintKintsugi(canvas);
    _paintAccent(canvas);
    _paintInclusion(canvas);

    canvas.restore();
  }

  void _paintShadow(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(120)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.06);
    canvas.drawPath(outerPath.shift(const Offset(0.02, 0.05)), paint);
  }

  void _paintCrust(Canvas canvas) {
    canvas.drawPath(outerPath, Paint()..color = _palette.crust());

    // Сырая порода у края: неровная кромка шириной 3–5 % радиуса.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round
      ..color = _palette.crustEdge().withAlpha(150);
    canvas.drawPath(crustPath, edge);
  }

  void _paintRings(Canvas canvas) {
    canvas.save();
    canvas.clipPath(crustPath);

    canvas.drawPath(crustPath, Paint()..color = _palette.crust());

    final rings = geometry.rings;
    final center = Offset(genome.geodeShiftX, genome.geodeShiftY);
    final ringCount = rings.length;

    for (var i = 0; i < ringCount; i++) {
      final ring = rings[i];
      final path = agateSmoothPath(ring.points);
      final milky = i.isEven;
      final color = _palette.ring(i, ringCount, ring.depth, milky: milky);

      final inner = Color.lerp(color, _palette.crust(), 0.35)!;
      final alpha = milky ? 140 : 255;
      final fill = Paint()
        ..shader = ui.Gradient.radial(
          center,
          1.15,
          <Color>[inner.withAlpha(alpha), color.withAlpha(alpha)],
          const <double>[0.0, 1.0],
        )
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;

      canvas.drawPath(path, fill);

      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.0018
        ..color = Colors.white.withAlpha(milky ? 26 : 36);
      canvas.drawPath(path, line);
    }

    _paintNoise(canvas);
    canvas.restore();
  }

  void _paintNoise(Canvas canvas) {
    // Мелкий монохромный минеральный шум (overlay, ~6 %). Рисуется один раз
    // вместе с кольцами; детерминирован по соли v1:tex.
    final rnd = AgateRandom(agateSeed(genome.createdAtMs, 'v1:tex'));
    final light = Paint()
      ..blendMode = BlendMode.overlay
      ..color = Colors.white.withAlpha(16);
    final dark = Paint()
      ..blendMode = BlendMode.overlay
      ..color = Colors.black.withAlpha(14);

    for (var i = 0; i < 700; i++) {
      final angle = rnd.range(0, 2 * math.pi);
      final distance = math.sqrt(rnd.next()) * 0.95;
      final p = Offset(
        math.cos(angle) * distance * genome.squeezeX,
        math.sin(angle) * distance,
      );
      final size = rnd.range(0.0015, 0.0045);
      canvas.drawRect(
        Rect.fromCenter(center: p, width: size, height: size),
        rnd.next() < 0.55 ? light : dark,
      );
    }
  }

  void _paintGeode(Canvas canvas) {
    _paintGeodeAt(canvas, geometry.inner, geometry.faces,
        Offset(genome.geodeShiftX, genome.geodeShiftY));

    final twin = geometry.twinInner;
    if (twin != null) {
      _paintGeodeAt(
        canvas,
        twin,
        geometry.twinFaces,
        _centroid(twin),
      );
    }

    if (geometry.eyeRays.isNotEmpty) {
      canvas.save();
      canvas.clipPath(innerPath);
      for (final ray in geometry.eyeRays) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ray.width
          ..color = Colors.white.withAlpha((ray.opacity * 255).round());
        canvas.drawLine(ray.from, ray.to, paint);
      }
      canvas.restore();
    }
  }

  void _paintGeodeAt(
    Canvas canvas,
    List<Offset> contour,
    List<CrystalFace> faces,
    Offset center,
  ) {
    final rim = _sugarRim(contour, center);
    final rimPath = agateSmoothPath(rim);

    canvas.drawPath(rimPath, Paint()..color = _palette.sugar());

    canvas.save();
    canvas.clipPath(agateSmoothPath(contour));

    for (final face in faces) {
      final path = Path()..addPolygon(face.polygon, true);
      canvas.drawPath(path, Paint()..color = _palette.crystal(face.brightness));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.0012
          ..color = Colors.white.withAlpha(40),
      );
    }

    final glow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        genome.geodeRadius,
        <Color>[Colors.white.withAlpha(60), Colors.white.withAlpha(0)],
      );
    canvas.drawCircle(center, genome.geodeRadius, glow);
    canvas.restore();
  }

  /// Зубчатая кромка «сахарного кварца»: мелкая высокочастотная волна.
  List<Offset> _sugarRim(List<Offset> contour, Offset center) {
    final k = 28 + (genome.roughness * 100).round() % 15;
    return contour.map((p) {
      final v = p - center;
      final angle = math.atan2(v.dy, v.dx);
      final factor = 1 + 0.015 * math.sin(k * angle + genome.rotation);
      return center + v * factor;
    }).toList(growable: false);
  }

  void _paintKintsugi(Canvas canvas) {
    if (!genome.has(MutationId.kintsugi)) return;

    final rnd = AgateRandom(agateSeed(genome.createdAtMs, 'v1:draw:kintsugi'));
    final rays = rnd.nextInt(2, 4);

    canvas.save();
    canvas.clipPath(outerPath);

    for (var r = 0; r < rays; r++) {
      final start = geometry.outer[rnd.index(geometry.outer.length)];
      final points = <Offset>[start];
      var point = start;
      var guard = 0;
      while (point.distance > 0.15 && guard++ < 40) {
        final toCenter = -point;
        final length = toCenter.distance;
        if (length == 0) break;
        final direction = _rotate(toCenter / length, rnd.range(-0.55, 0.55));
        point += direction * rnd.range(0.04, 0.09);
        points.add(point);
      }

      _strokePolyline(canvas, points, 0.010, _palette.crack().withAlpha(200));
      _strokePolyline(canvas, points, 0.006, _palette.gold());
      _strokePolyline(
        canvas,
        points.map((p) => p - const Offset(0.0012, 0.0012)).toList(),
        0.0022,
        _palette.goldLight(),
      );
    }
    canvas.restore();
  }

  void _paintMoss(Canvas canvas) {
    if (!genome.has(MutationId.mossDendrites)) return;

    final rnd = AgateRandom(agateSeed(genome.createdAtMs, 'v1:draw:moss'));
    final starts = rnd.nextInt(4, 8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _palette.moss().withAlpha(120)
      ..blendMode = BlendMode.multiply;

    canvas.save();
    canvas.clipPath(agateSmoothPath(_innerRing));

    for (var i = 0; i < starts; i++) {
      final anchor = _midRing[rnd.index(_midRing.length)];
      final angle = rnd.range(0, 2 * math.pi);
      _dendrite(canvas, paint, anchor, angle, rnd.range(0.14, 0.24), 4, rnd);
    }
    canvas.restore();
  }

  void _dendrite(
    Canvas canvas,
    Paint paint,
    Offset point,
    double angle,
    double length,
    int depth,
    AgateRandom rnd,
  ) {
    if (depth <= 0 || length < 0.01) return;

    final end = point + Offset(math.cos(angle), math.sin(angle)) * length;
    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..strokeWidth = depth * 0.0016;
    canvas.drawLine(point, end, branch);

    final branches = rnd.nextInt(2, 3);
    for (var i = 0; i < branches; i++) {
      _dendrite(
        canvas,
        paint,
        end,
        angle + rnd.range(-0.65, 0.65),
        length * rnd.range(0.55, 0.78),
        depth - 1,
        rnd,
      );
    }
  }

  void _paintAccent(Canvas canvas) {
    if (!genome.isObsidian || _accentRing.length < 3) return;

    final path = agateSmoothPath(_accentRing);
    canvas.save();
    canvas.clipPath(outerPath);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..color = _palette.neon().withAlpha(120)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.012)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, glow);

    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.003
      ..color = _palette.neon().withAlpha(230)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, core);
    canvas.restore();
  }

  void _paintInclusion(Canvas canvas) {
    final point = geometry.inclusionPoint;
    if (point == null) return;

    switch (geometry.inclusionKind) {
      case 0: // воздушный пузырёк
        canvas.drawCircle(
          point,
          0.022,
          Paint()..color = _palette.inclusion().withAlpha(90),
        );
        canvas.drawCircle(
          point - const Offset(0.006, 0.007),
          0.006,
          Paint()..color = Colors.white.withAlpha(170),
        );
        canvas.drawCircle(
          point,
          0.022,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.0015
            ..color = Colors.white.withAlpha(120),
        );
      case 1: // золотой октаэдр
        final polygon = <Offset>[
          point + const Offset(0, -0.028),
          point + const Offset(0.020, 0),
          point + const Offset(0, 0.028),
          point + const Offset(-0.020, 0),
        ];
        canvas.drawPath(
          Path()..addPolygon(polygon, true),
          Paint()..color = _palette.gold().withAlpha(220),
        );
        canvas.drawPath(
          Path()
            ..addPolygon(
              <Offset>[polygon[0], point, polygon[3]],
              true,
            ),
          Paint()..color = _palette.goldLight().withAlpha(200),
        );
      default: // геометрическая руна
        final rune = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.0035
          ..strokeCap = StrokeCap.round
          ..color = _palette.inclusion().withAlpha(220);
        canvas.drawLine(
          point + const Offset(-0.016, -0.016),
          point + const Offset(0.016, 0.016),
          rune,
        );
        canvas.drawLine(
          point + const Offset(0.016, -0.016),
          point + const Offset(-0.016, 0.016),
          rune,
        );
        canvas.drawLine(
          point + const Offset(0, -0.018),
          point + const Offset(0, 0.018),
          rune,
        );
    }
  }

  /// Динамический слой (раздел 6): блик, иризация и вспышки кристаллов.
  void paintDynamic(Canvas canvas, Size size, Offset light) {
    final radius = math.min(size.width, size.height) / 2 * 0.92;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(radius);
    canvas.clipPath(outerPath);

    _paintGlint(canvas, light);
    _paintIridescence(canvas, light);
    _paintSparks(canvas, light);

    canvas.restore();
  }

  void _paintGlint(Canvas canvas, Offset light) {
    final intensity = 0.10 + 0.16 * genome.ageFactor;
    final center = light * 0.45;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        0.8,
        <Color>[
          Colors.white.withAlpha((intensity * 255).round()),
          Colors.white.withAlpha(0),
        ],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, 0.8, paint);
  }

  void _paintIridescence(Canvas canvas, Offset light) {
    if (!genome.has(MutationId.iridescence)) return;

    final startAngle = math.atan2(light.dy, light.dx);
    final colors = <Color>[
      const Color(0x40FF5E7A),
      const Color(0x40FFC95E),
      const Color(0x4068FF9B),
      const Color(0x405E9BFF),
      const Color(0x40B45EFF),
      const Color(0x40FF5E7A),
    ];
    final paint = Paint()
      ..shader = ui.Gradient.sweep(
        const Offset(0, 0),
        colors,
        null,
        ui.TileMode.clamp,
        startAngle,
        startAngle + 2 * math.pi,
      )
      ..blendMode = BlendMode.colorDodge;

    canvas.save();
    canvas.clipPath(agateSmoothPath(_midRing));
    canvas.drawCircle(Offset.zero, 1.0, paint);
    canvas.restore();
  }

  void _paintSparks(Canvas canvas, Offset light) {
    final length =
        math.sqrt(light.dx * light.dx + light.dy * light.dy + 0.85 * 0.85);
    if (length == 0) return;
    final lx = light.dx / length;
    final ly = light.dy / length;
    final lz = 0.85 / length;

    final paint = Paint()..blendMode = BlendMode.plus;

    void sparkle(CrystalFace face) {
      final scalar = math.max(0.0, face.nx * lx + face.ny * ly + face.nz * lz);
      final flash = math.pow(scalar, 6).toDouble();
      if (flash <= 0.08) return;
      paint.color = Colors.white.withAlpha((flash * 0.65 * 255).round());
      canvas.drawPath(Path()..addPolygon(face.polygon, true), paint);
    }

    // Блики обеих жеод: иначе задняя остаётся матовой при любом свете.
    for (final face in geometry.faces) {
      sparkle(face);
    }
    for (final face in geometry.twinFaces) {
      sparkle(face);
    }
  }
}

Path agateSmoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  if (points.length < 3) {
    path.addPolygon(points, true);
    return path;
  }

  final start = (points.last + points.first) / 2;
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < points.length; i++) {
    final current = points[i];
    final next = points[(i + 1) % points.length];
    final end = (current + next) / 2;
    path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

Path _stonePath(AgateGeometry geometry) {
  final main = agateSmoothPath(geometry.outer);
  final twin = geometry.twinOuter;
  if (twin == null) return main;
  return Path.combine(PathOperation.union, main, agateSmoothPath(twin));
}

void _strokePolyline(
  Canvas canvas,
  List<Offset> points,
  double width,
  Color color,
) {
  if (points.length < 2) return;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  canvas.drawPath(path, paint);
}

Offset _rotate(Offset v, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

Offset _centroid(List<Offset> points) {
  var x = 0.0;
  var y = 0.0;
  for (final p in points) {
    x += p.dx;
    y += p.dy;
  }
  return Offset(x / points.length, y / points.length);
}
