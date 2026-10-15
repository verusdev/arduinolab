import 'geometry.dart';
import 'component_type.dart';
import 'pin.dart';

/// A component instance placed on the workspace.
class PlacedComponent {
  PlacedComponent({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.rotation = 0,
    Map<String, Object?>? properties,
  }) : properties = properties ?? Map.of(ComponentSpecs.of(type).defaults);

  final String id;
  final ComponentType type;
  double x;
  double y;

  /// Rotation in degrees: 0, 90, 180 or 270.
  double rotation;
  final Map<String, Object?> properties;

  ComponentSpec get spec => ComponentSpecs.of(type);
  double get width => spec.width;
  double get height => spec.height;

  PlacedComponent copyWith({
    double? x,
    double? y,
    double? rotation,
    Map<String, Object?>? properties,
  }) {
    return PlacedComponent(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      properties:
          properties == null ? Map.of(this.properties) : Map.of(properties),
    );
  }

  Pin? pinById(String pinId) => ComponentSpecs.pin(type, pinId);

  /// Absolute position of a pin on the workspace.
  (double, double) pinPosition(Pin pin) {
    final (rx, ry) = rotatePoint(pin.dx, pin.dy, width / 2, height / 2,
        degToRad(rotation));
    return (x + rx, y + ry);
  }

  (double, double) pinPositionById(String pinId) {
    final p = pinById(pinId);
    if (p == null) return (x, y);
    return pinPosition(p);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'rotation': rotation,
        'properties': properties,
      };

  factory PlacedComponent.fromJson(Map<String, Object?> j) {
    final type = ComponentType.parse(j['type'] as String? ?? 'resistor');
    return PlacedComponent(
      id: j['id'] as String? ?? 'c',
      type: type,
      x: (j['x'] as num?)?.toDouble() ?? 0,
      y: (j['y'] as num?)?.toDouble() ?? 0,
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      properties: Map<String, Object?>.from(
          (j['properties'] as Map?)?.cast<String, Object?>() ??
              ComponentSpecs.of(type).defaults),
    );
  }
}

/// A wire connecting two component pins.
class Wire {
  Wire({
    required this.id,
    required this.aComponent,
    required this.aPin,
    required this.bComponent,
    required this.bPin,
    this.color = 0xFF2F6FED,
  });

  final String id;
  String aComponent;
  String aPin;
  String bComponent;
  String bPin;
  int color;

  Map<String, Object?> toJson() => {
        'id': id,
        'aComponent': aComponent,
        'aPin': aPin,
        'bComponent': bComponent,
        'bPin': bPin,
        'color': color,
      };

  factory Wire.fromJson(Map<String, Object?> j) => Wire(
        id: j['id'] as String? ?? 'w',
        aComponent: j['aComponent'] as String? ?? '',
        aPin: j['aPin'] as String? ?? '',
        bComponent: j['bComponent'] as String? ?? '',
        bPin: j['bPin'] as String? ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0xFF2F6FED,
      );
}

/// The schematic: placed components plus wires between them.
class Circuit {
  Circuit({List<PlacedComponent>? components, List<Wire>? wires})
      : components = components ?? [],
        wires = wires ?? [];

  final List<PlacedComponent> components;
  final List<Wire> wires;

  static String pinKey(String componentId, String pinId) =>
      '$componentId::$pinId';

  PlacedComponent? componentById(String id) {
    for (final c in components) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool hasPin(String componentId, String pinId) =>
      componentById(componentId)?.pinById(pinId) != null;

  bool wireExists(String a, String ap, String b, String bp) {
    for (final w in wires) {
      if (w.aComponent == a &&
          w.aPin == ap &&
          w.bComponent == b &&
          w.bPin == bp) {
        return true;
      }
      if (w.aComponent == b &&
          w.aPin == bp &&
          w.bComponent == a &&
          w.bPin == ap) {
        return true;
      }
    }
    return false;
  }

  void removeComponent(String id) {
    components.removeWhere((c) => c.id == id);
    wires.removeWhere((w) => w.aComponent == id || w.bComponent == id);
  }

  void removeWire(String id) => wires.removeWhere((w) => w.id == id);

  bool get hasArduino =>
      components.any((c) => c.type == ComponentType.arduinoUno);

  Circuit copy() => Circuit(
        components: components.map((c) => c.copyWith()).toList(),
        wires: wires.map((w) => Wire.fromJson(w.toJson())).toList(),
      );

  Map<String, Object?> toJson() => {
        'components': components.map((c) => c.toJson()).toList(),
        'wires': wires.map((w) => w.toJson()).toList(),
      };

  factory Circuit.fromJson(Map<String, Object?> j) => Circuit(
        components: ((j['components'] as List?) ?? const [])
            .map((e) =>
                PlacedComponent.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        wires: ((j['wires'] as List?) ?? const [])
            .map((e) => Wire.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );
}
