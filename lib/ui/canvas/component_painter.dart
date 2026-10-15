import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/circuit.dart';
import '../../models/component_type.dart';
import '../../models/pin.dart';
import '../../i18n/strings.dart';
import 'component_visual.dart';
import '../../engine/robotics.dart';

/// Paints the body and pins of a single component.
class ComponentPainter extends CustomPainter {
  ComponentPainter({
    required this.component,
    required this.visual,
    this.selected = false,
    this.pendingPinId,
    this.wiring = false,
  });

  final PlacedComponent component;
  final ComponentVisual visual;
  final bool selected;
  final String? pendingPinId;

  /// True while a wire is being drawn anywhere on the canvas, which turns every
  /// connection point into an obvious, clickable target.
  final bool wiring;

  static const Color _gold = Color(0xFFC9A227);
  static const Color _teal = Color(0xFF0B3C49);

  /// Boards and breadboards carry too many pins to label without noise.
  static const int _labelPinLimit = 12;

  @override
  void paint(Canvas canvas, Size size) {
    switch (component.type) {
      case ComponentType.arduinoUno:
        _arduino(canvas, size);
        break;
      case ComponentType.breadboard:
        _breadboard(canvas, size);
        break;
      case ComponentType.led:
        _led(canvas, size);
        break;
      case ComponentType.rgbLed:
        _rgbLed(canvas, size);
        break;
      case ComponentType.resistor:
        _resistor(canvas, size);
        break;
      case ComponentType.pushButton:
        _button(canvas, size);
        break;
      case ComponentType.potentiometer:
        _potentiometer(canvas, size);
        break;
      case ComponentType.servo:
        _servo(canvas, size);
        break;
      case ComponentType.buzzer:
        _buzzer(canvas, size);
        break;
      case ComponentType.lcd16x2:
        _lcd(canvas, size);
        break;
      case ComponentType.ultrasonic:
        _ultrasonic(canvas, size);
        break;
      case ComponentType.dht11:
        _dht(canvas, size);
        break;
      case ComponentType.photoresistor:
        _photoresistor(canvas, size);
        break;
      case ComponentType.robotCar:
        _robotCar(canvas, size);
        break;
      case ComponentType.robotArm:
        _robotArm(canvas, size);
        break;
      case ComponentType.armBase:
        _armBase(canvas, size);
        break;
      case ComponentType.armLink:
        _armLink(canvas, size);
        break;
      case ComponentType.armGripper:
        _armGripper(canvas, size);
        break;
    }
    _paintPins(canvas, size);
    if (selected) {
      final r = Rect.fromLTWH(0, 0, size.width, size.height).inflate(4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2F6FED),
      );
    }
  }

  void _paintPins(Canvas canvas, Size size) {
    final isBoard = component.type == ComponentType.arduinoUno;
    final labelled = component.spec.pins.length <= _labelPinLimit && !isBoard;
    for (final p in component.spec.pins) {
      if (p.id.startsWith('+') || p.id.startsWith('-')) continue;
      final isPending = p.id == pendingPinId;
      final color = isPending
          ? const Color(0xFFFF9800)
          : (p.kind == PinKind.ground
              ? const Color(0xFF37474F)
              : _gold);
      canvas.drawCircle(Offset(p.dx, p.dy), isPending ? 5.5 : 3,
          Paint()..color = color);
      canvas.drawCircle(
        Offset(p.dx, p.dy),
        isPending ? 5.5 : 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x66000000),
      );
      if (!labelled || p.hasGenericName) continue;
      _pinLabel(canvas, p.displayName, p, size,
          emphasize: isPending || wiring || selected);
    }
  }

  /// Prints a pin name just outside the component, biased to the edge the pin
  /// sits on so it never covers the body artwork.
  void _pinLabel(Canvas canvas, String text, Pin p, Size size,
      {required bool emphasize}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 6.5,
          height: 1.0,
          fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
          color: emphasize ? Colors.white : const Color(0xFFF1F5F7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const gap = 4.0;
    final below = p.dy >= size.height - 1;
    final above = p.dy <= 1;
    final onLeft = p.dx <= 1;
    final onRight = p.dx >= size.width - 1;

    final Offset topLeft;
    if (below || (!above && !onLeft && !onRight)) {
      topLeft = Offset(p.dx - tp.width / 2, p.dy + gap);
    } else if (above) {
      topLeft = Offset(p.dx - tp.width / 2, p.dy - gap - tp.height);
    } else if (onLeft) {
      topLeft = Offset(p.dx - gap - tp.width, p.dy - tp.height / 2);
    } else {
      topLeft = Offset(p.dx + gap, p.dy - tp.height / 2);
    }

    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          topLeft.dx - 2.5, topLeft.dy - 1, tp.width + 5, tp.height + 2),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      chip,
      Paint()
        ..color = emphasize
            ? const Color(0xE6EF6C00)
            : const Color(0xB3181C1F),
    );
    if (emphasize) {
      canvas.drawRRect(
        chip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFFFFFFFF),
      );
    }
    tp.paint(canvas, topLeft);
  }

  // ---------------------------------------------------------------- helpers

  void _label(Canvas canvas, String text, Offset at,
      {double size = 8,
      Color color = Colors.white,
      FontWeight weight = FontWeight.normal,
      TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  void _rounded(Canvas canvas, Rect r, Color color,
      {double radius = 6, Color? stroke, double strokeWidth = 1}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = color);
    if (stroke != null) {
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = stroke);
    }
  }

  // ------------------------------------------------------------ components

  void _arduino(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(0, 0, size.width, size.height), _teal,
        radius: 8, stroke: const Color(0xFF072A33), strokeWidth: 2);
    _rounded(
        canvas,
        Rect.fromLTWH(8, 26, size.width - 16, size.height - 52),
        const Color(0xFF12556B),
        radius: 6);
    _label(canvas, 'ARDUINO', Offset(size.width / 2, size.height / 2 - 16),
        size: 16, weight: FontWeight.bold, align: TextAlign.center);
    _label(canvas, 'UNO', Offset(size.width / 2, size.height / 2),
        size: 14, align: TextAlign.center);
    _label(canvas, S.t('silk.digital'), const Offset(2, 2),
        size: 7, color: const Color(0xFFBFE3EA));
    _label(canvas, S.t('silk.analogPower'), Offset(120, size.height - 24),
        size: 7, color: const Color(0xFFBFE3EA));
    // USB connector
    _rounded(canvas, const Rect.fromLTWH(-6, 44, 14, 34),
        const Color(0xFFB0BEC5),
        radius: 3);
    // Barrel jack
    _rounded(canvas, Rect.fromLTWH(2, size.height - 60, 24, 34),
        const Color(0xFF1B1F22),
        radius: 4);
    // Every header is silkscreened, GND pins included: without them a wire
    // landing on the ground rail looks like it connects to nothing.
    for (final p in component.spec.pins) {
      if (p.hasGenericName) continue;
      _label(canvas, p.displayName, Offset(p.dx, p.dy + 5),
          size: 6.5,
          weight: FontWeight.w600,
          color: const Color(0xFFE4F2F6),
          align: TextAlign.center);
    }
  }

  void _breadboard(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(0, 0, size.width, size.height),
        const Color(0xFFF3F1EA),
        radius: 6, stroke: const Color(0xFFCFC9BA), strokeWidth: 2);
    final hole = Paint()..color = const Color(0xFF9AA0A6);
    for (var c = 0; c < BreadboardGeometry.columns; c++) {
      for (var r = 0; r < 5; r++) {
        canvas.drawCircle(
            Offset(BreadboardGeometry.columnX(c),
                BreadboardGeometry.topY(r)),
            1.6,
            hole);
        canvas.drawCircle(
            Offset(BreadboardGeometry.columnX(c),
                BreadboardGeometry.bottomY(r)),
            1.6,
            hole);
      }
    }
    // centre gap
    canvas.drawLine(
        Offset(0, BreadboardGeometry.topY(4) + 10),
        Offset(size.width, BreadboardGeometry.topY(4) + 10),
        Paint()
          ..color = const Color(0xFFCFC9BA)
          ..strokeWidth = 2);
    // rails
    final railTop = Paint()
      ..color = const Color(0xFFE57373)
      ..strokeWidth = 3;
    final railBottom = Paint()
      ..color = const Color(0xFF64B5F6)
      ..strokeWidth = 3;
    canvas.drawLine(
        const Offset(6, 20), Offset(6, size.height - 20), railTop);
    canvas.drawLine(
        Offset(6, size.height - 20), const Offset(6, 20), railBottom);
    canvas.drawLine(Offset(size.width - 6, 20),
        Offset(size.width - 6, size.height - 20), railTop);
    canvas.drawLine(Offset(size.width - 6, size.height - 20),
        Offset(size.width - 6, 20), railBottom);
  }

  void _led(Canvas canvas, Size size) {
    final glow = visual.ledBrightness;
    if (glow > 0.02) {
      canvas.drawCircle(
          Offset(size.width / 2, 20),
          10 + 14 * glow,
          Paint()
            ..color = visual.ledColor.withValues(alpha: 0.25 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    _rounded(canvas, Rect.fromLTWH(3, 4, size.width - 6, 28),
        const Color(0xFFFFE0E0),
        radius: 12,
        stroke: const Color(0xFFB0BEC5));
    canvas.drawCircle(
        Offset(size.width / 2, 18),
        9,
        Paint()
          ..color = Color.lerp(
              const Color(0xFF8C8C8C), visual.ledColor, 0.15 + 0.85 * glow)!);
    canvas.drawLine(const Offset(9, 32), const Offset(9, 46),
        Paint()
          ..color = const Color(0xFF607D8B)
          ..strokeWidth = 2);
    canvas.drawLine(Offset(size.width - 9, 32), Offset(size.width - 9, 46),
        Paint()
          ..color = const Color(0xFF607D8B)
          ..strokeWidth = 2);
  }

  void _rgbLed(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(3, 4, size.width - 6, 30),
        const Color(0xFFEDEDED),
        radius: 12,
        stroke: const Color(0xFFB0BEC5));
    final off = (visual.rgbRed + visual.rgbGreen + visual.rgbBlue) < 0.02;
    final color = off
        ? const Color(0xFF8C8C8C)
        : Color.fromARGB(
            255,
            (60 + 195 * visual.rgbRed).round(),
            (60 + 195 * visual.rgbGreen).round(),
            (60 + 195 * visual.rgbBlue).round(),
          );
    canvas.drawCircle(Offset(size.width / 2, 19), 10, Paint()..color = color);
    for (var i = 0; i < 4; i++) {
      final x = 5 + i * 8.0;
      canvas.drawLine(Offset(x, 34), Offset(x, 48),
          Paint()
            ..color = const Color(0xFF607D8B)
            ..strokeWidth = 2);
    }
  }

  void _resistor(Canvas canvas, Size size) {
    final ohms = (component.properties['resistance'] as num?)?.toDouble() ?? 220;
    _rounded(canvas, Rect.fromLTWH(0, 2, size.width, 12),
        const Color(0xFFD7C9A7),
        radius: 5,
        stroke: const Color(0xFF9E8F6B));
    const bandColors = [
      Color(0xFF795548),
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(10.0 + i * 7, 2, 3, 12),
          Paint()..color = bandColors[i]);
    }
    canvas.drawLine(const Offset(0, 8), const Offset(-2, 8),
        Paint()..color = const Color(0xFF607D8B));
    _label(canvas, '${ohms.toInt()}Ω', Offset(size.width / 2, 15),
        size: 7, color: const Color(0xFF37474F), align: TextAlign.center);
  }

  void _button(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Color(0xFFECEFF1),
        radius: 8,
        stroke: const Color(0xFF90A4AE));
    final press = visual.pressed ? 3.0 : 0.0;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2 + press),
        visual.pressed ? 13 : 15,
        Paint()
          ..color = visual.pressed
              ? const Color(0xFF90A4AE)
              : const Color(0xFF546E7A));
  }

  void _potentiometer(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(2, 2, size.width - 4, size.height - 6),
        const Color(0xFF37474F),
        radius: 5);
    final angle = (visual.knob - 0.5) * 2 * math.pi * 0.8;
    final center = Offset(size.width / 2, size.height / 2 - 1);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -10, 6, 20), const Radius.circular(3)),
      Paint()..color = const Color(0xFFCFD8DC));
    canvas.restore();
    canvas.drawCircle(center, 12, Paint()..color = const Color(0xFF90A4AE));
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF37474F));
  }

  void _servo(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(2, 6, size.width - 4, size.height - 12),
        const Color(0xFF1565C0),
        radius: 6,
        stroke: const Color(0xFF0D47A1));
    final center = Offset(size.width / 2, 14);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(visual.angle * math.pi / 180.0 - math.pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, 0, 6, 18), const Radius.circular(3)),
      Paint()..color = const Color(0xFFECEFF1));
    canvas.restore();
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFFBBDEFB));
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF0D47A1));
  }

  void _buzzer(Canvas canvas, Size size) {
    final active = visual.frequency > 0;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2 - 4),
        14,
        Paint()
          ..color = active
              ? const Color(0xFFFFCC80)
              : const Color(0xFF263238));
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - 4), 6,
        Paint()..color = const Color(0xFF000000));
    if (active) {
      _label(canvas, '♪', Offset(size.width / 2, 2),
          size: 12, color: const Color(0xFFEF6C00), align: TextAlign.center);
    }
  }

  void _lcd(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(0, 0, size.width, size.height),
        const Color(0xFF1B5E20),
        radius: 8,
        stroke: const Color(0xFF0D3D12), strokeWidth: 2);
    final screen = Rect.fromLTWH(8, 8, size.width - 16, size.height - 24);
    canvas.drawRect(screen, Paint()..color = const Color(0xFF9CCC65));
    for (var row = 0; row < 2; row++) {
      final text = row < visual.lcdRows.length ? visual.lcdRows[row] : '';
      _label(canvas, text, Offset(screen.left + 4, screen.top + 6 + row * 18),
          size: 13, color: const Color(0xFF1B3006));
    }
  }

  void _ultrasonic(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(0, 0, size.width, size.height - 6),
        const Color(0xFF0D47A1),
        radius: 6,
        stroke: const Color(0xFF082A63));
    for (var i = 0; i < 2; i++) {
      canvas.drawCircle(Offset(18.0 + i * 30, 20), 12,
          Paint()..color = const Color(0xFFB0BEC5));
      canvas.drawCircle(Offset(18.0 + i * 30, 20), 8,
          Paint()..color = const Color(0xFF607D8B));
    }
    _label(canvas, 'HC-SR04', Offset(size.width / 2, 2),
        size: 7, align: TextAlign.center);
  }

  void _dht(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(2, 2, size.width - 4, size.height - 8),
        const Color(0xFF37474F),
        radius: 5);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        canvas.drawRect(Rect.fromLTWH(8.0 + c * 9, 10.0 + r * 9, 6, 6),
            Paint()..color = const Color(0xFF78909C));
      }
    }
    _label(canvas, 'DHT11', Offset(size.width / 2, 2),
        size: 7, align: TextAlign.center);
  }

  void _photoresistor(Canvas canvas, Size size) {
    _rounded(canvas, Rect.fromLTWH(4, 2, size.width - 8, size.height - 8),
        const Color(0xFFECEFF1),
        radius: 8,
        stroke: const Color(0xFFB0BEC5));
    final zig = Path()..moveTo(8, 11);
    for (var i = 1; i <= 4; i++) {
      zig.lineTo(8 + i * 5.0, i.isOdd ? 5 : 17);
    }
    canvas.drawPath(
        zig,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF8D6E63));
  }

  // ------------------------------------------------------------------ robots

  /// Top-down view. The car drives towards its local +x axis, which is also the
  /// direction `rotation` points, so the drawn nose always matches the physics.
  /// Four wheels, each driven on its own, plus a rangefinder on the nose and
  /// another one on the tail.
  void _robotCar(Canvas canvas, Size size) {
    final w = size.width;
    final midY = 47.0;

    // Chassis and deck.
    _rounded(canvas, Rect.fromLTWH(16, 16, w - 32, 62), const Color(0xFF2E3A40),
        radius: 12,
        stroke: const Color(0xFF141A1D),
        strokeWidth: 1.5);
    _rounded(canvas, Rect.fromLTWH(30, 26, w - 60, 42), const Color(0xFF3B474D),
        radius: 8);

    // Wheels: M1 front-left, M2 front-right, M3 rear-left, M4 rear-right. The
    // nose is at +x, so the front pair sits further right and the left pair
    // further up.
    const wheels = [
      Rect.fromLTWH(92, 4, 30, 12), // front-left
      Rect.fromLTWH(92, 78, 30, 12), // front-right
      Rect.fromLTWH(34, 4, 30, 12), // rear-left
      Rect.fromLTWH(34, 78, 30, 12), // rear-right
    ];
    for (var i = 0; i < wheels.length; i++) {
      _wheel(
        canvas,
        wheels[i],
        i < visual.wheelPhases.length ? visual.wheelPhases[i] : 0,
        i < visual.wheels.length ? visual.wheels[i] : 0,
      );
    }

    // HC-SR04s: the two cans of the front sensor point up the nose, the rear
    // pair points back down the tail.
    for (final x in const [140.0, 20.0]) {
      for (final y in const [30.0, 62.0]) {
        canvas.drawCircle(Offset(x, y), 6.5, Paint()..color = const Color(0xFF90A4AE));
        canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = const Color(0xFF37474F));
      }
    }

    _carHeading(canvas, size, midY);
    _label(canvas, S.t('silk.robotCar'), Offset(w / 2, 44),
        size: 6.5, color: const Color(0xFFCFD8DC), align: TextAlign.center);
  }

  void _wheel(Canvas canvas, Rect r, double phase, double duty) {
    _rounded(canvas, r, const Color(0xFF212121), radius: 4);
    final tread = Paint()
      ..color = const Color(0xFF556066)
      ..strokeWidth = 1.4;
    // Scrolling the tread reads as rotation without distorting the tyre. Long
    // wheels roll along x, upright ones along y.
    final horizontal = r.width >= r.height;
    for (var i = 0; i < 4; i++) {
      final t = ((i / 4) + phase / 360.0) % 1.0;
      if (horizontal) {
        final x = r.left + 3 + t * (r.width - 6);
        canvas.drawLine(
            Offset(x, r.top + 1.2), Offset(x, r.bottom - 1.2), tread);
      } else {
        final y = r.top + 3 + t * (r.height - 6);
        canvas.drawLine(
            Offset(r.left + 1.2, y), Offset(r.right - 1.2, y), tread);
      }
    }
    final glow = duty.abs().clamp(0.0, 1.0);
    if (glow > 0.05) {
      _rounded(
          canvas,
          r,
          (duty > 0 ? const Color(0xFF43A047) : const Color(0xFFE53935))
              .withValues(alpha: 0.15 + 0.6 * glow),
          radius: 4);
    }
  }

  /// A nose chevron that lights up with forward/backward drive.
  void _carHeading(Canvas canvas, Size size, double midY) {
    final speed = (visual.left + visual.right) / 2;
    final magnitude = speed.abs().clamp(0.0, 1.0);
    final color = magnitude < 0.05
        ? const Color(0xFF7B8A91)
        : (speed > 0 ? const Color(0xFF00E5FF) : const Color(0xFFFF7043))
            .withValues(alpha: 0.35 + 0.65 * magnitude);
    final path = Path()
      ..moveTo(size.width - 4, midY)
      ..lineTo(size.width - 18, midY - 11)
      ..lineTo(size.width - 18, midY + 11)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }


  /// The configurable arm: a planar chain of segments with a servo at each
  /// joint that has one fitted, so every joint swings in the plane of the
  /// drawing and all of the motion is visible at once.
  void _robotArm(Canvas canvas, Size size) {
    final pose = ArmKinematics.of(component, visual.joints);
    final joints = [for (final p in pose.joints) Offset(p.$1, p.$2)];

    // Foot plate under the shoulder.
    final foot = joints.first;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(foot.dx, foot.dy + 12), width: 92, height: 18),
      Paint()..color = const Color(0xFF455A64),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(foot.dx, foot.dy + 12), width: 92, height: 18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF263238),
    );

    // Links, tapering towards the tip.
    for (var i = 0; i + 1 < joints.length; i++) {
      _limb(
        canvas,
        joints[i],
        joints[i + 1],
        (12 - i * 1.4).clamp(5.0, 12.0),
        i.isEven ? const Color(0xFF607D8B) : const Color(0xFF78909C),
      );
    }

    // Joints. A gold ring and a horn mean a servo is fitted there; a bare grey
    // ring means the joint is rigid and holds the angle dialled in by hand.
    for (var i = 0; i < joints.length; i++) {
      final fitted = i < pose.fitted.length ? pose.fitted[i] : false;
      final at = joints[i];
      canvas.drawCircle(at, 5, Paint()..color = const Color(0xFF37474F));
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = fitted ? const Color(0xFFFFB300) : const Color(0xFF90A4AE),
      );
      if (!fitted) continue;
      // The horn shows which way the joint is swung; the tip has jaws instead.
      if (i >= joints.length - 1) continue;
      final swing = i < pose.directions.length ? pose.directions[i] : -90.0;
      _limb(canvas, at, _along(at, swing, 11), 3, const Color(0xFFFFF3E0));
    }

    // Jaws.
    final spread = 9 + pose.openness * 22;
    for (final sign in const [-1.0, 1.0]) {
      _limb(
          canvas,
          _point(pose.tip),
          _alongTuple(pose.tip, pose.tipDirection + sign * spread, 15),
          4.5,
          const Color(0xFFB0BEC5));
    }

    _label(canvas, S.t('silk.robotArm'), const Offset(4, 2),
        size: 6.5, color: const Color(0xFFB0BEC5));
  }

  /// The pedestal an arm is built up from.
  void _armBase(Canvas canvas, Size size) {
    final mount = component.spec.mount!;
    final path = Path()
      ..moveTo(8, mount.socketY! + 14)
      ..lineTo(size.width - 8, mount.socketY! + 14)
      ..lineTo(size.width - 20, size.height - 4)
      ..lineTo(20, size.height - 4)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF546E7A));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF263238),
    );
    _socketMark(canvas, Offset(mount.socketX!, mount.socketY!));
    _label(canvas, S.t('silk.base'), Offset(size.width / 2, size.height - 20),
        size: 6.5, color: const Color(0xFFCFD8DC), align: TextAlign.center);
  }

  /// One segment of a built-up arm: a bar with a joint at its foot and a socket
  /// on its shoulder.
  void _armLink(Canvas canvas, Size size) {
    final mount = component.spec.mount!;
    _rounded(canvas, Rect.fromLTWH(5, mount.socketY! - 2, size.width - 10, size.height - 14),
        const Color(0xFF78909C),
        radius: 5,
        stroke: const Color(0xFF37474F));
    canvas.drawLine(
        Offset(size.width / 2, mount.socketY! + 4),
        Offset(size.width / 2, size.height - 12),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF546E7A));
    canvas.drawCircle(
        Offset(mount.pivotX, mount.pivotY),
        8,
        Paint()..color = const Color(0xFF455A64));
    canvas.drawCircle(Offset(mount.pivotX, mount.pivotY), 3.5,
        Paint()..color = const Color(0xFFCFD8DC));
    _socketMark(canvas, Offset(mount.socketX!, mount.socketY!));
  }

  /// The jaws. A servo bolted onto the socket above them opens and closes them.
  void _armGripper(Canvas canvas, Size size) {
    final mount = component.spec.mount!;
    final open = (component.properties['openness'] as num?)?.toDouble() ?? 0;
    _rounded(canvas, Rect.fromLTWH(8, mount.socketY! - 2, size.width - 16, 22),
        const Color(0xFF90A4AE),
        radius: 6,
        stroke: const Color(0xFF37474F));
    final hinge = Offset(mount.pivotX, mount.pivotY - 12);
    for (final sign in const [-1.0, 1.0]) {
      final tip = _along(hinge, -90 + sign * (7 + open * 32), 17);
      _limb(canvas, hinge, tip, 5, const Color(0xFFB0BEC5));
      canvas.drawCircle(tip, 3, Paint()..color = const Color(0xFF607D8B));
    }
    _socketMark(canvas, Offset(mount.socketX!, mount.socketY!));
  }

  /// A socket a child part bolts onto, drawn the same on every part so it reads
  /// as "something can go here".
  void _socketMark(Canvas canvas, Offset at) {
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFFFB300),
    );
    canvas.drawCircle(at, 2, Paint()..color = const Color(0xFF8D6E63));
  }

  /// A limb of [length] from [from], in the same angle convention the canvas
  /// uses: measured from +x, growing clockwise on screen, so -90° is up.
  Offset _along(Offset from, double deg, double length) {
    final h = deg * math.pi / 180.0;
    return Offset(
        from.dx + math.cos(h) * length, from.dy + math.sin(h) * length);
  }

  /// Same as [_along] but for a point the kinematics module handed back.
  Offset _alongTuple((double, double) from, double deg, double length) =>
      _along(_point(from), deg, length);

  /// A point record from the kinematics module as a canvas offset.
  Offset _point((double, double) at) => Offset(at.$1, at.$2);

  void _limb(Canvas canvas, Offset a, Offset b, double width, Color color) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant ComponentPainter old) =>
      old.visual != visual ||
      old.selected != selected ||
      old.wiring != wiring ||
      old.pendingPinId != pendingPinId ||
      old.component.rotation != component.rotation;
}
