import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/engine/netlist.dart';
import 'package:arduino_lab/engine/runtime.dart';
import 'package:arduino_lab/engine/solver.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/canvas/canvas_view.dart';

/// A board carrying a joystick wired the way the lesson wires it: rails, both
/// wiper pins to analog inputs, and the button to a digital pin.
Circuit _rig({double x = 0.5, double y = 0.5}) => Circuit(
      components: [
        PlacedComponent(id: 'uno', type: ComponentType.arduinoUno, x: 0, y: 0),
        PlacedComponent(
          id: 'joy1',
          type: ComponentType.joystick,
          x: 300,
          y: 0,
          properties: {'x': x, 'y': y},
        ),
      ],
      wires: [
        Wire(
            id: 'w1',
            aComponent: 'joy1',
            aPin: 'VCC',
            bComponent: 'uno',
            bPin: '5V0'),
        Wire(
            id: 'w2',
            aComponent: 'joy1',
            aPin: 'GND',
            bComponent: 'uno',
            bPin: 'GND3'),
        Wire(
            id: 'w3',
            aComponent: 'joy1',
            aPin: 'VRX',
            bComponent: 'uno',
            bPin: 'A0'),
        Wire(
            id: 'w4',
            aComponent: 'joy1',
            aPin: 'VRY',
            bComponent: 'uno',
            bPin: 'A1'),
        Wire(
            id: 'w5',
            aComponent: 'joy1',
            aPin: 'SW',
            bComponent: 'uno',
            bPin: 'D2'),
      ],
    );

/// What `analogRead` would report on [pin] with the stick at ([x], [y]).
/// A0 is logical 14, A1 is 15.
double _axis({double x = 0.5, double y = 0.5, int pin = 14}) {
  final circuit = _rig(x: x, y: y);
  final solution = Solver.solve(
      circuit, Netlist.build(circuit), ArduinoRuntime()..started = true, const {});
  return solution.analogRead(pin);
}

/// What `digitalRead(2)` would report with the button either held or free.
bool _switchHigh({required bool pressed}) {
  final circuit = _rig();
  final runtime = ArduinoRuntime()..started = true;
  runtime.pullup[2] = true;
  final solution = Solver.solve(circuit, Netlist.build(circuit), runtime,
      pressed ? const {'joy1'} : const {});
  return solution.digitalRead(2);
}

void main() {
  group('Joystick geometry', () {
    test('the stick rests in the middle and swings to the ends of its travel',
        () {
      expect(JoystickGeometry.stickAt(0.5, 0.5),
          (JoystickGeometry.bootX, JoystickGeometry.bootY));
      expect(JoystickGeometry.stickAt(1, 1),
          (JoystickGeometry.bootX + 10, JoystickGeometry.bootY - 10));
      expect(JoystickGeometry.stickAt(0, 0),
          (JoystickGeometry.bootX - 10, JoystickGeometry.bootY + 10));
    });

    test('a drag slides the stick and stops at the ends of the travel', () {
      expect(JoystickGeometry.slide(0.5, 0.5, 10, 0), (1.0, 0.5));
      expect(JoystickGeometry.slide(0.5, 0.5, 0, 10), (0.5, 0.0));
      expect(JoystickGeometry.slide(0.5, 0.5, 100, 100), (1.0, 0.0));
      expect(JoystickGeometry.slide(0.5, 0.5, -100, -100), (0.0, 1.0));
    });

    test('the boot grabs the stick, the corner pad is a button, pins are neither',
        () {
      expect(JoystickGeometry.overStick(JoystickGeometry.bootX,
          JoystickGeometry.bootY), isTrue);
      expect(JoystickGeometry.overButton(8, 8), isTrue);
      expect(JoystickGeometry.overButton(JoystickGeometry.bootX,
          JoystickGeometry.bootY), isFalse);
      expect(JoystickGeometry.overStick(60, 60), isFalse);

      for (final pin in ComponentSpecs.of(ComponentType.joystick).pins) {
        expect(JoystickGeometry.overStick(pin.dx, pin.dy), isFalse,
            reason: 'the stick must not sit over ${pin.id}');
        expect(JoystickGeometry.overButton(pin.dx, pin.dy), isFalse,
            reason: 'the button must not sit over ${pin.id}');
      }
    });
  });

  group('Joystick part', () {
    test('is an input with the KY-023 header and both axes centred', () {
      final spec = ComponentSpecs.of(ComponentType.joystick);
      expect(spec.category, 'Input');
      expect(spec.pins.map((p) => p.id).toList(),
          ['VCC', 'GND', 'VRX', 'VRY', 'SW']);
      expect(spec.pins.map((p) => p.displayName).toList(),
          ['VCC', 'GND', 'VRX', 'VRY', 'SW']);
      expect(spec.defaults['x'], 0.5);
      expect(spec.defaults['y'], 0.5);
    });

    test('its header is spaced widely enough for the tap targets', () {
      final pins = ComponentSpecs.of(ComponentType.joystick).pins;
      for (var i = 0; i < pins.length; i++) {
        for (var j = i + 1; j < pins.length; j++) {
          final a = pins[i];
          final b = pins[j];
          final gap = (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
          expect(gap, greaterThanOrEqualTo(13), reason: '${a.id} vs ${b.id}');
        }
      }
    });
  });

  group('Joystick solver', () {
    test('an untouched stick reads the middle of the range', () {
      expect(_axis(pin: 14), closeTo(511.5, 3));
      expect(_axis(pin: 15), closeTo(511.5, 3));
    });

    test('the X wiper reads full scale to the right and nothing to the left', () {
      expect(_axis(x: 1, pin: 14), greaterThan(1000));
      expect(_axis(x: 0, pin: 14), lessThan(25));
      // The other axis must not be disturbed by it.
      expect(_axis(x: 1, pin: 15), closeTo(511.5, 3));
    });

    test('the Y wiper works the same way, upwards', () {
      expect(_axis(y: 1, pin: 15), greaterThan(1000));
      expect(_axis(y: 0, pin: 15), lessThan(25));
      expect(_axis(y: 1, pin: 14), closeTo(511.5, 3));
    });

    test('SW is a button to ground: pulled up when free, low when held', () {
      expect(_switchHigh(pressed: false), isTrue);
      expect(_switchHigh(pressed: true), isFalse);
    });
  });

  group('Joystick state', () {
    test('setJoystick stores both axes and clamps them to the travel', () {
      final app = AppState();
      app.addComponent(ComponentType.joystick, 100, 100);
      final id = app.project.circuit.components.single.id;

      app.setJoystick(id, 0.25, 0.75);
      final c = app.project.circuit.componentById(id)!;
      expect(c.properties['x'], 0.25);
      expect(c.properties['y'], 0.75);

      app.setJoystick(id, -2, 7);
      expect(c.properties['x'], 0.0);
      expect(c.properties['y'], 1.0);
    });
  });

  group('Joystick on the canvas', () {
    // Well clear of the hint card that floats over the top-left corner.
    const base = Offset(400, 400);

    /// Places a joystick at [base] with its stick at ([x], [y]) and pumps the
    /// workspace around it.
    Future<AppState> pumpCanvas(WidgetTester tester,
        {double x = 0.5, double y = 0.5}) async {
      final app = AppState();
      app.addComponent(ComponentType.joystick, base.dx, base.dy);
      final id = app.project.circuit.components.single.id;
      app.setJoystick(id, x, y);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: const MaterialApp(home: Scaffold(body: CanvasView())),
        ),
      );
      await tester.pump();
      return app;
    }

    Offset at(double dx, double dy) => base + Offset(dx, dy);

    testWidgets('dragging the stick moves the stick, not the module',
        (tester) async {
      final app = await pumpCanvas(tester);
      final id = app.project.circuit.components.single.id;

      // From the middle of the boot, right by exactly one full travel.
      final gesture = await tester.startGesture(
          at(JoystickGeometry.bootX, JoystickGeometry.bootY));
      await gesture.moveBy(const Offset(JoystickGeometry.travel * 2, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final c = app.project.circuit.componentById(id)!;
      expect(c.properties['x'], closeTo(1.0, 0.001));
      expect(c.properties['y'], closeTo(0.5, 0.001));
      expect(c.x, base.dx, reason: 'the module itself must not move');
      expect(c.y, base.dy);
      // Let the double-tap countdown started by the pointer down expire.
      await tester.pump(kDoubleTapTimeout);
    });

    testWidgets('dragging the body moves the module and leaves the stick alone',
        (tester) async {
      final app = await pumpCanvas(tester);
      final id = app.project.circuit.components.single.id;

      // A corner of the body: off the boot, off the button and off the header.
      final gesture = await tester.startGesture(at(58, 36));
      // The first move is eaten by the touch slop, the second one drags.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final c = app.project.circuit.componentById(id)!;
      expect(c.x, closeTo(base.dx + 20, 1));
      expect(c.properties['x'], 0.5, reason: 'the stick must stay centred');
      expect(c.properties['y'], 0.5);
      // Let the double-tap countdown started by the pointer down expire.
      await tester.pump(kDoubleTapTimeout);
    });

    testWidgets('tapping the SW pad presses the button', (tester) async {
      final app = await pumpCanvas(tester);
      final id = app.project.circuit.components.single.id;

      expect(app.isButtonPressed(id), isFalse);
      await tester.tapAt(at(10, 8));
      await tester.pump(kDoubleTapTimeout);
      expect(app.isButtonPressed(id), isTrue);

      await tester.tapAt(at(10, 8));
      await tester.pump(kDoubleTapTimeout);
      expect(app.isButtonPressed(id), isFalse);
    });

    testWidgets('tapping a pushed stick springs it back to the middle',
        (tester) async {
      final app = await pumpCanvas(tester, x: 1, y: 0);
      final id = app.project.circuit.components.single.id;

      // Where the stick is actually drawn, not where its centre is.
      await tester.tapAt(
          at(JoystickGeometry.bootX + 10, JoystickGeometry.bootY - 10));
      await tester.pump(kDoubleTapTimeout);

      final c = app.project.circuit.componentById(id)!;
      expect(c.properties['x'], 0.5);
      expect(c.properties['y'], 0.5);
      expect(app.isButtonPressed(id), isFalse,
          reason: 'touching the stick is not pressing the button');
    });
  });
}
