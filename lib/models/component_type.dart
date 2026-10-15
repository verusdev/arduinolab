import 'pin.dart';

/// All component types supported by the simulator.
enum ComponentType {
  arduinoUno,
  breadboard,
  led,
  rgbLed,
  resistor,
  pushButton,
  potentiometer,
  servo,
  buzzer,
  lcd16x2,
  ultrasonic,
  dht11,
  photoresistor,
  robotCar,
  robotArm;

  static ComponentType parse(String name) =>
      ComponentType.values.firstWhere((t) => t.name == name,
          orElse: () => ComponentType.resistor);
}

/// Static description of a component: geometry, pins, defaults and the
/// implicit connections the component provides (e.g. breadboard rows).
class ComponentSpec {
  const ComponentSpec({
    required this.type,
    required this.label,
    required this.category,
    required this.width,
    required this.height,
    required this.pins,
    this.implicitGroups = const [],
    this.defaults = const {},
  });

  final ComponentType type;
  final String label;
  final String category;
  final double width;
  final double height;
  final List<Pin> pins;

  /// Groups of pin ids that are internally shorted by the component itself.
  final List<List<String>> implicitGroups;
  final Map<String, Object?> defaults;
}

/// Breadboard geometry helpers.
class BreadboardGeometry {
  static const int columns = 30;
  static const double spacing = 12;
  static const double margin = 20;
  static const List<String> topRows = ['a', 'b', 'c', 'd', 'e'];
  static const List<String> bottomRows = ['f', 'g', 'h', 'i', 'j'];

  static double get width => margin * 2 + (columns - 1) * spacing;
  static double get height => 16 + 5 * spacing + 20 + 5 * spacing + 16;

  static String id(String row, int column) => '$row${column + 1}';

  static double columnX(int column) => margin + column * spacing;
  static double topY(int row) => 16 + row * spacing;
  static double bottomY(int row) => 16 + 5 * spacing + 20 + row * spacing;

  static List<Pin> buildPins() {
    final pins = <Pin>[];
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < topRows.length; r++) {
        final row = topRows[r];
        pins.add(Pin(id(row, c), id(row, c).toUpperCase(), columnX(c), topY(r),
            PinKind.passive));
      }
      for (var r = 0; r < bottomRows.length; r++) {
        final row = bottomRows[r];
        pins.add(Pin(id(row, c), id(row, c).toUpperCase(), columnX(c),
            bottomY(r), PinKind.passive));
      }
    }
    final w = width;
    final h = height;
    pins.add(Pin('+L', '+L', 6, 20, PinKind.power));
    pins.add(Pin('-L', '-L', 6, h - 20, PinKind.ground));
    pins.add(Pin('+R', '+R', w - 6, 20, PinKind.power));
    pins.add(Pin('-R', '-R', w - 6, h - 20, PinKind.ground));
    return pins;
  }

  static List<List<String>> buildGroups() {
    final groups = <List<String>>[];
    for (var c = 0; c < columns; c++) {
      groups.add(topRows.map((r) => id(r, c)).toList());
      groups.add(bottomRows.map((r) => id(r, c)).toList());
    }
    return groups;
  }
}

/// Pin layout of the Arduino UNO board.
List<Pin> _arduinoPins() {
  final pins = <Pin>[];
  const double h = 170;
  for (var i = 0; i <= 13; i++) {
    pins.add(Pin('D$i', 'D$i', 42 + i * 14.5, 12,
        BoardPins.isPwm(i) ? PinKind.pwm : PinKind.digital, i));
  }
  // Stable power pin ids: examples and saved projects reference them by name.
  const powerIds = ['VIN0', '3V30', '5V0', 'GND3', 'GND4'];
  const powerLabels = ['VIN', '3V3', '5V', 'GND', 'GND'];
  for (var i = 0; i < powerIds.length; i++) {
    final label = powerLabels[i];
    pins.add(Pin(powerIds[i], label, 24 + i * 16, h - 12,
        label == 'GND' ? PinKind.ground : PinKind.power));
  }
  for (var i = 0; i <= 5; i++) {
    pins.add(Pin('A$i', 'A$i', 130 + i * 16, h - 12, PinKind.analogIn,
        BoardPins.analogBase + i));
  }
  return pins;
}

/// Central registry of every component specification.
class ComponentSpecs {
  static final Map<ComponentType, ComponentSpec> all = {
    ComponentType.arduinoUno: ComponentSpec(
      type: ComponentType.arduinoUno,
      label: 'Arduino UNO',
      category: 'Boards',
      width: 250,
      height: 170,
      pins: _arduinoPins(),
    ),
    ComponentType.breadboard: ComponentSpec(
      type: ComponentType.breadboard,
      label: 'Breadboard',
      category: 'Boards',
      width: BreadboardGeometry.width,
      height: BreadboardGeometry.height,
      pins: BreadboardGeometry.buildPins(),
      implicitGroups: BreadboardGeometry.buildGroups(),
    ),
    ComponentType.led: ComponentSpec(
      type: ComponentType.led,
      label: 'LED',
      category: 'Output',
      width: 26,
      height: 46,
      pins: const [
        Pin('A', 'A', 9, 46, PinKind.passive),
        Pin('C', 'C', 17, 46, PinKind.passive),
      ],
      defaults: {'color': 0xFFFF3B30},
    ),
    ComponentType.rgbLed: ComponentSpec(
      type: ComponentType.rgbLed,
      label: 'RGB LED',
      category: 'Output',
      width: 34,
      height: 48,
      pins: const [
        Pin('R', 'R', 5, 48, PinKind.passive),
        Pin('G', 'G', 13, 48, PinKind.passive),
        Pin('B', 'B', 21, 48, PinKind.passive),
        Pin('C', 'C', 29, 48, PinKind.passive),
      ],
    ),
    ComponentType.resistor: ComponentSpec(
      type: ComponentType.resistor,
      label: 'Resistor',
      category: 'Basic',
      width: 44,
      height: 16,
      pins: const [
        Pin('1', '', 0, 8, PinKind.passive),
        Pin('2', '', 44, 8, PinKind.passive),
      ],
      defaults: {'resistance': 220.0},
    ),
    ComponentType.pushButton: ComponentSpec(
      type: ComponentType.pushButton,
      label: 'Push Button',
      category: 'Input',
      width: 40,
      height: 40,
      pins: const [
        Pin('1', '1', 0, 20, PinKind.passive),
        Pin('2', '2', 40, 20, PinKind.passive),
        Pin('3', '3', 0, 20, PinKind.passive),
        Pin('4', '4', 40, 20, PinKind.passive),
      ],
    ),
    ComponentType.potentiometer: ComponentSpec(
      type: ComponentType.potentiometer,
      label: 'Potentiometer',
      category: 'Input',
      width: 60,
      height: 40,
      pins: const [
        Pin('1', '1', 0, 30, PinKind.passive),
        Pin('2', 'W', 30, 0, PinKind.passive),
        Pin('3', '3', 60, 30, PinKind.passive),
      ],
      defaults: {'position': 0.5},
    ),
    ComponentType.servo: ComponentSpec(
      type: ComponentType.servo,
      label: 'Servo Motor',
      category: 'Output',
      width: 60,
      height: 60,
      pins: const [
        Pin('VCC', 'V', 0, 50, PinKind.power),
        Pin('GND', 'G', 20, 50, PinKind.ground),
        Pin('SIG', 'S', 40, 50, PinKind.pwm),
      ],
    ),
    ComponentType.buzzer: ComponentSpec(
      type: ComponentType.buzzer,
      label: 'Piezo Buzzer',
      category: 'Output',
      width: 40,
      height: 40,
      pins: const [
        Pin('P', '+', 10, 40, PinKind.passive),
        Pin('N', '-', 30, 40, PinKind.passive),
      ],
    ),
    ComponentType.lcd16x2: ComponentSpec(
      type: ComponentType.lcd16x2,
      label: 'LCD 16x2 (I2C)',
      category: 'Display',
      width: 170,
      height: 80,
      pins: const [
        Pin('GND', 'G', 20, 80, PinKind.ground),
        Pin('VCC', 'V', 50, 80, PinKind.power),
        Pin('SDA', 'SDA', 80, 80, PinKind.i2c),
        Pin('SCL', 'SCL', 110, 80, PinKind.i2c),
      ],
    ),
    ComponentType.ultrasonic: ComponentSpec(
      type: ComponentType.ultrasonic,
      label: 'Ultrasonic HC-SR04',
      category: 'Sensors',
      width: 100,
      height: 60,
      pins: const [
        Pin('VCC', 'V', 0, 60, PinKind.power),
        Pin('GND', 'G', 25, 60, PinKind.ground),
        Pin('TRIG', 'TRIG', 50, 60, PinKind.digital),
        Pin('ECHO', 'ECHO', 75, 60, PinKind.digital),
      ],
      defaults: {'distance': 100.0},
    ),
    ComponentType.dht11: ComponentSpec(
      type: ComponentType.dht11,
      label: 'DHT11 Temp/Humidity',
      category: 'Sensors',
      width: 60,
      height: 60,
      pins: const [
        Pin('VCC', 'V', 0, 60, PinKind.power),
        Pin('DATA', 'D', 25, 60, PinKind.digital),
        Pin('GND', 'G', 50, 60, PinKind.ground),
      ],
      defaults: {'temperature': 24.0, 'humidity': 50.0},
    ),
    ComponentType.photoresistor: ComponentSpec(
      type: ComponentType.photoresistor,
      label: 'Photoresistor',
      category: 'Sensors',
      width: 44,
      height: 16,
      pins: const [
        Pin('1', '', 0, 8, PinKind.passive),
        Pin('2', '', 44, 8, PinKind.passive),
      ],
      defaults: {'light': 0.5},
    ),
    ComponentType.robotCar: ComponentSpec(
      type: ComponentType.robotCar,
      label: 'Robot Car',
      category: 'Robotics',
      width: 140,
      height: 100,
      pins: const [
        Pin('IN1', 'IN1', 10, 78, PinKind.digital),
        Pin('IN2', 'IN2', 32, 78, PinKind.digital),
        Pin('IN3', 'IN3', 54, 78, PinKind.digital),
        Pin('IN4', 'IN4', 76, 78, PinKind.digital),
        Pin('EN1', 'EN1', 98, 78, PinKind.pwm),
        Pin('EN2', 'EN2', 120, 78, PinKind.pwm),
        Pin('5V', '5V', 14, 96, PinKind.power),
        Pin('GND', 'GND', 36, 96, PinKind.ground),
        Pin('TRIG', 'TRIG', 88, 96, PinKind.digital),
        Pin('ECHO', 'ECHO', 110, 96, PinKind.digital),
      ],
      defaults: {
        'distance': 100.0,
        'autoDistance': true,
        'wheelPhase': 0.0,
      },
    ),
    ComponentType.robotArm: ComponentSpec(
      type: ComponentType.robotArm,
      label: 'Robot Arm',
      category: 'Robotics',
      width: 130,
      height: 128,
      pins: const [
        Pin('BASE', 'BASE', 12, 112, PinKind.pwm),
        Pin('SHLD', 'SHLD', 34, 112, PinKind.pwm),
        Pin('ELBW', 'ELBW', 56, 112, PinKind.pwm),
        Pin('GRIP', 'GRIP', 78, 112, PinKind.pwm),
        Pin('5V', '5V', 100, 112, PinKind.power),
        Pin('GND', 'GND', 122, 112, PinKind.ground),
      ],
    ),
  };

  static ComponentSpec of(ComponentType type) => all[type]!;

  static Pin? pin(ComponentType type, String pinId) {
    for (final p in all[type]!.pins) {
      if (p.id == pinId) return p;
    }
    return null;
  }
}
