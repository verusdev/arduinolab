import 'dart:math' as math;

/// Rotates the point ([x],[y]) around ([cx],[cy]) by [angleRad].
(double, double) rotatePoint(
    double x, double y, double cx, double cy, double angleRad) {
  final dx = x - cx;
  final dy = y - cy;
  final c = math.cos(angleRad);
  final s = math.sin(angleRad);
  return (cx + dx * c - dy * s, cy + dx * s + dy * c);
}

double degToRad(double deg) => deg * math.pi / 180.0;
