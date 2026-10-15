import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/blocks/block_model.dart';
import 'package:arduino_lab/blocks/sketch_printer.dart';
import 'package:arduino_lab/engine/netlist.dart';
import 'package:arduino_lab/engine/runtime.dart';
import 'package:arduino_lab/engine/simulation_engine.dart';
import 'package:arduino_lab/engine/solver.dart';
import 'package:arduino_lab/engine/vm.dart';
import 'package:arduino_lab/examples/examples.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/services/storage_service.dart';

PlacedComponent _uno([double x = 0, double y = 0]) =>
    PlacedComponent(id: 'uno', type: ComponentType.arduinoUno, x: x, y: y);

/// Builds the classic blink circuit: D13 -> 220Ω -> LED -> GND.
Circuit _blinkCircuit() => Circuit(
      components: [
        _uno(),
        PlacedComponent(
          id: 'r1',
          type: ComponentType.resistor,
          x: 300,
          y: 0,
          properties: {'resistance': 220.0},
        ),
        PlacedComponent(id: 'led1', type: ComponentType.led, x: 300, y: 80),
      ],
      wires: [
        Wire(
            id: 'w1',
            aComponent: 'uno',
            aPin: 'D13',
            bComponent: 'r1',
            bPin: '1'),
        Wire(id: 'w2', aComponent: 'r1', aPin: '2', bComponent: 'led1', bPin: 'A'),
        Wire(
            id: 'w3',
            aComponent: 'led1',
            aPin: 'C',
            bComponent: 'uno',
            bPin: 'GND3'),
      ],
    );

void main() {
  group('Netlist', () {
    test('wires merge pins into the same electrical net', () {
      final netlist = Netlist.build(_blinkCircuit());

      expect(netlist.netOf('uno', 'D13'), isNot(-1));
      expect(netlist.netOf('uno', 'D13'), netlist.netOf('r1', '1'));
      expect(netlist.netOf('r1', '2'), netlist.netOf('led1', 'A'));
      expect(netlist.netOf('led1', 'C'), netlist.netOf('uno', 'GND3'));

      // Two ends that are not wired together must stay apart.
      expect(netlist.netOf('uno', 'D13'), isNot(netlist.netOf('led1', 'A')));
      // Unconnected pins report -1.
      expect(netlist.netOf('uno', 'D2'), isNot(netlist.netOf('uno', 'D3')));
    });
  });

  group('Solver', () {
    test('LED brightness follows digitalWrite (5V through 220Ω + 180Ω LED)',
        () {
      final circuit = _blinkCircuit();
      final netlist = Netlist.build(circuit);
      final runtime = ArduinoRuntime()
        ..started = true
        ..isOutput[13] = true
        ..digitalValue[13] = 1;

      final on = Solver.solve(circuit, netlist, runtime, const {});
      // 2.25 V across a 180Ω model -> 12.5 mA -> 0.625 of the 20 mA full scale.
      expect(on.ledBrightness['led1'], closeTo(0.625, 0.01));

      runtime.digitalValue[13] = 0;
      final off = Solver.solve(circuit, netlist, runtime, const {});
      expect(off.ledBrightness['led1'], closeTo(0.0, 0.001));
    });

    test('analogRead reads the middle of a potentiometer as ~511', () {
      final circuit = Circuit(
        components: [
          _uno(),
          PlacedComponent(
            id: 'pot1',
            type: ComponentType.potentiometer,
            x: 300,
            y: 0,
            properties: {'position': 0.5},
          ),
        ],
        wires: [
          Wire(
              id: 'p1',
              aComponent: 'pot1',
              aPin: '1',
              bComponent: 'uno',
              bPin: '5V0'),
          Wire(
              id: 'p2',
              aComponent: 'pot1',
              aPin: '3',
              bComponent: 'uno',
              bPin: 'GND3'),
          Wire(
              id: 'p3',
              aComponent: 'pot1',
              aPin: '2',
              bComponent: 'uno',
              bPin: 'A0'),
        ],
      );
      final solution = Solver.solve(
          circuit, Netlist.build(circuit), ArduinoRuntime()..started = true,
          const {});

      // A0 is logical pin 14.
      expect(solution.pinVoltage(14), closeTo(2.5, 0.05));
      expect(solution.analogRead(14), closeTo(511.5, 3));
    });
  });

  group('Virtual machine', () {
    test('runs a blink loop and toggles the pin both ways', () {
      final program = BlockProgram(
        setup: [
          Block(kind: BlockKind.setPinMode, params: {'pin': 13, 'mode': 'OUTPUT'}),
        ],
        loop: [
          Block(kind: BlockKind.digitalWrite, params: {'pin': 13, 'value': 'HIGH'}),
          Block(kind: BlockKind.wait, params: {'ms': 1000.0}),
          Block(kind: BlockKind.digitalWrite, params: {'pin': 13, 'value': 'LOW'}),
          Block(kind: BlockKind.wait, params: {'ms': 1000.0}),
        ],
      );

      final runtime = ArduinoRuntime()..started = true;
      final vm = Vm(SketchCompiler.compile(program))..reset();

      final seen = <double>{};
      for (var i = 0; i < 400 && seen.length < 2; i++) {
        vm.step(runtime, CircuitSolution.empty());
        final value = runtime.digitalValue[13];
        if (value != null) seen.add(value);
      }

      expect(runtime.isPinOutput(13), isTrue);
      expect(seen, containsAll(<double>[0.0, 1.0]));
    });
  });

  group('SketchPrinter', () {
    test('renders an Arduino sketch with setup() and digitalWrite', () {
      final program = BlockProgram(
        setup: [
          Block(kind: BlockKind.setPinMode, params: {'pin': 13, 'mode': 'OUTPUT'}),
        ],
        loop: [
          Block(kind: BlockKind.digitalWrite, params: {'pin': 13, 'value': 'HIGH'}),
          Block(kind: BlockKind.wait, params: {'ms': 500.0}),
        ],
      );

      final sketch = SketchPrinter.print(program);
      expect(sketch, contains('void setup()'));
      expect(sketch, contains('digitalWrite(13, HIGH);'));
      expect(sketch, contains('delay(500);'));
    });
  });

  group('StorageService JSON round-trip', () {
    test('a project survives encode/decode unchanged', () {
      final storage = StorageService();
      final project = Examples.byId('pot_led')!.build();

      final encoded = storage.encode(project);
      final decoded = storage.decode(encoded);

      expect(decoded.name, project.name);
      expect(decoded.circuit.components.length, project.circuit.components.length);
      expect(decoded.circuit.wires.length, project.circuit.wires.length);
      // Re-encoding must be byte-for-byte stable (proves no data was lost).
      expect(storage.encode(decoded), encoded);
    });
  });

  group('Built-in examples', () {
    test('every example compiles and ticks without throwing', () {
      for (final example in Examples.all) {
        final project = example.build();
        final engine = SimulationEngine(
          circuit: project.circuit,
          program: project.program,
        );
        engine.start();
        for (var frame = 0; frame < 20; frame++) {
          engine.tick(0.02);
        }
        expect(engine.serial.length, lessThan(600), reason: example.id);
      }
    });

    test('the ultrasonic example prints the measured distance', () {
      final project = Examples.byId('ultrasonic')!.build();
      final engine = SimulationEngine(
        circuit: project.circuit,
        program: project.program,
      );
      engine.start();
      engine.tick(0.02);

      expect(engine.serial, isNotEmpty);
      expect(engine.serial.first, '100');
    });
  });
}
