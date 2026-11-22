// Детерминированный PRNG для «Среза агата».
//
// Вся арифметика держится в диапазоне [0, 2^32). На web (dart2js) `int` — это
// double, а битовые операции усечены до 32 бит и знаковые, поэтому обычные
// `<<`, `>>` и `*` там дают неверный результат. Умножение и xor собраны из
// 16-битных половин: промежуточные значения не выходят за 2^53 и одинаковы
// на всех платформах. Сдвиг вправо — деление, потому что `>>` в web знаковый.

const int _mod32 = 4294967296; // 2^32

/// Приводит значение к беззнаковому 32-битному диапазону.
int u32(int value) {
  final v = value % _mod32;
  return v < 0 ? v + _mod32 : v;
}

int add32(int a, int b) => u32(a + b);

int xor32(int a, int b) =>
    ((a ~/ 65536) ^ (b ~/ 65536)) * 65536 + ((a % 65536) ^ (b % 65536));

int or32(int a, int b) =>
    ((a ~/ 65536) | (b ~/ 65536)) * 65536 + ((a % 65536) | (b % 65536));

int shr32(int a, int n) => a ~/ (1 << n);

int mul32(int a, int b) {
  final aLo = a % 65536;
  final aHi = a ~/ 65536;
  final bLo = b % 65536;
  final bHi = b ~/ 65536;
  final lo = aLo * bLo;
  final mid = (aHi * bLo + aLo * bHi) % 65536;
  return (lo + mid * 65536) % _mod32;
}

/// MurmurHash3 fmix32 поверх created_at_ms и соли (раздел 2.1 спецификации).
///
/// Сдвиг времени на 1 мс меняет примерно половину битов результата. Соль
/// разделяет независимые потоки: "v1:geo", "v1:color", "v1:mut", "v1:geode".
int agateSeed(int timestampMs, String salt) {
  var h = xor32(u32(timestampMs), mul32(u32(timestampMs ~/ _mod32), 0x9E3779B1));
  for (final code in salt.codeUnits) {
    h = mul32(xor32(h, code), 0x85EBCA6B);
  }
  h = xor32(h, shr32(h, 16));
  h = mul32(h, 0x85EBCA6B);
  h = xor32(h, shr32(h, 13));
  h = mul32(h, 0xC2B2AE35);
  h = xor32(h, shr32(h, 16));
  return h;
}

/// Mulberry32 (раздел 2.2 спецификации).
class AgateRandom {
  AgateRandom(int seed) : _state = u32(seed);

  int _state;

  /// Равномерное число в [0.0, 1.0).
  double next() {
    _state = add32(_state, 0x6D2B79F5);
    var t = _state;
    t = mul32(xor32(t, shr32(t, 15)), or32(t, 1));
    t = xor32(t, add32(t, mul32(xor32(t, shr32(t, 7)), or32(t, 61))));
    return xor32(t, shr32(t, 14)) / _mod32;
  }

  double range(double min, double max) => min + next() * (max - min);

  /// floor(range(min, max + 1)) — как в спецификации.
  int nextInt(int min, int max) => range(min.toDouble(), max.toDouble() + 1).floor();

  /// Нижняя граница включена, верхняя тоже (для выбора из списка).
  int index(int length) => nextInt(0, length - 1);

  T pick<T>(List<T> items) => items[index(items.length)];

  bool chance(double probability) => next() < probability;
}
