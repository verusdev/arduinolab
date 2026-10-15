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
  robotArm,
  armBase,
  armLink,
  armGripper;

  static ComponentType parse(String name) =>
      ComponentType.values.firstWhere((t) => t.name == name,
          orElse: () => ComponentType.resistor);
}

/// How a part of a built-up arm bolts onto its neighbour.
///
/// Every arm part rotates about its own [pivotX]/[pivotY]; a child part is
/// attached by dropping its pivot onto the parent's socket, and the child's
/// angle is the parent's plus whatever the parent contributes.
class ArmMount {
  const ArmMount({
    required this.pivotX,
    required this.pivotY,
    this.socketX,
    this.socketY,
    this.isJoint = false,
  });

  /// Rotation point, in the component's local (unrotated) space.
  final double pivotX;
  final double pivotY;

  /// Where the next part's pivot lands. Null when nothing bolts on top.
  final double? socketX;
  final double? socketY;

  /// True for a servo: its own angle is added to everything bolted above it.
  final bool isJoint;

  bool get hasSocket => socketX != null && socketY != null;
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
    this.mount,
  });

  final ComponentType type;

  /// English display name: the reference wording for translators. The interface
  /// shows the translation under the `component.<type.name>` key instead.
  final String label;

  /// English grouping used by the palette, kept as a stable key; shown as
  /// `category.<value>` in the active language.
  final String category;
  final double width;
  final double height;
  final List<Pin> pins;

  /// Groups of pin ids that are internally shorted by the component itself.
  final List<List<String>> implicitGroups;
  final Map<String, Object?> defaults;

  /// Mechanical mount, for the parts a built-up arm is made of.
  final ArmMount? mount;

  bool get isArmPart => mount != null;
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
      // The shaft is the centre, so a part bolted on swings around it, and the
      // pins keep rotating about the centre exactly like every other part.
      mount: const ArmMount(
          pivotX: 30, pivotY: 30, socketX: 30, socketY: 30, isJoint: true),
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
      label: 'Robot Car 4WD',
      category: 'Robotics',
      width: 160,
      height: 170,
      // One row per axle pair, then the sensors and power. Motors are numbered
      // M1 front-left, M2 front-right, M3 rear-left, M4 rear-right; each has its
      // own direction inputs A/B and its own PWM enable.
      pins: const [
        Pin('M1A', 'M1A', 14, 100, PinKind.digital),
        Pin('M1B', 'M1B', 38, 100, PinKind.digital),
        Pin('EN1', 'EN1', 62, 100, PinKind.pwm),
        Pin('M2A', 'M2A', 86, 100, PinKind.digital),
        Pin('M2B', 'M2B', 110, 100, PinKind.digital),
        Pin('EN2', 'EN2', 134, 100, PinKind.pwm),
        Pin('M3A', 'M3A', 14, 124, PinKind.digital),
        Pin('M3B', 'M3B', 38, 124, PinKind.digital),
        Pin('EN3', 'EN3', 62, 124, PinKind.pwm),
        Pin('M4A', 'M4A', 86, 124, PinKind.digital),
        Pin('M4B', 'M4B', 110, 124, PinKind.digital),
        Pin('EN4', 'EN4', 134, 124, PinKind.pwm),
        Pin('TRIG', 'TRIG', 14, 148, PinKind.digital),
        Pin('ECHO', 'ECHO', 38, 148, PinKind.digital),
        Pin('TRIG2', 'TRIG2', 62, 148, PinKind.digital),
        Pin('ECHO2', 'ECHO2', 86, 148, PinKind.digital),
        Pin('5V', '5V', 110, 148, PinKind.power),
        Pin('GND', 'GND', 134, 148, PinKind.ground),
      ],
      defaults: {
        'distance': 100.0,
        'distanceBehind': 100.0,
        'autoDistance': true,
        'phase1': 0.0,
        'phase2': 0.0,
        'phase3': 0.0,
        'phase4': 0.0,
      },
    ),
    ComponentType.robotArm: ComponentSpec(
      type: ComponentType.robotArm,
      label: 'Robot Arm',
      category: 'Robotics',
      width: 190,
      height: 150,
      // One pin per joint, in order up the arm. The last joint works the jaws,
      // so a 4 segment arm has a shoulder, an elbow, a wrist and a gripper.
      pins: const [
        Pin('J1', 'J1', 14, 128, PinKind.pwm),
        Pin('J2', 'J2', 36, 128, PinKind.pwm),
        Pin('J3', 'J3', 58, 128, PinKind.pwm),
        Pin('J4', 'J4', 80, 128, PinKind.pwm),
        Pin('J5', 'J5', 102, 128, PinKind.pwm),
        Pin('J6', 'J6', 124, 128, PinKind.pwm),
        Pin('5V', '5V', 146, 128, PinKind.power),
        Pin('GND', 'GND', 168, 128, PinKind.ground),
      ],
      defaults: {
        'segments': 4,
        // A joint with no servo fitted simply holds its rest angle, so an arm
        // can be posed by hand and then have one joint animated.
        'servoJ1': true,
        'servoJ2': true,
        'servoJ3': true,
        'servoJ4': true,
        'servoJ5': false,
        'servoJ6': false,
        // Neutral, so a joint without a servo holds the arm straight up.
        'restJ1': 90.0,
        'restJ2': 90.0,
        'restJ3': 90.0,
        'restJ4': 90.0,
        'restJ5': 90.0,
        'restJ6': 90.0,
      },
    ),
    ComponentType.armBase: ComponentSpec(
      type: ComponentType.armBase,
      label: 'Arm Base',
      category: 'Robotics',
      width: 96,
      height: 60,
      pins: const [],
      mount: const ArmMount(pivotX: 48, pivotY: 30, socketX: 48, socketY: 10),
    ),
    ComponentType.armLink: ComponentSpec(
      type: ComponentType.armLink,
      label: 'Arm Link',
      category: 'Robotics',
      width: 28,
      height: 76,
      pins: const [],
      mount: const ArmMount(pivotX: 14, pivotY: 76, socketX: 14, socketY: 8),
    ),
    ComponentType.armGripper: ComponentSpec(
      type: ComponentType.armGripper,
      label: 'Arm Gripper',
      category: 'Robotics',
      width: 52,
      height: 44,
      pins: const [],
      mount: const ArmMount(pivotX: 26, pivotY: 44, socketX: 26, socketY: 8),
      defaults: {'openness': 0.0},
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
