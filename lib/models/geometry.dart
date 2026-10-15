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

/// Size of the workspace parts are placed on. The canvas renders it and the
/// robot physics treats its border as a wall, so both must agree.
const double kWorkspaceWidth = 2400;
const double kWorkspaceHeight = 1600;
