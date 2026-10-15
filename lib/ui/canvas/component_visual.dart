import 'package:flutter/material.dart';

import '../../engine/robotics.dart';
import '../../models/circuit.dart';
import '../../models/component_type.dart';
import '../../state/app_state.dart';

/// Snapshot of the visual state of a component for the painter.
class ComponentVisual {
  const ComponentVisual({
    this.ledBrightness = 0,
    this.ledColor = const Color(0xFFFF3B30),
    this.rgbRed = 0,
    this.rgbGreen = 0,
    this.rgbBlue = 0,
    this.pressed = false,
    this.angle = 90,
    this.knob = 0.5,
    this.light = 0.5,
    this.lcdRows = const ['                ', '                '],
    this.frequency = 0,
    this.wheels = const <double>[0, 0, 0, 0],
    this.wheelPhases = const <double>[0, 0, 0, 0],
    this.joints = const <double>[90, 90, 90, 90, 90, 90],
    this.fitted = const <bool>[true, true, true, true, false, false],
  });

  final double ledBrightness;
  final Color ledColor;
  final double rgbRed;
  final double rgbGreen;
  final double rgbBlue;
  final bool pressed;

  /// Servo angle in degrees, 0..180.
  final double angle;
  final double knob;
  final double light;
  final List<String> lcdRows;
  final double frequency;

  /// Drive duty of the car's four wheels, each in -1..1, in the order
  /// front-left, front-right, rear-left, rear-right.
  final List<double> wheels;

  /// Rotation of each wheel graphic, in degrees, in the same order.
  final List<double> wheelPhases;

  /// Robot arm servo angles in degrees, one per joint from the shoulder up.
  final List<double> joints;

  /// Whether each arm joint has a servo fitted.
  final List<bool> fitted;

  /// Average duty of the two left wheels.
  double get left => wheels.length < 4 ? 0 : (wheels[0] + wheels[2]) / 2;

  /// Average duty of the two right wheels.
  double get right => wheels.length < 4 ? 0 : (wheels[1] + wheels[3]) / 2;

  factory ComponentVisual.of(AppState app, PlacedComponent c) {
    final solution = app.engine.solution;
    final runtime = app.engine.runtime;
    final servoPin = app.engine.resolveLogicPin(c.id, 'SIG');
    final buzzerPin = app.engine.resolveLogicPin(c.id, 'P');

    var wheels = const <double>[0, 0, 0, 0];
    var phases = const <double>[0, 0, 0, 0];
    var joints = const <double>[90, 90, 90, 90, 90, 90];
    var fitted = const <bool>[true, true, true, true, false, false];
    switch (c.type) {
      case ComponentType.robotCar:
        wheels = readRigCommands(app.engine, c).wheels;
        phases = [
          for (var i = 1; i <= 4; i++)
            (c.properties['phase$i'] as num?)?.toDouble() ?? 0,
        ];
      case ComponentType.robotArm:
        joints = readRigCommands(app.engine, c).joints;
        fitted = [
          for (var j = 1; j <= 6; j++) armJointFitted(c, j),
        ];
      default:
        break;
    }

    return ComponentVisual(
      ledBrightness: solution.ledBrightness[c.id] ?? 0,
      ledColor: Color((c.properties['color'] as int?) ?? 0xFFFF3B30),
      rgbRed: solution.rgbBrightness['${c.id}:R'] ?? 0,
      rgbGreen: solution.rgbBrightness['${c.id}:G'] ?? 0,
      rgbBlue: solution.rgbBrightness['${c.id}:B'] ?? 0,
      pressed: app.isButtonPressed(c.id),
      angle: servoPin == null ? 90 : (runtime.servoAngle[servoPin] ?? 90),
      knob: (c.properties['position'] as num?)?.toDouble() ?? 0.5,
      light: (c.properties['light'] as num?)?.toDouble() ?? 0.5,
      lcdRows: List<String>.from(runtime.lcdRows),
      frequency: buzzerPin == null ? 0 : (runtime.toneFreq[buzzerPin] ?? 0),
      wheels: wheels,
      wheelPhases: phases,
      joints: joints,
      fitted: fitted,
    );
  }
}
