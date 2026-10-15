import 'dart:math' as math;

import '../i18n/strings.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
import '../models/pin.dart';
import 'netlist.dart';
import 'runtime.dart';

/// Solution of the circuit for one instant in time.
class CircuitSolution {
  CircuitSolution({
    required this.netVoltage,
    required this.logicalPinNet,
    required this.ledBrightness,
    required this.rgbBrightness,
    required this.ultrasonicDistanceByEchoPin,
    required this.dhtTemperatureByDataPin,
    required this.dhtHumidityByDataPin,
    required this.pwmByPin,
    required this.warnings,
  });

  /// net index -> node voltage.
  final Map<int, double> netVoltage;

  /// logical pin -> net index.
  final Map<int, int> logicalPinNet;

  /// component id -> 0..1 visual brightness.
  final Map<String, double> ledBrightness;

  /// `"<componentId>:R"` -> 0..1 visual brightness.
  final Map<String, double> rgbBrightness;

  /// logical pin (the pin the ECHO wire lands on) -> distance in cm.
  final Map<int, double> ultrasonicDistanceByEchoPin;

  /// logical pin (the pin the DATA wire lands on) -> value.
  final Map<int, double> dhtTemperatureByDataPin;
  final Map<int, double> dhtHumidityByDataPin;

  /// logical pin -> 0..255 PWM value.
  final Map<int, double> pwmByPin;

  final List<String> warnings;

  /// Voltage of a logical Arduino pin.
  double pinVoltage(int pin) {
    final net = logicalPinNet[pin];
    if (net == null) return 0;
    return netVoltage[net] ?? 0;
  }

  double analogRead(int pin) => pinVoltage(pin) / 5.0 * 1023.0;

  bool digitalRead(int pin) => pinVoltage(pin) > 2.5;

  /// pulseIn() emulation in microseconds; 58 us per centimetre of round trip.
  double pulseInMicros(int pin) =>
      (ultrasonicDistanceByEchoPin[pin] ?? 0) * 58.0;

  double temperature(int pin) => dhtTemperatureByDataPin[pin] ?? 0;
  double humidity(int pin) => dhtHumidityByDataPin[pin] ?? 0;

  static CircuitSolution empty() => CircuitSolution(
        netVoltage: const {},
        logicalPinNet: const {},
        ledBrightness: const {},
        rgbBrightness: const {},
        ultrasonicDistanceByEchoPin: const {},
        dhtTemperatureByDataPin: const {},
        dhtHumidityByDataPin: const {},
        pwmByPin: const {},
        warnings: const [],
      );
}

class _Element {
  _Element(this.a, this.b, this.g);

  final int a;
  final int b;
  final double g;
}

/// Modified nodal analysis of the circuit at one instant in time.
///
/// The board supplies the fixed reference voltages (5V, 3.3V, GND and pins that
/// currently drive an output). Every conductive branch becomes a conductance
/// entry in a nodal matrix which is solved by Gaussian elimination.
class Solver {
  static const double ledResistance = 180;
  static const double _pullupResistance = 40000;
  static const double _leak = 1e-9;

  static CircuitSolution solve(
    Circuit circuit,
    Netlist netlist,
    ArduinoRuntime runtime,
    Set<String> pressedButtons,
  ) {
    final warnings = <String>[];

    // ---- The board supplies the fixed reference voltages. ----
    final fixed = <int, double>{};
    int? fiveVoltNet;
    final logicalPinNet = <int, int>{};
    final logicOfNet = <int, int>{};

    for (final c in circuit.components) {
      if (c.type != ComponentType.arduinoUno) continue;
      for (final p in c.spec.pins) {
        final net = netlist.netOf(c.id, p.id);
        if (net < 0) continue;
        final logic = p.logic;
        if (logic != null) {
          logicalPinNet[logic] = net;
          logicOfNet.putIfAbsent(net, () => logic);
        }
        if (p.label == '5V' || p.label == 'VIN') {
          fiveVoltNet ??= net;
          fixed[net] = 5.0;
        } else if (p.label == '3V3') {
          fixed[net] = 3.3;
        } else if (p.kind == PinKind.ground) {
          fixed[net] = 0.0;
        } else if (logic != null && runtime.isPinOutput(logic)) {
          final v = runtime.drivenVoltage(logic);
          if (v != null) fixed[net] = v;
        }
      }
    }

    // ---- Component branches. ----
    final elements = <_Element>[];
    void addElement(String cid, String a, String b, double g) {
      final na = netlist.netOf(cid, a);
      final nb = netlist.netOf(cid, b);
      if (na < 0 || nb < 0 || na == nb || g <= 0) return;
      elements.add(_Element(na, nb, g));
    }

    for (final c in circuit.components) {
      switch (c.type) {
        case ComponentType.resistor:
          final r = (c.properties['resistance'] as num?)?.toDouble() ?? 220;
          addElement(c.id, '1', '2', 1 / math.max(r, 0.01));
        case ComponentType.photoresistor:
          final light = (c.properties['light'] as num?)?.toDouble() ?? 0.5;
          addElement(
              c.id, '1', '2', 1 / math.max(200 + (1 - light) * 99800, 1));
        case ComponentType.led:
          addElement(c.id, 'A', 'C', 1 / ledResistance);
        case ComponentType.rgbLed:
          addElement(c.id, 'R', 'C', 1 / ledResistance);
          addElement(c.id, 'G', 'C', 1 / ledResistance);
          addElement(c.id, 'B', 'C', 1 / ledResistance);
        case ComponentType.pushButton:
          if (pressedButtons.contains(c.id)) {
            addElement(c.id, '1', '3', 1 / 20);
            addElement(c.id, '2', '4', 1 / 20);
          } else {
            addElement(c.id, '1', '2', 1 / 10000);
          }
        case ComponentType.potentiometer:
          final t = (c.properties['position'] as num?)?.toDouble() ?? 0.5;
          addElement(c.id, '1', '2', 1 / math.max(t * 10000, 50));
          addElement(c.id, '2', '3', 1 / math.max((1 - t) * 10000, 50));
        case ComponentType.joystick:
          // Two wipers on one track between VCC and GND: each axis is a plain
          // voltage divider, so the wiper reads 0 V at one end of the travel and
          // 5 V at the other, with the centre in between.
          final jx = _lever(c.properties['x']);
          final jy = _lever(c.properties['y']);
          addElement(c.id, 'VRX', 'GND', 1 / math.max(jx * 10000, 50));
          addElement(c.id, 'VCC', 'VRX', 1 / math.max((1 - jx) * 10000, 50));
          addElement(c.id, 'VRY', 'GND', 1 / math.max(jy * 10000, 50));
          addElement(c.id, 'VCC', 'VRY', 1 / math.max((1 - jy) * 10000, 50));
          // SW is a push button to GND, closed only while it is held down.
          if (pressedButtons.contains(c.id)) {
            addElement(c.id, 'SW', 'GND', 1 / 20);
          }
        case ComponentType.arduinoUno:
        case ComponentType.breadboard:
        case ComponentType.servo:
        case ComponentType.buzzer:
        case ComponentType.lcd16x2:
        case ComponentType.ultrasonic:
        case ComponentType.dht11:
        case ComponentType.robotCar:
        case ComponentType.robotArm:
        case ComponentType.armBase:
        case ComponentType.armLink:
        case ComponentType.armGripper:
          break;
      }
    }

    // ---- Assign a matrix row to every net that needs one. ----
    final nodeOfNet = <int, int>{};
    int nodeIndex(int net) => nodeOfNet.putIfAbsent(net, () => nodeOfNet.length);

    for (final e in elements) {
      nodeIndex(e.a);
      nodeIndex(e.b);
    }
    // Input pins with no branch still need a node so pull-ups can attach.
    for (final entry in logicalPinNet.entries) {
      if (!runtime.isPinOutput(entry.key)) nodeIndex(entry.value);
    }
    // INPUT_PULLUP pins get an internal pull-up to 5V.
    for (final entry in logicalPinNet.entries) {
      final pin = entry.key;
      if (runtime.isPinOutput(pin)) continue;
      if (!runtime.isPinPullup(pin)) continue;
      final five = fiveVoltNet;
      if (five == null || entry.value == five) continue;
      elements.add(_Element(entry.value, five, 1 / _pullupResistance));
    }
    for (final net in fixed.keys) {
      nodeIndex(net);
    }

    final n = nodeOfNet.length;
    final g = List<List<double>>.generate(n, (_) => List<double>.filled(n, 0));
    final b = List<double>.filled(n, 0);

    for (final e in elements) {
      final i = nodeIndex(e.a);
      final j = nodeIndex(e.b);
      g[i][i] += e.g;
      g[j][j] += e.g;
      g[i][j] -= e.g;
      g[j][i] -= e.g;
    }
    // Anchor fixed nodes with an identity row.
    for (final entry in fixed.entries) {
      final i = nodeIndex(entry.key);
      for (var j = 0; j < n; j++) {
        g[i][j] = 0;
      }
      g[i][i] = 1;
      b[i] = entry.value;
    }
    // Tiny leak to ground so floating nets stay solvable.
    for (var i = 0; i < n; i++) {
      g[i][i] += _leak;
    }

    final x = _gauss(g, b);

    final netVoltage = <int, double>{};
    for (final entry in nodeOfNet.entries) {
      netVoltage[entry.key] = x[entry.value];
    }

    // ---- Derived quantities for rendering and the sensors. ----
    final ledBrightness = <String, double>{};
    final rgbBrightness = <String, double>{};
    final ultrasonic = <int, double>{};
    final dhtTemp = <int, double>{};
    final dhtHum = <int, double>{};

    double voltageAt(String cid, String pinId) {
      final net = netlist.netOf(cid, pinId);
      if (net < 0) return 0;
      return netVoltage[net] ?? 0;
    }

    for (final c in circuit.components) {
      switch (c.type) {
        case ComponentType.led:
          final current = (voltageAt(c.id, 'A') - voltageAt(c.id, 'C')) /
              ledResistance;
          ledBrightness[c.id] = (current.abs() / 0.02).clamp(0.0, 1.0);
          if (current.abs() > 0.05) {
            warnings.add(S.t('warn.ledCurrent', {'id': c.id}));
          }
        case ComponentType.rgbLed:
          for (final ch in const ['R', 'G', 'B']) {
            final current = (voltageAt(c.id, ch) - voltageAt(c.id, 'C')) /
                ledResistance;
            rgbBrightness['${c.id}:$ch'] =
                (current.abs() / 0.02).clamp(0.0, 1.0);
          }
        case ComponentType.ultrasonic:
          final logic = logicOfNet[netlist.netOf(c.id, 'ECHO')];
          if (logic == null) {
            warnings.add(S.t('warn.ultrasonicEcho'));
            break;
          }
          final cm = (c.properties['distance'] as num?)?.toDouble() ?? 100;
          ultrasonic[logic] = cm.clamp(2.0, 400.0);
        case ComponentType.dht11:
          final logic = logicOfNet[netlist.netOf(c.id, 'DATA')];
          if (logic == null) {
            warnings.add(S.t('warn.dhtData'));
            break;
          }
          dhtTemp[logic] =
              ((c.properties['temperature'] as num?)?.toDouble() ?? 25)
                  .clamp(-40.0, 80.0);
          dhtHum[logic] =
              ((c.properties['humidity'] as num?)?.toDouble() ?? 60)
                  .clamp(0.0, 100.0);
        case ComponentType.robotCar:
          // Both onboard HC-SR04s are optional hardware: stay quiet when an ECHO
          // header is not wired, and otherwise report exactly like a discrete
          // sensor so `read distance` works unchanged. The front sensor is ECHO,
          // the rear one is ECHO2.
          final frontLogic = logicOfNet[netlist.netOf(c.id, 'ECHO')];
          if (frontLogic != null) {
            final cm = (c.properties['distance'] as num?)?.toDouble() ?? 100;
            ultrasonic[frontLogic] = cm.clamp(2.0, 400.0);
          }
          final rearLogic = logicOfNet[netlist.netOf(c.id, 'ECHO2')];
          if (rearLogic != null) {
            final cm = (c.properties['distanceBehind'] as num?)?.toDouble() ?? 100;
            ultrasonic[rearLogic] = cm.clamp(2.0, 400.0);
          }
        case ComponentType.arduinoUno:
        case ComponentType.breadboard:
        case ComponentType.resistor:
        case ComponentType.photoresistor:
        case ComponentType.pushButton:
        case ComponentType.potentiometer:
        case ComponentType.joystick:
        case ComponentType.servo:
        case ComponentType.buzzer:
        case ComponentType.lcd16x2:
        case ComponentType.robotArm:
        case ComponentType.armBase:
        case ComponentType.armLink:
        case ComponentType.armGripper:
          break;
      }
    }

    return CircuitSolution(
      netVoltage: netVoltage,
      logicalPinNet: logicalPinNet,
      ledBrightness: ledBrightness,
      rgbBrightness: rgbBrightness,
      ultrasonicDistanceByEchoPin: ultrasonic,
      dhtTemperatureByDataPin: dhtTemp,
      dhtHumidityByDataPin: dhtHum,
      pwmByPin: runtime.pwmValue,
      warnings: warnings,
    );
  }

  /// A control position in 0..1: the parts the user drags report where they were
  /// told to sit, so clamp what reaches the matrix.
  static double _lever(Object? value) =>
      ((value as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);

  /// Gaussian elimination with partial pivoting.
  static List<double> _gauss(List<List<double>> a, List<double> b) {
    final n = b.length;
    for (var col = 0; col < n; col++) {
      var pivot = col;
      var best = a[col][col].abs();
      for (var row = col + 1; row < n; row++) {
        final v = a[row][col].abs();
        if (v > best) {
          best = v;
          pivot = row;
        }
      }
      if (best < 1e-18) continue;
      if (pivot != col) {
        final rowTmp = a[pivot];
        a[pivot] = a[col];
        a[col] = rowTmp;
        final bTmp = b[pivot];
        b[pivot] = b[col];
        b[col] = bTmp;
      }
      final pivotValue = a[col][col];
      for (var row = col + 1; row < n; row++) {
        final factor = a[row][col] / pivotValue;
        if (factor == 0) continue;
        for (var k = col; k < n; k++) {
          a[row][k] -= factor * a[col][k];
        }
        b[row] -= factor * b[col];
      }
    }
    final x = List<double>.filled(n, 0);
    for (var row = n - 1; row >= 0; row--) {
      var sum = b[row];
      for (var k = row + 1; k < n; k++) {
        sum -= a[row][k] * x[k];
      }
      final diag = a[row][row];
      x[row] = diag.abs() < 1e-18 ? 0 : sum / diag;
    }
    return x;
  }
}
