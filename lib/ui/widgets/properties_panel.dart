import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/robotics.dart';
import '../../models/circuit.dart';
import '../../models/component_type.dart';
import '../../models/pin.dart';
import '../../state/app_state.dart';

/// Inspector for the selected component plus circuit level information.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final selectedId = app.selectedComponentId;
    final component =
        selectedId == null ? null : app.project.circuit.componentById(selectedId);
    final warnings = app.engine.solution.warnings.toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (component == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing selected.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Tap a part to inspect it. Its pin names are printed on the '
                  'canvas — tap one pin, then another pin, to draw a wire '
                  'between them.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                SizedBox(height: 10),
                _Shortcut(label: 'Double-tap', text: 'rotate the part'),
                _Shortcut(label: 'Long-press', text: 'delete the part'),
                _Shortcut(label: 'Drag', text: 'move the part'),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(component.spec.label,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Rotate 90°',
                icon: const Icon(Icons.rotate_90_degrees_cw),
                onPressed: () => app.rotateComponent(component.id),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => app.deleteComponent(component.id),
              ),
            ],
          ),
          Text('id: ${component.id}',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 8),
          ..._controls(context, app, component),
          const Divider(height: 24),
          Text('Connections (${component.spec.pins.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Tap a pin to start a wire from it.',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 6),
          for (final pin in component.spec.pins) _pinTile(app, component, pin),
          const Divider(height: 24),
        ],
        if (warnings.isNotEmpty) ...[
          const Text('Warnings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          for (final w in warnings)
            Card(
              color: const Color(0xFFFFF3E0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber,
                    color: Colors.orange, size: 20),
                title: Text(w, style: const TextStyle(fontSize: 12)),
              ),
            ),
          const Divider(height: 24),
        ],
        Text('Wires (${app.project.circuit.wires.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        if (app.project.circuit.wires.isEmpty)
          const Text('No wires yet.',
              style: TextStyle(fontSize: 12, color: Colors.black45))
        else
          for (final w in app.project.circuit.wires) _wireTile(app, w),
      ],
    );
  }

  // ------------------------------------------------------------------- pins

  Widget _pinTile(AppState app, PlacedComponent component, Pin pin) {
    final targets = _connections(app, component, pin);
    final pending = app.pendingWire;
    final isPending = pending != null &&
        pending.componentId == component.id &&
        pending.pinId == pin.id;
    final connected = targets.isNotEmpty;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(left: 6, top: 6),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFF9800) : _pinColor(pin),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
      title: Text(
        pin.displayName,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        connected ? targets.join('\n') : 'Not connected',
        style: TextStyle(
          fontSize: 11,
          color: connected ? Colors.black87 : Colors.black38,
        ),
      ),
      trailing: Icon(
        isPending ? Icons.radio_button_checked : Icons.cable,
        size: 16,
        color: isPending ? const Color(0xFFFF9800) : Colors.black26,
      ),
      onTap: () => app.tapPin(component.id, pin.id),
    );
  }

  /// Labels of everything wired to [pin], e.g. `→ Arduino UNO · D7`.
  List<String> _connections(AppState app, PlacedComponent c, Pin pin) {
    final out = <String>[];
    for (final wire in app.project.circuit.wires) {
      if (wire.aComponent == c.id && wire.aPin == pin.id) {
        final other = app.project.circuit.componentById(wire.bComponent);
        out.add('→ ${other?.spec.label ?? '?'} · ${wire.bPin}');
      } else if (wire.bComponent == c.id && wire.bPin == pin.id) {
        final other = app.project.circuit.componentById(wire.aComponent);
        out.add('→ ${other?.spec.label ?? '?'} · ${wire.aPin}');
      }
    }
    return out;
  }

  Color _pinColor(Pin pin) {
    switch (pin.kind) {
      case PinKind.power:
        return const Color(0xFFC9A227);
      case PinKind.ground:
        return const Color(0xFF37474F);
      case PinKind.pwm:
        return const Color(0xFF2F6FED);
      case PinKind.analogIn:
        return const Color(0xFF00897B);
      case PinKind.i2c:
        return const Color(0xFF8E24AA);
      case PinKind.digital:
        return const Color(0xFF546E7A);
      case PinKind.passive:
        return const Color(0xFF90A4AE);
    }
  }

  Widget _wireTile(AppState app, Wire wire) {
    final a = app.project.circuit.componentById(wire.aComponent);
    final b = app.project.circuit.componentById(wire.bComponent);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.cable, size: 18, color: Color(wire.color)),
      title: Text(
        '${a?.spec.label ?? '?'} .${wire.aPin}  →  '
        '${b?.spec.label ?? '?'} .${wire.bPin}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Delete wire',
        icon: const Icon(Icons.close, size: 16),
        onPressed: () {
          app.selectWire(wire.id);
          app.deleteSelected();
        },
      ),
    );
  }

  List<Widget> _controls(
      BuildContext context, AppState app, PlacedComponent component) {
    void setProp(String key, Object? value) =>
        app.setProperty(component.id, key, value);

    switch (component.type) {
      case ComponentType.robotCar:
        final auto = (component.properties['autoDistance'] as bool?) ?? true;
        final d = (component.properties['distance'] as num?)?.toDouble() ?? 100;
        final commands = readRigCommands(app.engine, component);
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Wall sensor',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text('Reads the distance ahead automatically',
                style: TextStyle(fontSize: 11)),
            value: auto,
            onChanged: (v) => setProp('autoDistance', v),
          ),
          if (!auto)
            _slider('Distance', '${d.round()} cm', d, 2, 400,
                (v) => setProp('distance', v)),
          const Divider(height: 20),
          _stat('Left / right drive',
              '${_percent(commands.left)} / ${_percent(commands.right)}'),
          _stat('Heading', '${component.rotation.round() % 360}°'),
          _stat('Sensor reads', '${d.round()} cm'),
        ];
      case ComponentType.robotArm:
        final joints = readRigCommands(app.engine, component).joints;
        return [
          const Text('Drive the joints with "servo write" blocks.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const Divider(height: 20),
          _stat('Base', '${joints[0].round()}°'),
          _stat('Shoulder', '${joints[1].round()}°'),
          _stat('Elbow', '${joints[2].round()}°'),
          _stat('Gripper', '${_percent(joints[3] / 180.0)} open'),
        ];
      case ComponentType.pushButton:
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Pressed', style: TextStyle(fontSize: 13)),
            value: app.isButtonPressed(component.id),
            onChanged: (v) => app.setButtonPressed(component.id, v),
          ),
        ];
      case ComponentType.resistor:
        final r = (component.properties['resistance'] as num?)?.toDouble() ?? 220;
        return [
          _slider('Resistance', '${r.toInt()} Ω', r.clamp(10, 10000), 10, 10000,
              (v) => setProp('resistance', v.roundToDouble())),
          Wrap(
            spacing: 6,
            children: [
              for (final preset in [100, 220, 330, 1000, 10000])
                ActionChip(
                  label: Text('$preset'),
                  onPressed: () => setProp('resistance', preset.toDouble()),
                ),
            ],
          ),
        ];
      case ComponentType.potentiometer:
        final p = (component.properties['position'] as num?)?.toDouble() ?? 0.5;
        return [
          _slider('Knob', '${(p * 100).round()}%', p, 0, 1,
              (v) => setProp('position', v)),
        ];
      case ComponentType.photoresistor:
        final l = (component.properties['light'] as num?)?.toDouble() ?? 0.5;
        return [
          _slider('Light level', '${(l * 100).round()}%', l, 0, 1,
              (v) => setProp('light', v)),
        ];
      case ComponentType.ultrasonic:
        final d = (component.properties['distance'] as num?)?.toDouble() ?? 100;
        return [
          _slider('Distance', '${d.round()} cm', d, 2, 400,
              (v) => setProp('distance', v)),
        ];
      case ComponentType.dht11:
        final t = (component.properties['temperature'] as num?)?.toDouble() ?? 24;
        final h = (component.properties['humidity'] as num?)?.toDouble() ?? 50;
        return [
          _slider('Temperature', '${t.toStringAsFixed(1)} °C', t, -10, 50,
              (v) => setProp('temperature', v)),
          _slider('Humidity', '${h.round()} %', h, 0, 100,
              (v) => setProp('humidity', v)),
        ];
      case ComponentType.led:
        final color = (component.properties['color'] as int?) ?? 0xFFFF3B30;
        return [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('Colour', style: TextStyle(fontSize: 13)),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [
                0xFFFF3B30,
                0xFF34C759,
                0xFF0A84FF,
                0xFFFFCC00,
                0xFFFFFFFF,
              ])
                GestureDetector(
                  onTap: () => setProp('color', c),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == c ? Colors.blue : Colors.black26,
                        width: color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ];
      default:
        return const [
          Text('No adjustable properties.',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ];
    }
  }

  /// Read-only telemetry row.
  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static String _percent(double value) => '${(value * 100).round()}%';

  Widget _slider(String label, String valueText, double value, double min,
      double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(valueText, style: const TextStyle(fontSize: 12)),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
