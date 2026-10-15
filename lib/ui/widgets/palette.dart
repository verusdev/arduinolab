import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/component_type.dart';
import '../../state/app_state.dart';

/// Left panel listing available components. Tap one to drop it on the board.
class Palette extends StatelessWidget {
  const Palette({super.key});

  static IconData iconFor(ComponentType type) {
    switch (type) {
      case ComponentType.arduinoUno:
        return Icons.memory;
      case ComponentType.breadboard:
        return Icons.grid_on;
      case ComponentType.led:
        return Icons.lightbulb;
      case ComponentType.rgbLed:
        return Icons.emoji_objects;
      case ComponentType.resistor:
        return Icons.horizontal_rule;
      case ComponentType.pushButton:
        return Icons.radio_button_checked;
      case ComponentType.potentiometer:
        return Icons.tune;
      case ComponentType.servo:
        return Icons.rotate_right;
      case ComponentType.buzzer:
        return Icons.volume_up;
      case ComponentType.lcd16x2:
        return Icons.tv;
      case ComponentType.ultrasonic:
        return Icons.sensors;
      case ComponentType.dht11:
        return Icons.thermostat;
      case ComponentType.photoresistor:
        return Icons.brightness_6;
      case ComponentType.robotCar:
        return Icons.directions_car;
      case ComponentType.robotArm:
        return Icons.precision_manufacturing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final categories = <String, List<ComponentType>>{};
    for (final type in ComponentType.values) {
      final spec = ComponentSpecs.of(type);
      categories.putIfAbsent(spec.category, () => []).add(type);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Text('COMPONENTS',
              style: TextStyle(fontSize: 11, letterSpacing: 0.8,
                  fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ),
        for (final entry in categories.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ),
          for (final type in entry.value)
            ListTile(
              dense: true,
              leading: Icon(iconFor(type),
                  color: const Color(0xFF00796B), size: 20),
              title: Text(ComponentSpecs.of(type).label,
                  style: const TextStyle(fontSize: 13)),
              onTap: () {
                final n = app.project.circuit.components.length;
                app.addComponent(
                    type, 260.0 + (n % 5) * 34, 200.0 + (n % 7) * 30);
              },
            ),
        ],
      ],
    );
  }
}
