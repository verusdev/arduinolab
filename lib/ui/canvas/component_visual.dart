import 'package:flutter/material.dart';

import '../../models/circuit.dart';
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

  factory ComponentVisual.of(AppState app, PlacedComponent c) {
    final solution = app.engine.solution;
    final runtime = app.engine.runtime;
    final servoPin = app.engine.resolveLogicPin(c.id, 'SIG');
    final buzzerPin = app.engine.resolveLogicPin(c.id, 'P');
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
    );
  }
}
