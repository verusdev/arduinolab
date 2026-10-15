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
    this.angle = 0,
    this.knob = 0.5,
    this.light = 0.5,
    this.lcdRows = const ['                ', '                '],
    this.frequency = 0,
    this.leftSpeed = 0,
    this.rightSpeed = 0,
    this.wheelPhase = 0,
    this.joints = const [0, 0, 0, 0],
  });

  final double ledBrightness;
  final Color ledColor;
  final double rgbRed;
  final double rgbGreen;
  final double rgbBlue;
  final bool pressed;
  final double angle;
  final double knob;
  final double light;
  final List<String> lcdRows;
  final double frequency;

  /// Drive duty of the robot car's motors, each in -1..1.
  final double leftSpeed;
  final double rightSpeed;

  /// Rotation of the car's wheel graphics, in degrees.
  final double wheelPhase;

  /// Robot arm servo angles in degrees: base, shoulder, elbow, gripper.
  final List<double> joints;

  factory ComponentVisual.of(AppState app, PlacedComponent c) {
    final solution = app.engine.solution;
    final runtime = app.engine.runtime;
    final servoPin = app.engine.resolveLogicPin(c.id, 'SIG');
    final buzzerPin = app.engine.resolveLogicPin(c.id, 'P');

    var left = 0.0;
    var right = 0.0;
    var joints = const <double>[0, 0, 0, 0];
    if (c.type == ComponentType.robotCar) {
      final commands = readRigCommands(app.engine, c);
      left = commands.left;
      right = commands.right;
    } else if (c.type == ComponentType.robotArm) {
      joints = readRigCommands(app.engine, c).joints;
    }

    return ComponentVisual(
      ledBrightness: solution.ledBrightness[c.id] ?? 0,
      ledColor: Color((c.properties['color'] as int?) ?? 0xFFFF3B30),
      rgbRed: solution.rgbBrightness['${c.id}:R'] ?? 0,
      rgbGreen: solution.rgbBrightness['${c.id}:G'] ?? 0,
      rgbBlue: solution.rgbBrightness['${c.id}:B'] ?? 0,
      pressed: app.isButtonPressed(c.id),
      angle: servoPin == null ? 0 : (runtime.servoAngle[servoPin] ?? 0),
      knob: (c.properties['position'] as num?)?.toDouble() ?? 0.5,
      light: (c.properties['light'] as num?)?.toDouble() ?? 0.5,
      lcdRows: List<String>.from(runtime.lcdRows),
      frequency: buzzerPin == null ? 0 : (runtime.toneFreq[buzzerPin] ?? 0),
      leftSpeed: left,
      rightSpeed: right,
      wheelPhase: (c.properties['wheelPhase'] as num?)?.toDouble() ?? 0,
      joints: joints,
    );
  }
}
