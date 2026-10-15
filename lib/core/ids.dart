import 'dart:math';

final Random _rand = Random();

/// Short unique-enough identifier for circuit elements.
String newId([String prefix = 'e']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rand.nextInt(1 << 20).toRadixString(36);
  return '${prefix}_$t$r';
}
