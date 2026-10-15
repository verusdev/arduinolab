import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/robotics.dart';
import '../../i18n/strings.dart';
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.t('inspector.nothingSelected'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  S.t('inspector.nothingSelectedHint'),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                _Shortcut(
                    label: S.t('inspector.sc.doubleTap'),
                    text: S.t('inspector.sc.doubleTapText')),
                _Shortcut(
                    label: S.t('inspector.sc.longPress'),
                    text: S.t('inspector.sc.longPressText')),
                _Shortcut(
                    label: S.t('inspector.sc.drag'),
                    text: S.t('inspector.sc.dragText')),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(S.t('component.${component.type.name}'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: S.t('inspector.rotate90'),
                icon: const Icon(Icons.rotate_90_degrees_cw),
                onPressed: () => app.rotateComponent(component.id),
              ),
              IconButton(
                tooltip: S.t('common.delete'),
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
          Text(
              S.t('inspector.connections',
                  {'n': component.spec.pins.length}),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text(S.t('inspector.pinHint'),
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 6),
          for (final pin in component.spec.pins) _pinTile(app, component, pin),
          const Divider(height: 24),
        ],
        if (warnings.isNotEmpty) ...[
          Text(S.t('inspector.warnings'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        Text(
            S.t('inspector.wires', {'n': app.project.circuit.wires.length}),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        if (app.project.circuit.wires.isEmpty)
          Text(S.t('inspector.noWires'),
              style: const TextStyle(fontSize: 12, color: Colors.black45))
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
        connected ? targets.join('\n') : S.t('inspector.notConnected'),
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
    String label(String? componentId) {
      final other = componentId == null
          ? null
          : app.project.circuit.componentById(componentId);
      return other == null ? '?' : S.t('component.${other.type.name}');
    }

    for (final wire in app.project.circuit.wires) {
      if (wire.aComponent == c.id && wire.aPin == pin.id) {
        out.add('→ ${label(wire.bComponent)} · ${wire.bPin}');
      } else if (wire.bComponent == c.id && wire.bPin == pin.id) {
        out.add('→ ${label(wire.aComponent)} · ${wire.aPin}');
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
    String label(PlacedComponent? c) =>
        c == null ? '?' : S.t('component.${c.type.name}');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.cable, size: 18, color: Color(wire.color)),
      title: Text(
        '${label(a)} .${wire.aPin}  →  ${label(b)} .${wire.bPin}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: S.t('inspector.deleteWire'),
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
        final ahead = (component.properties['distance'] as num?)?.toDouble() ?? 100;
        final behind =
            (component.properties['distanceBehind'] as num?)?.toDouble() ?? 100;
        final commands = readRigCommands(app.engine, component);
        final wheelNames = [
          S.t('car.wheel1'),
          S.t('car.wheel2'),
          S.t('car.wheel3'),
          S.t('car.wheel4'),
        ];
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(S.t('car.wallSensors'),
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(S.t('car.wallSensorsHint'),
                style: const TextStyle(fontSize: 11)),
            value: auto,
            onChanged: (v) => setProp('autoDistance', v),
          ),
          if (!auto) ...[
            _slider(S.t('car.distanceAhead'), '${ahead.round()} cm', ahead, 2,
                400, (v) => setProp('distance', v)),
            _slider(S.t('car.distanceBehind'), '${behind.round()} cm', behind, 2,
                400, (v) => setProp('distanceBehind', v)),
          ],
          const Divider(height: 20),
          for (var i = 0; i < 4; i++)
            _stat(wheelNames[i], _percent(commands.wheels[i])),
          _stat(S.t('car.heading'), '${component.rotation.round() % 360}°'),
          _stat(S.t('car.sensorAhead'), '${ahead.round()} cm'),
          _stat(S.t('car.sensorBehind'), '${behind.round()} cm'),
        ];
      case ComponentType.robotArm:
        final segments = armSegmentCount(component);
        final angles = readArmJoints(app.engine, component);
        return [
          Text(S.t('arm.hint'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          _slider(S.t('arm.segments'), '$segments', segments.toDouble(), 2, 6,
              (v) => setProp('segments', v.round()),
              divisions: 4),
          const Divider(height: 20),
          for (var j = 1; j <= segments; j++) ...[
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                  j == segments
                      ? S.t('arm.jointGripper', {'n': j})
                      : S.t('arm.jointServo', {'n': j}),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  j == segments
                      ? S.t('arm.jointGripperSub')
                      : S.t('arm.jointSub', {'n': j}),
                  style: const TextStyle(fontSize: 11)),
              value: armJointFitted(component, j),
              onChanged: (v) => setProp('servoJ$j', v),
            ),
            if (armJointFitted(component, j))
              _stat(S.t('arm.jointCommanded', {'n': j}),
                  '${(j <= angles.length ? angles[j - 1] : 90).round()}°')
            else
              _slider(
                  S.t('arm.jointRest', {'n': j}),
                  '${((component.properties['restJ$j'] as num?)?.toDouble() ?? 90).round()}°',
                  (component.properties['restJ$j'] as num?)?.toDouble() ?? 90,
                  0,
                  180,
                  (v) => setProp('restJ$j', v),
                  divisions: 36),
          ],
        ];
      case ComponentType.armBase:
      case ComponentType.armLink:
      case ComponentType.armGripper:
        final parent = ArmAssembly.parentOf(component);
        final host = parent == null
            ? null
            : app.project.circuit.componentById(parent);
        final roles = {
          ComponentType.armBase: S.t('arm.roleBase'),
          ComponentType.armLink: S.t('arm.roleLink'),
          ComponentType.armGripper: S.t('arm.roleGripper'),
        };
        return [
          Text(roles[component.type]!,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const Divider(height: 20),
          _stat(
              S.t('arm.boltedTo'),
              host == null
                  ? S.t('arm.nothing')
                  : S.t('component.${host.type.name}')),
          _stat(S.t('arm.angle'), '${component.rotation.round() % 360}°'),
          if (component.type == ComponentType.armGripper)
            _stat(
                S.t('arm.jaws'),
                S.t('arm.jawsOpen', {
                  'value': _percent(
                      (component.properties['openness'] as num?)?.toDouble() ??
                          0),
                })),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: parent == null
                  ? null
                  : () => app.detachArmPart(component.id),
              icon: const Icon(Icons.link_off, size: 16),
              label: Text(S.t('arm.unbolt')),
            ),
          ),
        ];
      case ComponentType.pushButton:
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(S.t('prop.pressed'), style: const TextStyle(fontSize: 13)),
            value: app.isButtonPressed(component.id),
            onChanged: (v) => app.setButtonPressed(component.id, v),
          ),
        ];
      case ComponentType.resistor:
        final r = (component.properties['resistance'] as num?)?.toDouble() ?? 220;
        return [
          _slider(S.t('prop.resistance'), '${r.toInt()} Ω', r.clamp(10, 10000),
              10, 10000, (v) => setProp('resistance', v.roundToDouble())),
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
          _slider(S.t('prop.knob'), '${(p * 100).round()}%', p, 0, 1,
              (v) => setProp('position', v)),
        ];
      case ComponentType.photoresistor:
        final l = (component.properties['light'] as num?)?.toDouble() ?? 0.5;
        return [
          _slider(S.t('prop.lightLevel'), '${(l * 100).round()}%', l, 0, 1,
              (v) => setProp('light', v)),
        ];
      case ComponentType.joystick:
        final x = (component.properties['x'] as num?)?.toDouble() ?? 0.5;
        final y = (component.properties['y'] as num?)?.toDouble() ?? 0.5;
        return [
          Text(S.t('prop.stick'), style: const TextStyle(fontSize: 13)),
          _slider(
              S.t('prop.axisX'),
              S.t('prop.axisValue',
                  {'percent': (x * 100).round(), 'volts': (x * 5).toStringAsFixed(1)}),
              x,
              0,
              1,
              (v) => setProp('x', v)),
          _slider(
              S.t('prop.axisY'),
              S.t('prop.axisValue',
                  {'percent': (y * 100).round(), 'volts': (y * 5).toStringAsFixed(1)}),
              y,
              0,
              1,
              (v) => setProp('y', v)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setProp('x', 0.5);
                setProp('y', 0.5);
              },
              icon: const Icon(Icons.filter_center_focus, size: 16),
              label: Text(S.t('prop.centre')),
            ),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(S.t('prop.swPressed'),
                style: const TextStyle(fontSize: 13)),
            value: app.isButtonPressed(component.id),
            onChanged: (v) => app.setButtonPressed(component.id, v),
          ),
        ];
      case ComponentType.ultrasonic:
        final d = (component.properties['distance'] as num?)?.toDouble() ?? 100;
        return [
          _slider(S.t('prop.distance'), '${d.round()} cm', d, 2, 400,
              (v) => setProp('distance', v)),
        ];
      case ComponentType.dht11:
        final t = (component.properties['temperature'] as num?)?.toDouble() ?? 24;
        final h = (component.properties['humidity'] as num?)?.toDouble() ?? 50;
        return [
          _slider(S.t('prop.temperature'), '${t.toStringAsFixed(1)} °C', t, -10,
              50, (v) => setProp('temperature', v)),
          _slider(S.t('prop.humidity'), '${h.round()} %', h, 0, 100,
              (v) => setProp('humidity', v)),
        ];
      case ComponentType.led:
        final color = (component.properties['color'] as int?) ?? 0xFFFF3B30;
        return [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(S.t('prop.colour'), style: const TextStyle(fontSize: 13)),
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
        return [
          Text(S.t('inspector.noProperties'),
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
      double max, ValueChanged<double> onChanged,
      {int? divisions}) {
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
        Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged),
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
