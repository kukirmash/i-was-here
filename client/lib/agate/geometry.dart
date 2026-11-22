import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'genome.dart';
import 'prng.dart';

/// Точка контура в нормализованных координатах: камень описывается в
/// квадрате [-1, 1], центр — в (0, 0), радиус — 1.
typedef AgatePoint = Offset;

class AgateRing {
  const AgateRing(this.points, this.depth);

  final List<AgatePoint> points;

  /// 0.0 — у края, ближе к 1.0 — у полости. Строго возрастает.
  final double depth;
}

class CrystalFace {
  const CrystalFace({
    required this.polygon,
    required this.nx,
    required this.ny,
    required this.nz,
    required this.brightness,
  });

  final List<AgatePoint> polygon;
  final double nx;
  final double ny;
  final double nz;
  final double brightness;
}

class AgateRay {
  const AgateRay(this.from, this.to, this.width, this.opacity);

  final AgatePoint from;
  final AgatePoint to;
  final double width;
  final double opacity;
}

/// Вся геометрия камня. Строится один раз и не зависит от размера холста:
/// painter только масштабирует нормализованные координаты.
class AgateGeometry {
  const AgateGeometry({
    required this.outer,
    required this.crustInner,
    required this.inner,
    required this.rings,
    required this.faces,
    required this.twinOuter,
    required this.twinInner,
    required this.twinFaces,
    required this.eyeRays,
    required this.inclusionPoint,
    required this.inclusionKind,
  });

  final List<AgatePoint> outer;

  /// 95 % от внешнего контура — граница корки и минеральных колец.
  final List<AgatePoint> crustInner;

  /// Контур кристаллической полости.
  final List<AgatePoint> inner;

  final List<AgateRing> rings;
  final List<CrystalFace> faces;

  /// Второй лепесток камня для double_geode.
  final List<AgatePoint>? twinOuter;

  /// Вторая полость для double_geode.
  final List<AgatePoint>? twinInner;
  final List<CrystalFace> twinFaces;

  final List<AgateRay> eyeRays;
  final AgatePoint? inclusionPoint;
  final int inclusionKind;

  bool get hasTwin => twinInner != null;
}

AgateGeometry buildAgateGeometry(AgateGenome genome, {int points = 180}) {
  final m = points < 24 ? 24 : points;
  final outer = _outerContour(genome, m);
  final crustInner = _scaled(outer, 0.95);

  final geodeCenter = Offset(genome.geodeShiftX, genome.geodeShiftY);
  final inner = genome.has(MutationId.eyeAgate)
      ? _circle(geodeCenter, genome.geodeRadius, m)
      : _innerContour(outer, geodeCenter, genome.geodeRadius);

  final geode = AgateRandom(agateSeed(genome.createdAtMs, 'v1:geode'));
  final faces = _crystalFaces(inner, geode);

  List<AgatePoint>? twinOuter;
  List<AgatePoint>? twinInner;
  var twinFaces = const <CrystalFace>[];
  if (genome.has(MutationId.doubleGeode) &&
      genome.twinAngle != null &&
      genome.twinDistance != null) {
    final dir = Offset(math.cos(genome.twinAngle!), math.sin(genome.twinAngle!));
    final shift = dir * (genome.twinDistance! / 2);
    twinOuter = outer
        .map((p) => geodeCenter + shift + p * 0.8)
        .toList(growable: false);
    twinInner = genome.has(MutationId.eyeAgate)
        ? _circle(geodeCenter + shift, genome.geodeRadius * 0.8, m)
        : _innerContour(outer, geodeCenter + shift, genome.geodeRadius * 0.8);
    twinFaces = _crystalFaces(twinInner, geode);
  }

  final ringStream = AgateRandom(agateSeed(genome.createdAtMs, 'v1:ring'));
  final rings = _rings(
    genome,
    crustInner,
    inner,
    twinInner,
    ringStream,
  );

  final eyeRays = <AgateRay>[];
  if (genome.has(MutationId.eyeAgate)) {
    final eye = AgateRandom(agateSeed(genome.createdAtMs, 'v1:eye'));
    final count = eye.nextInt(45, 65);
    for (var i = 0; i < count; i++) {
      final angle = eye.range(0, 2 * math.pi);
      final length = genome.geodeRadius * eye.range(0.35, 0.95);
      eyeRays.add(
        AgateRay(
          geodeCenter,
          geodeCenter + Offset(math.cos(angle), math.sin(angle)) * length,
          eye.range(0.0015, 0.004),
          eye.range(0.10, 0.35),
        ),
      );
    }
  }

  Offset? inclusionPoint;
  var inclusionKind = 0;
  if (genome.has(MutationId.inclusion) && rings.isNotEmpty) {
    final incl = AgateRandom(agateSeed(genome.createdAtMs, 'v1:incl'));
    inclusionKind = incl.nextInt(0, 2);
    // Точка на кольце глубиной около 0.65 — там полупрозрачные слои её скроют.
    var index = 0;
    for (var i = 1; i < rings.length; i++) {
      if ((rings[i].depth - 0.65).abs() < (rings[index].depth - 0.65).abs()) {
        index = i;
      }
    }
    final contour = rings[index].points;
    inclusionPoint = contour[incl.index(contour.length)];
  }

  return AgateGeometry(
    outer: outer,
    crustInner: crustInner,
    inner: inner,
    rings: rings,
    faces: faces,
    twinOuter: twinOuter,
    twinInner: twinInner,
    twinFaces: twinFaces,
    eyeRays: eyeRays,
    inclusionPoint: inclusionPoint,
    inclusionKind: inclusionKind,
  );
}

/// Полярный ряд Фурье с защитой от самопересечений (раздел 4.1).
List<AgatePoint> _outerContour(AgateGenome genome, int m) {
  var sum = 0.0;
  for (final h in genome.harmonics) {
    sum += h.amplitude.abs();
  }
  final clamp = sum > 0.30 ? 0.30 / sum : 1.0;

  final cosR = math.cos(genome.rotation);
  final sinR = math.sin(genome.rotation);
  final points = <AgatePoint>[];

  for (var i = 0; i < m; i++) {
    final angle = i / m * 2 * math.pi;
    var radius = 1.0;
    for (final h in genome.harmonics) {
      radius += h.amplitude * clamp * math.cos(h.k * angle + h.phase);
    }
    final x = radius * math.cos(angle) * genome.squeezeX;
    final y = radius * math.sin(angle);
    points.add(Offset(x * cosR - y * sinR, x * sinR + y * cosR));
  }
  return points;
}

/// Контур полости повторяет силуэт камня, сжатый к центру жеоды.
List<AgatePoint> _innerContour(
  List<AgatePoint> outer,
  Offset center,
  double radius,
) {
  final points = <AgatePoint>[];
  for (final p in outer) {
    final v = p - center;
    final length = v.distance;
    if (length < 0.05) {
      points.add(center + Offset(radius, 0));
    } else {
      points.add(center + v * (radius / length));
    }
  }
  return points;
}

List<AgatePoint> _circle(Offset center, double radius, int m) {
  return List<AgatePoint>.generate(m, (i) {
    final angle = i / m * 2 * math.pi;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  });
}

List<AgatePoint> _scaled(List<AgatePoint> points, double k) =>
    points.map((p) => p * k).toList(growable: false);

/// Кольца через монотонную интерполяцию внешнего контура и полости
/// (раздел 4.2): по построению они не пересекаются.
List<AgateRing> _rings(
  AgateGenome genome,
  List<AgatePoint> from,
  List<AgatePoint> to,
  List<AgatePoint>? twin,
  AgateRandom rnd,
) {
  final count = genome.visibleRings;
  final weights = List<double>.generate(count, (_) {
    final r = rnd.next();
    return 0.15 + r * r * 1.4;
  });
  var total = 0.0;
  for (final w in weights) {
    total += w;
  }

  final rings = <AgateRing>[];
  var accumulated = 0.0;
  for (var i = 0; i < count; i++) {
    final progress = total == 0 ? 0.0 : accumulated / total;
    final target = twin == null ? to : _combinedInner(to, twin);
    final contour = <AgatePoint>[];
    for (var j = 0; j < from.length; j++) {
      contour.add(Offset.lerp(from[j], target[j], progress)!);
    }
    rings.add(AgateRing(contour, progress));
    accumulated += weights[i];
  }
  return rings;
}

/// Общая внутренняя граница двух полостей: по каждому углу берём более
/// удалённую от центра точку — так кольца охватывают оба центра.
List<AgatePoint> _combinedInner(List<AgatePoint> a, List<AgatePoint> b) {
  return List<AgatePoint>.generate(a.length, (i) {
    return a[i].distanceSquared >= b[i].distanceSquared ? a[i] : b[i];
  });
}

/// Кристаллические грани: семена + мозаика Вороного, обрезанная по полости
/// (раздел 4.3). Порядок обращений к потоку фиксирован: сначала семена,
/// затем нормали и яркость каждой грани.
List<CrystalFace> _crystalFaces(List<AgatePoint> region, AgateRandom rnd) {
  final seedsCount = rnd.nextInt(18, 34);
  final seeds = _uniformPoints(region, seedsCount, rnd);
  final cells = _voronoi(region, seeds);

  final faces = <CrystalFace>[];
  for (final cell in cells) {
    final nx = rnd.range(-0.75, 0.75);
    final ny = rnd.range(-0.75, 0.75);
    final nz = math.sqrt(math.max(0.1, 1.0 - nx * nx - ny * ny));
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    faces.add(
      CrystalFace(
        polygon: cell,
        nx: nx / length,
        ny: ny / length,
        nz: nz / length,
        brightness: rnd.range(0.55, 0.95),
      ),
    );
  }
  return faces;
}

List<AgatePoint> _uniformPoints(
  List<AgatePoint> region,
  int count,
  AgateRandom rnd,
) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in region) {
    if (p.dx < minX) minX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy > maxY) maxY = p.dy;
  }

  final points = <AgatePoint>[];
  var attempts = 0;
  final limit = count * 60;
  while (points.length < count && attempts < limit) {
    attempts++;
    final p = Offset(
      rnd.range(minX, maxX),
      rnd.range(minY, maxY),
    );
    if (_inside(p, region)) points.add(p);
  }
  while (points.length < count) {
    // Страховка для узких контуров: дублируем центр.
    points.add(Offset((minX + maxX) / 2, (minY + maxY) / 2));
  }
  return points;
}

List<List<AgatePoint>> _voronoi(
  List<AgatePoint> region,
  List<AgatePoint> seeds,
) {
  final cells = <List<AgatePoint>>[];
  for (var i = 0; i < seeds.length; i++) {
    var polygon = region;
    final si = seeds[i];
    for (var j = 0; j < seeds.length && polygon.isNotEmpty; j++) {
      if (i == j) continue;
      final sj = seeds[j];
      final nx = sj.dx - si.dx;
      final ny = sj.dy - si.dy;
      final mx = (si.dx + sj.dx) / 2;
      final my = (si.dy + sj.dy) / 2;
      polygon = _clipHalfPlane(polygon, nx, ny, nx * mx + ny * my);
    }
    if (polygon.length >= 3) cells.add(polygon);
  }
  return cells;
}

/// Оставляет часть полигона, где nx*x + ny*y <= c (Сазерленд — Ходжман).
List<AgatePoint> _clipHalfPlane(
  List<AgatePoint> polygon,
  double nx,
  double ny,
  double c,
) {
  final result = <AgatePoint>[];
  for (var i = 0; i < polygon.length; i++) {
    final current = polygon[i];
    final next = polygon[(i + 1) % polygon.length];
    final dc = nx * current.dx + ny * current.dy - c;
    final dn = nx * next.dx + ny * next.dy - c;

    if (dc <= 0) result.add(current);
    if ((dc < 0 && dn > 0) || (dc > 0 && dn < 0)) {
      final t = dc / (dc - dn);
      result.add(Offset.lerp(current, next, t)!);
    }
  }
  return result;
}

bool _inside(AgatePoint point, List<AgatePoint> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects = (pi.dy > point.dy) != (pj.dy > point.dy) &&
        point.dx <
            (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
    if (intersects) inside = !inside;
  }
  return inside;
}
