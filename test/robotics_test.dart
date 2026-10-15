import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/engine/robotics.dart';
import 'package:arduino_lab/engine/simulation_engine.dart';
import 'package:arduino_lab/examples/examples.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/models/geometry.dart';

/// A board plus a rig wired the way the bundled examples wire them, so the
/// electrical-to-mechanical mapping can be exercised without the UI.
(SimulationEngine, PlacedComponent) _rig(String rigId, ComponentType type,
    List<(String pin, String boardPin)> links) {
  final uno = PlacedComponent(
      id: 'uno', type: ComponentType.arduinoUno, x: 0, y: 0);
  final rig = PlacedComponent(id: rigId, type: type, x: 400, y: 0);
  final wires = <Wire>[
    for (final (pin, boardPin) in links)
      Wire(
          id: '$rigId$pin',
          aComponent: rigId,
          aPin: pin,
          bComponent: 'uno',
          bPin: boardPin),
  ];
  final circuit = Circuit(components: [uno, rig], wires: wires);
  return (SimulationEngine(circuit: circuit), rig);
}

/// What a run of a car example produced.
typedef DriveResult = ({RigPose pose, double before, double after});

void main() {
  group('Car kinematics', () {
    test('equal wheel speeds drive straight along the heading', () {
      final next = CarPhysics.step(const RigPose(100, 200, 0), 1, 1, 1);
      expect(next.x, closeTo(100 + CarPhysics.fullSpeedPx, 0.001));
      expect(next.y, closeTo(200, 0.001));
      expect(next.headingDeg, closeTo(0, 0.001));
    });

    test('a spinning pair rotates in place without translating', () {
      final next = CarPhysics.step(const RigPose(100, 200, 0), -1, 1, 1);
      expect(next.x, closeTo(100, 0.001));
      expect(next.y, closeTo(200, 0.001));
      expect(next.headingDeg, greaterThan(0));
    });

    test('the heading wraps instead of going negative', () {
      final next = CarPhysics.step(const RigPose(0, 0, 10), 1, -1, 1);
      expect(next.headingDeg, inInclusiveRange(0, 360));
    });

    test('reversing retraces the heading', () {
      final next = CarPhysics.step(const RigPose(100, 200, 0), -1, -1, 1);
      expect(next.x, closeTo(100 - CarPhysics.fullSpeedPx, 0.001));
    });

    test('the wheel graphics advance and wrap', () {
      final phase = CarPhysics.advanceWheelPhase(0, 1, 1, 1);
      expect(phase, greaterThan(0));
      expect(phase, lessThan(360));
      // Enough travel to wrap several times still lands in one turn.
      expect(CarPhysics.advanceWheelPhase(0, 1, 1, 100),
          inInclusiveRange(0, 360));
      // Standing still leaves the wheels where they were.
      expect(CarPhysics.advanceWheelPhase(12.5, 0, 0, 1), 12.5);
    });

    test('the ray stops at the border it is pointing at', () {
      expect(CarPhysics.rayToBorder(100, 800, 0, 2400, 1600), 2300);
      expect(CarPhysics.rayToBorder(100, 800, 180, 2400, 1600), 100);
      expect(CarPhysics.rayToBorder(100, 800, 90, 2400, 1600), 800);
      expect(CarPhysics.rayToBorder(100, 800, 270, 2400, 1600), 800);
    });

    test('the onboard sensor reports the gap ahead in centimetres', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 1000, y: 0);
      const pose = RigPose(1000, 0, 0);
      // Centre at 1070, nose 70 further on, so 1260 px of clear road.
      expect(CarPhysics.clearanceCm(pose, car, 2400, 1600),
          closeTo(1260 / CarPhysics.pxPerCm, 0.001));
    });

    test('the sensor never reports less than nothing', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 2250, y: 0);
      const pose = RigPose(2250, 0, 0);
      expect(CarPhysics.clearanceCm(pose, car, 2400, 1600), 2.0);
    });

    test('a rotated body measures along its own length', () {
      expect(CarPhysics.halfExtentAlong(140, 100, 0), closeTo(70, 1e-9));
      expect(CarPhysics.halfExtentAlong(140, 100, 90), closeTo(50, 1e-9));
    });

    test('the body is kept inside the workspace', () {
      final clamped = CarPhysics.clampToField(
          const RigPose(-50, 2000, 0), 140, 100, 2400, 1600);
      expect(clamped.x, 0);
      expect(clamped.y, 1500);
      expect(clamped.headingDeg, 0);
    });
  });

  group('Rig wiring', () {
    test('a bridge drives forward, backward and brakes', () {
      final (engine, car) = _rig('car', ComponentType.robotCar,
          const [('IN1', 'D4'), ('IN2', 'D5'), ('EN1', 'D9')]);
      final rt = engine.runtime;
      for (final pin in [4, 5, 9]) {
        rt.isOutput[pin] = true;
      }
      rt.pwmValue[9] = 255;

      rt.digitalValue[4] = 1;
      rt.digitalValue[5] = 0;
      expect(readRigCommands(engine, car).left, closeTo(1.0, 1e-9));

      rt.digitalValue[4] = 0;
      rt.digitalValue[5] = 1;
      expect(readRigCommands(engine, car).left, closeTo(-1.0, 1e-9));

      // Both inputs equal means the bridge is braking, so the motor is silent.
      rt.digitalValue[4] = 1;
      expect(readRigCommands(engine, car).left, 0);
    });

    test('the enable input scales the speed', () {
      final (engine, car) = _rig('car', ComponentType.robotCar,
          const [('IN1', 'D4'), ('IN2', 'D5'), ('EN1', 'D9')]);
      final rt = engine.runtime;
      for (final pin in [4, 5, 9]) {
        rt.isOutput[pin] = true;
      }
      rt.digitalValue[4] = 1;
      rt.digitalValue[5] = 0;
      rt.pwmValue[9] = 128;
      expect(readRigCommands(engine, car).left, closeTo(128 / 255, 1e-9));
    });

    test('a floating rig reads as idle rather than crashing', () {
      final (engine, car) = _rig('car', ComponentType.robotCar, const []);
      expect(readRigCommands(engine, car).isIdle, isTrue);
    });

    test('arm joints follow the servo angles on their pins', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm, const [
        ('BASE', 'D3'),
        ('SHLD', 'D5'),
        ('ELBW', 'D6'),
        ('GRIP', 'D9'),
      ]);
      final rt = engine.runtime;
      rt.servoAngle[3] = 40;
      rt.servoAngle[5] = 120;
      rt.servoAngle[6] = 135;
      rt.servoAngle[9] = 165;
      expect(readRigCommands(engine, arm).joints, [40, 120, 135, 165]);
    });

    test('an unwired joint rests at zero', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm, const []);
      expect(readRigCommands(engine, arm).joints, [0, 0, 0, 0]);
    });
  });

  group('Robots in simulation', () {
    /// Mirrors what AppState does every frame, so the examples can be checked
    /// without a widget tree: tick the program, then step the car by however
    /// much firmware time that frame consumed.
    DriveResult drive(String exampleId, int frames,
        {double? x, double? y}) {
      final project = Examples.byId(exampleId)!.build();
      final car = project.circuit.components
          .firstWhere((c) => c.type == ComponentType.robotCar);
      if (x != null) car.x = x;
      if (y != null) car.y = y;
      car.rotation = 0;

      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      engine.start();

      var pose = RigPose(car.x, car.y, car.rotation);
      final before =
          CarPhysics.clearanceCm(pose, car, kWorkspaceWidth, kWorkspaceHeight);
      var lastUs = engine.runtime.timeUs;

      for (var i = 0; i < frames; i++) {
        engine.tick(0.016);
        final nowUs = engine.runtime.timeUs;
        final elapsed = ((nowUs - lastUs) / 1e6).clamp(0.0, 0.5);
        lastUs = nowUs;

        final commands = readRigCommands(engine, car);
        pose = CarPhysics.clampToField(
            CarPhysics.step(pose, commands.left, commands.right, elapsed),
            car.width,
            car.height,
            kWorkspaceWidth,
            kWorkspaceHeight);
        car.x = pose.x;
        car.y = pose.y;
        car.rotation = pose.headingDeg;
        car.properties['distance'] =
            CarPhysics.clearanceCm(pose, car, kWorkspaceWidth, kWorkspaceHeight);
      }

      final after =
          CarPhysics.clearanceCm(pose, car, kWorkspaceWidth, kWorkspaceHeight);
      return (pose: pose, before: before, after: after);
    }

    test('the car example drives forward on a clear road', () {
      final result = drive('robot_car', 60, x: 600, y: 700);
      expect(result.pose.x, greaterThan(600));
      expect(result.pose.headingDeg, closeTo(0, 1));
      expect(result.after, lessThan(result.before),
          reason: 'the gap ahead keeps shrinking');
    });

    test('the waiting turn really turns the car', () {
      // The spin branch waits 220 ms, which must be 220 ms of motor time, not
      // one 16 ms frame.
      final pose = CarPhysics.step(const RigPose(2180, 700, 0), -130 / 255,
          130 / 255, 0.22);
      expect(pose.headingDeg, greaterThan(30));
    });

    test('the car example steers away from the wall', () {
      final result = drive('robot_car', 120, x: 2180, y: 700);
      expect(result.pose.headingDeg, greaterThan(20));
      expect(result.pose.x, inInclusiveRange(0, kWorkspaceWidth - 140));
      expect(result.pose.y, inInclusiveRange(0, kWorkspaceHeight - 100));
    });

    test('the car sensor feeds "read distance" through the netlist', () {
      final project = Examples.byId('robot_car')!.build();
      final car = project.circuit.components
          .firstWhere((c) => c.type == ComponentType.robotCar);
      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      expect(engine.resolveLogicPin(car.id, 'ECHO'), 12);
      engine.start();
      for (var i = 0; i < 5; i++) {
        engine.tick(0.016);
      }
      expect(engine.solution.ultrasonicDistanceByEchoPin.containsKey(12), isTrue,
          reason: 'the onboard sensor must behave like a discrete HC-SR04');
    });

    test('a hand-set ultrasonic still works', () {
      final project = Examples.byId('ultrasonic')!.build();
      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      engine.start();
      for (var i = 0; i < 5; i++) {
        engine.tick(0.016);
      }
      expect(engine.solution.ultrasonicDistanceByEchoPin[6], 100);
    });

    test('the arm example plays its pick and place cycle', () {
      final project = Examples.byId('robot_arm')!.build();
      final arm = project.circuit.components
          .firstWhere((c) => c.type == ComponentType.robotArm);
      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      engine.start();

      // A `wait` ends the frame, so each frame advances one step of the cycle.
      final bases = <double>{};
      final grips = <double>{};
      for (var i = 0; i < 8; i++) {
        engine.tick(0.016);
        final joints = readRigCommands(engine, arm).joints;
        bases.add(joints[0]);
        grips.add(joints[3]);
        if (i == 0) {
          expect(joints, [40, 120, 135, 0],
              reason: 'the pick pose is reached before the first wait');
        }
      }
      expect(bases, containsAll(<double>[40, 135]));
      expect(grips, containsAll(<double>[165, 20]));
    });
  });

  group('Robot specs', () {
    test('the car exposes a driver, a motor pair and a sensor', () {
      final pins = ComponentSpecs.of(ComponentType.robotCar).pins;
      expect(pins.map((p) => p.id).toList(), [
        'IN1',
        'IN2',
        'IN3',
        'IN4',
        'EN1',
        'EN2',
        '5V',
        'GND',
        'TRIG',
        'ECHO'
      ]);
      expect(pins.every((p) => p.displayName.isNotEmpty), isTrue);
      expect(ComponentSpecs.of(ComponentType.robotCar).category, 'Robotics');
    });

    test('the arm exposes four joint servos plus power', () {
      final pins = ComponentSpecs.of(ComponentType.robotArm).pins;
      expect(pins.map((p) => p.id).toList(),
          ['BASE', 'SHLD', 'ELBW', 'GRIP', '5V', 'GND']);
      expect(ComponentSpecs.of(ComponentType.robotArm).category, 'Robotics');
    });

    test('robot headers are far enough apart to be tapped', () {
      for (final type in [ComponentType.robotCar, ComponentType.robotArm]) {
        final pins = ComponentSpecs.of(type).pins;
        for (var i = 0; i < pins.length; i++) {
          for (var j = i + 1; j < pins.length; j++) {
            final gap = (pins[i].dx - pins[j].dx).abs() +
                (pins[i].dy - pins[j].dy).abs();
            expect(gap, greaterThanOrEqualTo(18),
                reason: '${type.name}: ${pins[i].id}/${pins[j].id}');
          }
        }
      }
    });

    test('a fresh car has the properties the physics expects', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 0, y: 0);
      expect(car.properties['distance'], 100.0);
      expect(car.properties['autoDistance'], isTrue);
      expect(car.properties['wheelPhase'], 0.0);
    });

    test('the examples exist and are wired', () {
      for (final id in ['robot_car', 'robot_arm']) {
        final example = Examples.byId(id);
        expect(example, isNotNull, reason: id);
        final circuit = example!.build().circuit;
        expect(circuit.wires, isNotEmpty);
        expect(circuit.components, hasLength(2));
      }
    });
  });
}
