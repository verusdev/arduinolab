import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/examples/examples.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/models/pin.dart';

void main() {
  group('Pin labels', () {
    test('sensors print their full header names', () {
      expect(
        ComponentSpecs.of(ComponentType.ultrasonic)
            .pins
            .map((p) => p.displayName)
            .toList(),
        ['VCC', 'GND', 'TRIG', 'ECHO'],
      );
      expect(
        ComponentSpecs.of(ComponentType.dht11)
            .pins
            .map((p) => p.displayName)
            .toList(),
        ['VCC', 'DATA', 'GND'],
      );
    });

    test('actuators and the display keep readable names', () {
      expect(
        ComponentSpecs.of(ComponentType.servo)
            .pins
            .map((p) => p.displayName)
            .toList(),
        ['VCC', 'GND', 'SIG'],
      );
      expect(
        ComponentSpecs.of(ComponentType.lcd16x2)
            .pins
            .map((p) => p.displayName)
            .toList(),
        ['GND', 'VCC', 'SDA', 'SCL'],
      );
    });

    test('LED anode and cathode stay distinguishable', () {
      expect(
        ComponentSpecs.of(ComponentType.led)
            .pins
            .map((p) => p.displayName)
            .toList(),
        ['A', 'C'],
      );
    });

    test('purely positional names are flagged so they can be hidden', () {
      final pins = ComponentSpecs.of(ComponentType.potentiometer).pins;
      // The wiper keeps its meaningful `W`, the two ends stay positional.
      expect(pins.map((p) => p.displayName).toList(), ['1', 'W', '3']);
      expect(pins.firstWhere((p) => p.displayName == '1').hasGenericName, isTrue);
      expect(pins.firstWhere((p) => p.displayName == '3').hasGenericName, isTrue);
      expect(pins.firstWhere((p) => p.displayName == 'W').hasGenericName, isFalse);

      final button = ComponentSpecs.of(ComponentType.pushButton).pins;
      expect(button.every((p) => p.hasGenericName), isTrue);
    });

    test('board pins are never hidden behind a generic name', () {
      final board = ComponentSpecs.of(ComponentType.arduinoUno).pins;
      expect(board, isNotEmpty);
      expect(board.any((p) => p.hasGenericName), isFalse);
    });

    test('the board silkscreens every header, ground rails included', () {
      final labels = ComponentSpecs.of(ComponentType.arduinoUno)
          .pins
          .map((p) => p.displayName)
          .toList();
      expect(labels.where((l) => l.startsWith('D')).toList(), hasLength(14));
      expect(labels.where((l) => l.startsWith('A')).toList(), hasLength(6));
      expect(labels.where((l) => l == 'GND').toList(), hasLength(2));
      expect(labels, containsAll(<String>['VIN', '3V3', '5V']));
    });

    test('serial monitor pins survive as named headers', () {
      const pin = Pin('TRIG', 'TRIG', 0, 0, PinKind.digital);
      expect(pin.displayName, 'TRIG');
      expect(pin.hasGenericName, isFalse);
    });
  });

  group('Example wiring', () {
    test('every wire lands on a pin that actually exists', () {
      for (final example in Examples.all) {
        final circuit = example.build().circuit;
        for (final wire in circuit.wires) {
          final a = circuit.componentById(wire.aComponent);
          final b = circuit.componentById(wire.bComponent);
          expect(a, isNotNull, reason: '${example.id}: ${wire.aComponent}');
          expect(b, isNotNull, reason: '${example.id}: ${wire.bComponent}');
          expect(ComponentSpecs.pin(a!.type, wire.aPin), isNotNull,
              reason: '${example.id}: ${a.type.name}.${wire.aPin}');
          expect(ComponentSpecs.pin(b!.type, wire.bPin), isNotNull,
              reason: '${example.id}: ${b.type.name}.${wire.bPin}');
        }
      }
    });

    test('sensor examples power their sensors', () {
      for (final id in ['ultrasonic', 'dht11']) {
        final circuit = Examples.byId(id)!.build().circuit;
        final sensor = circuit.components
            .firstWhere((c) => c.spec.category == 'Sensors');
        final wired = <String>{};
        for (final wire in circuit.wires) {
          if (wire.aComponent == sensor.id) wired.add(wire.aPin);
          if (wire.bComponent == sensor.id) wired.add(wire.bPin);
        }
        expect(wired, contains('VCC'), reason: id);
        expect(wired, contains('GND'), reason: id);
      }
    });

    test('every non-sensor component has a name for each of its pins', () {
      for (final type in ComponentType.values) {
        for (final pin in ComponentSpecs.of(type).pins) {
          expect(pin.displayName, isNotEmpty, reason: type.name);
        }
      }
    });
  });
}
