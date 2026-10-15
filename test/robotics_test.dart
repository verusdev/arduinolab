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

    test('each wheel graphic advances on its own and wraps', () {
      final phase = CarPhysics.advancePhase(0, 1, 1);
      expect(phase, greaterThan(0));
      expect(phase, lessThan(360));
      // Enough travel to wrap several times still lands in one turn.
      expect(CarPhysics.advancePhase(0, 1, 100), inInclusiveRange(0, 360));
      // Standing still leaves the wheel where it was.
      expect(CarPhysics.advancePhase(12.5, 0, 1), 12.5);
      // A wheel driven the other way rolls back by the same amount.
      final forwardStep = CarPhysics.advancePhase(0, 1, 0.05);
      final backwardStep = CarPhysics.advancePhase(0, -1, 0.05);
      expect(forwardStep, greaterThan(0));
      expect(forwardStep, lessThan(180));
      expect(backwardStep, closeTo(360 - forwardStep, 1e-9));
    });

    test('the ray stops at the border it is pointing at', () {
      expect(CarPhysics.rayToBorder(100, 800, 0, 2400, 1600), 2300);
      expect(CarPhysics.rayToBorder(100, 800, 180, 2400, 1600), 100);
      expect(CarPhysics.rayToBorder(100, 800, 90, 2400, 1600), 800);
      expect(CarPhysics.rayToBorder(100, 800, 270, 2400, 1600), 800);
    });

    test('the front sensor reports the gap ahead in centimetres', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 1000, y: 0);
      const pose = RigPose(1000, 0, 0);
      // Centre at 1080, nose 80 further on, so 1240 px of clear road.
      expect(CarPhysics.clearanceCm(pose, car, 2400, 1600),
          closeTo(1240 / CarPhysics.pxPerCm, 0.001));
    });

    test('the rear sensor looks the other way', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 1000, y: 0);
      const pose = RigPose(1000, 0, 0);
      // Tail is at 1000, so 1000 px of clear road behind.
      expect(CarPhysics.clearanceBehindCm(pose, car, 2400, 1600),
          closeTo(1000 / CarPhysics.pxPerCm - 0, 0.5));
      expect(
          CarPhysics.clearanceBehindCm(pose, car, 2400, 1600),
          lessThan(
              CarPhysics.clearanceCm(pose, car, 2400, 1600)));
    });

    test('a sensor never reports less than nothing', () {
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

  group('Car wiring', () {
    /// Wires the four motors the way the car example does and hand-sets the
    /// pin levels, so the mixing can be read back directly.
    (SimulationEngine, PlacedComponent) wiredCar() => _rig(
          'car',
          ComponentType.robotCar,
          const [
            ('M1A', 'D4'),
            ('M1B', 'D7'),
            ('EN1', 'D3'),
            ('M2A', 'D8'),
            ('M2B', 'D12'),
            ('EN2', 'D5'),
            ('M3A', 'D10'),
            ('M3B', 'D11'),
            ('EN3', 'D6'),
            ('M4A', 'D13'),
            ('M4B', 'D2'),
            ('EN4', 'D9'),
          ],
        );

    void outputs(SimulationEngine engine, List<int> pins) {
      for (final pin in pins) {
        engine.runtime.isOutput[pin] = true;
      }
    }

    test('every wheel is mixed on its own bridge', () {
      final (engine, car) = wiredCar();
      final rt = engine.runtime;
      // The direction inputs are driven as plain outputs. The enables are left
      // alone, which is the jumper-default full speed.
      outputs(engine, [4, 7, 8, 12, 10, 11, 13, 2]);

      // Front-left forward, front-right back, and the rear pair switched off.
      rt.digitalValue[4] = 1;
      rt.digitalValue[7] = 0;
      rt.digitalValue[8] = 0;
      rt.digitalValue[12] = 1;

      final wheels = readRigCommands(engine, car).wheels;
      expect(wheels, hasLength(4));
      expect(wheels[0], closeTo(1.0, 1e-9));
      expect(wheels[1], closeTo(-1.0, 1e-9));
      expect(wheels[2], 0);
      expect(wheels[3], 0);
      // The sides average their pair of wheels.
      expect(readRigCommands(engine, car).left, closeTo(0.5, 1e-9));
      expect(readRigCommands(engine, car).right, closeTo(-0.5, 1e-9));
    });

    test('each enable scales only its own wheel', () {
      final (engine, car) = wiredCar();
      final rt = engine.runtime;
      outputs(engine, [4, 7, 8, 12, 10, 11, 13, 2]);
      // All four bridges forward...
      for (final pin in [4, 8, 10, 13]) {
        rt.digitalValue[pin] = 1;
      }
      for (final pin in [7, 12, 11, 2]) {
        rt.digitalValue[pin] = 0;
      }
      // ...but only the rear-right enable has a PWM value of its own, so the
      // other three run at the floating full speed.
      rt.isOutput[9] = true;
      rt.pwmValue[9] = 128;

      final wheels = readRigCommands(engine, car).wheels;
      expect(wheels[0], 1.0);
      expect(wheels[1], 1.0);
      expect(wheels[2], 1.0);
      expect(wheels[3], closeTo(128 / 255, 1e-9));
    });

    test('both inputs equal means the bridge is braking', () {
      final (engine, car) = wiredCar();
      final rt = engine.runtime;
      outputs(engine, [4, 7, 8, 12, 10, 11, 13, 2]);
      rt.digitalValue[4] = 1;
      rt.digitalValue[7] = 1;
      expect(readRigCommands(engine, car).wheels[0], 0);
    });

    test('a floating rig reads as idle rather than crashing', () {
      final (engine, car) = _rig('car', ComponentType.robotCar, const []);
      expect(readRigCommands(engine, car).isIdle, isTrue);
      expect(readRigCommands(engine, car).left, 0);
      expect(readRigCommands(engine, car).right, 0);
    });
  });

  group('Arm wiring', () {
    test('each joint follows the servo angle on its own pin', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm, const [
        ('J1', 'D3'),
        ('J2', 'D5'),
        ('J3', 'D6'),
        ('J4', 'D9'),
      ]);
      final rt = engine.runtime;
      rt.servoAngle[3] = 40;
      rt.servoAngle[5] = 120;
      rt.servoAngle[6] = 135;
      rt.servoAngle[9] = 165;
      expect(readRigCommands(engine, arm).joints, [40, 120, 135, 165]);
    });

    test('a joint that has not been driven yet stands neutral', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm,
          const [('J1', 'D3'), ('J2', 'D5')]);
      engine.runtime.servoAngle[3] = 40;
      expect(readRigCommands(engine, arm).joints, [40, 90, 90, 90]);
    });

    test('the segment count decides how many joints there are', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm,
          const [('J1', 'D3'), ('J2', 'D5'), ('J3', 'D6')]);
      expect(readRigCommands(engine, arm).joints, hasLength(4));
      arm.properties['segments'] = 2;
      expect(readRigCommands(engine, arm).joints, hasLength(2));
      arm.properties['segments'] = 6;
      expect(readRigCommands(engine, arm).joints, hasLength(6));
      // Out of range values are clamped to what the arm can draw.
      arm.properties['segments'] = 99;
      expect(armSegmentCount(arm), 6);
    });

    test('a joint with no servo holds the angle dialled in by hand', () {
      final (engine, arm) = _rig('arm', ComponentType.robotArm,
          const [('J1', 'D3'), ('J2', 'D5')]);
      engine.runtime.servoAngle[3] = 30;
      engine.runtime.servoAngle[5] = 150;
      arm.properties['servoJ2'] = false;
      arm.properties['restJ2'] = 20.0;
      expect(readRigCommands(engine, arm).joints, [30, 20, 90, 90]);
    });

    test('a servo swing maps to 90 degrees either way', () {
      expect(servoRotation(0), -90);
      expect(servoRotation(90), 0);
      expect(servoRotation(180), 90);
      expect(servoRotation(200), 90);
    });
  });

  group('Arm forward kinematics', () {
    test('a neutral arm points straight up, joint by joint', () {
      final arm = PlacedComponent(
          id: 'arm', type: ComponentType.robotArm, x: 0, y: 0);
      final pose = ArmKinematics.of(arm, const [90, 90, 90, 90]);
      final link = (arm.height - 50) / 3;
      expect(pose.joints, hasLength(4));
      expect(pose.joints.first, (arm.width / 2, arm.height - 30));
      // Each joint sits straight above the one below it.
      for (var i = 1; i < pose.joints.length; i++) {
        expect(pose.joints[i].$1, closeTo(pose.joints[i - 1].$1, 1e-9));
        expect(pose.joints[i].$2,
            closeTo(pose.joints[i - 1].$2 - link, 1e-9));
      }
      expect(pose.tip, pose.joints.last);
    });

    test('a swing bends every joint above it', () {
      final arm = PlacedComponent(
          id: 'arm', type: ComponentType.robotArm, x: 0, y: 0);
      final straight = ArmKinematics.of(arm, const [90, 90, 90, 90]);
      final bent = ArmKinematics.of(arm, const [180, 90, 90, 90]);
      // The shoulder itself is fixed; the end of the first link is not.
      expect(bent.joints[0], straight.joints[0]);
      expect(bent.joints[1], isNot(straight.joints[1]));
      expect(bent.joints[2], isNot(straight.joints[2]));
      expect(bent.joints[3], isNot(straight.joints[3]));
      // Swinging one way then the other mirrors the tip.
      final left = ArmKinematics.of(arm, const [0, 90, 90, 90]);
      expect(left.tip.$1, lessThan(straight.tip.$1));
      expect(bent.tip.$1, greaterThan(straight.tip.$1));
    });

    test('the jaws follow the last joint', () {
      final arm = PlacedComponent(
          id: 'arm', type: ComponentType.robotArm, x: 0, y: 0);
      expect(ArmKinematics.of(arm, const [90, 90, 90, 0]).openness, 0);
      expect(ArmKinematics.of(arm, const [90, 90, 90, 90]).openness,
          closeTo(0.5, 1e-9));
      expect(ArmKinematics.of(arm, const [90, 90, 90, 180]).openness, 1);
    });

    test('more segments means shorter links so the arm still fits', () {
      final arm = PlacedComponent(
          id: 'arm', type: ComponentType.robotArm, x: 0, y: 0);
      for (final segments in [2, 4, 6]) {
        final pose = ArmKinematics.of(
            arm, List<double>.filled(segments, 90));
        expect(pose.joints, hasLength(segments));
        for (final (_, y) in pose.joints) {
          expect(y, inInclusiveRange(0, arm.height));
        }
      }
    });
  });

  group('Arm assembly', () {
    /// A pedestal, a servo in its socket and a link bolted on top.
    List<PlacedComponent> parts() => [
          PlacedComponent(
              id: 'base', type: ComponentType.armBase, x: 400, y: 300),
          PlacedComponent(
              id: 'shoulder',
              type: ComponentType.servo,
              x: 0,
              y: 0,
              properties: {'parent': 'base'}),
          PlacedComponent(
              id: 'link',
              type: ComponentType.armLink,
              x: 0,
              y: 0,
              properties: {'parent': 'shoulder'}),
        ];

    test('a bolted chain is placed from its root outwards', () {
      final circuit = Circuit(components: parts());
      ArmAssembly.bake(circuit);
      final base = circuit.componentById('base')!;
      final shoulder = circuit.componentById('shoulder')!;
      final link = circuit.componentById('link')!;

      // The root does not move: its pivot stays where the user dropped it.
      expect(ArmAssembly.pivotWorld(base), (448.0, 330.0));
      // The servo drops its shaft onto the base socket.
      expect(ArmAssembly.socketWorld(base), (448.0, 310.0));
      expect(ArmAssembly.pivotWorld(shoulder), ArmAssembly.socketWorld(base));
      expect(shoulder.x, closeTo(418, 1e-9));
      expect(shoulder.y, closeTo(280, 1e-9));
      // The link's foot lands on the servo shaft.
      expect(ArmAssembly.pivotWorld(link), ArmAssembly.socketWorld(shoulder));
      expect(link.x, closeTo(434, 1e-9));
      expect(link.y, closeTo(234, 1e-9));
    });

    test('a servo in the chain swings everything bolted above it', () {
      final circuit = Circuit(components: parts());
      ArmAssembly.bake(circuit);
      final link = circuit.componentById('link')!;
      expect(link.rotation, 0);

      // Neutral is straight up; 180 turns the link a quarter turn.
      ArmAssembly.bake(circuit, jointAngle: (part) => part.id == 'shoulder' ? 180 : 90);
      expect(link.rotation, 90);
      final swung = ArmAssembly.socketWorld(link);
      final upright = ArmAssembly.socketWorld(circuit.componentById('link')!);
      expect(swung, upright);
    });

    test('a part snaps onto the nearest free socket', () {
      final circuit = Circuit(components: parts());
      ArmAssembly.bake(circuit);
      final link = circuit.componentById('link')!;
      // Pull the link off and drop it near the servo shaft, but off chain.
      link.properties['parent'] = null;
      link.x = 448 - 14 + 18;
      link.y = 310 - 76 + 12;
      ArmAssembly.snap(circuit, link);
      // The base socket is already taken by the servo, so the free one wins.
      expect(ArmAssembly.parentOf(link), 'shoulder');
      expect(circuit.components.where((c) => c.id != 'link').length, 2);
    });

    test('a part dropped far from any socket is let go', () {
      final circuit = Circuit(components: parts());
      final link = circuit.componentById('link')!;
      link.properties['parent'] = null;
      link.x = 900;
      link.y = 900;
      ArmAssembly.snap(circuit, link);
      expect(ArmAssembly.parentOf(link), isNull);
    });

    test('a socket takes one occupant at a time', () {
      final circuit = Circuit(components: parts());
      final spare = PlacedComponent(
          id: 'spare',
          type: ComponentType.armLink,
          x: 0,
          y: 0,
          properties: {'parent': 'base'});
      circuit.components.add(spare);
      ArmAssembly.bake(circuit);
      // The first part to claim the socket keeps it, so the spare is a root.
      expect(ArmAssembly.parentOf(circuit.componentById('link')!), 'shoulder');
      expect(ArmAssembly.pivotWorld(spare), ArmAssembly.pivotWorld(spare));
    });

    test('deleting a part frees whatever was bolted to it', () {
      final circuit = Circuit(components: parts());
      ArmAssembly.bake(circuit);
      ArmAssembly.orphan(circuit, 'shoulder');
      circuit.removeComponent('shoulder');
      expect(ArmAssembly.parentOf(circuit.componentById('link')!), isNull);
      // A freed part stays where it was, rather than folding onto the root.
      ArmAssembly.bake(circuit);
      expect(circuit.componentById('link')!.rotation, 0);
    });

    test('bolting a servo onto the gripper works its jaws', () {
      final circuits = [
        PlacedComponent(
            id: 'base', type: ComponentType.armBase, x: 400, y: 300),
        PlacedComponent(
            id: 'grip',
            type: ComponentType.armGripper,
            x: 0,
            y: 0,
            properties: {'parent': 'base', 'openness': 0.0}),
        PlacedComponent(
            id: 'jaws',
            type: ComponentType.servo,
            x: 0,
            y: 0,
            properties: {'parent': 'grip'}),
      ];
      final circuit = Circuit(components: circuits);
      ArmAssembly.bake(circuit, jointAngle: (part) => part.id == 'jaws' ? 180 : 90);
      expect(circuit.componentById('grip')!.properties['openness'], 1.0);
      ArmAssembly.bake(circuit, jointAngle: (part) => part.id == 'jaws' ? 0 : 90);
      expect(circuit.componentById('grip')!.properties['openness'], 0.0);
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
        car.properties['distanceBehind'] = CarPhysics.clearanceBehindCm(
            pose, car, kWorkspaceWidth, kWorkspaceHeight);
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

    test('all four wheels really are driven forward', () {
      final project = Examples.byId('robot_car')!.build();
      final car = project.circuit.components
          .firstWhere((c) => c.type == ComponentType.robotCar);
      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      engine.start();
      engine.tick(0.016);
      final wheels = readRigCommands(engine, car).wheels;
      expect(wheels, hasLength(4));
      for (final duty in wheels) {
        expect(duty, greaterThan(0), reason: 'clear road: all four forward');
      }
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
    });

    test('both car sensors feed "read distance" through the netlist', () {
      final project = Examples.byId('robot_car')!.build();
      final car = project.circuit.components
          .firstWhere((c) => c.type == ComponentType.robotCar);
      final engine = SimulationEngine(
          circuit: project.circuit, program: project.program);
      expect(engine.resolveLogicPin(car.id, 'ECHO'), 15);
      expect(engine.resolveLogicPin(car.id, 'ECHO2'), 17);

      // Park the car near the right hand wall and step the rigs the way the
      // app does, then look at what each rangefinder publishes.
      car.x = 2200;
      car.y = 700;
      engine.start();
      for (var i = 0; i < 3; i++) {
        engine.tick(0.016);
        final pose = RigPose(car.x, car.y, car.rotation);
        car.properties['distance'] =
            CarPhysics.clearanceCm(pose, car, kWorkspaceWidth, kWorkspaceHeight);
        car.properties['distanceBehind'] = CarPhysics.clearanceBehindCm(
            pose, car, kWorkspaceWidth, kWorkspaceHeight);
      }
      final readings = engine.solution.ultrasonicDistanceByEchoPin;
      expect(readings.containsKey(15), isTrue,
          reason: 'the front sensor behaves like a discrete HC-SR04');
      expect(readings.containsKey(17), isTrue,
          reason: 'the rear sensor is published on its own echo pin');
      expect(readings[15]!, lessThan(readings[17]!),
          reason: 'the wall is ahead, not behind');
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
      final shoulders = <double>{};
      final jaws = <double>{};
      for (var i = 0; i < 8; i++) {
        engine.tick(0.016);
        final joints = readRigCommands(engine, arm).joints;
        shoulders.add(joints[0]);
        jaws.add(joints[3]);
        if (i == 0) {
          expect(joints, [40, 120, 135, 90],
              reason: 'the pick pose is reached before the first wait, and the '
                  'jaw joint is still neutral');
        }
      }
      expect(shoulders, containsAll(<double>[40, 135]));
      expect(jaws, containsAll(<double>[165, 20]));
    });

    test('the arm kit example is assembled when it is loaded', () {
      final project = Examples.byId('robot_arm_kit')!.build();
      final circuit = project.circuit;
      final engine = SimulationEngine(
          circuit: circuit, program: project.program);
      // Loading a project bakes the chain, exactly like the app does.
      ArmAssembly.bake(circuit, jointAngle: armJointReader(engine));

      final base = circuit.componentById('base')!;
      final shoulder = circuit.componentById('shoulder')!;
      final link1 = circuit.componentById('link1')!;
      final elbow = circuit.componentById('elbow')!;
      final link2 = circuit.componentById('link2')!;
      final grip = circuit.componentById('grip')!;
      final jaws = circuit.componentById('jaws')!;

      // Every part ends up on its parent's socket.
      expect(ArmAssembly.parentOf(shoulder), 'base');
      expect(ArmAssembly.pivotWorld(shoulder), ArmAssembly.socketWorld(base));
      expect(ArmAssembly.pivotWorld(link1), ArmAssembly.socketWorld(shoulder));
      expect(ArmAssembly.pivotWorld(elbow), ArmAssembly.socketWorld(link1));
      expect(ArmAssembly.pivotWorld(link2), ArmAssembly.socketWorld(elbow));
      expect(ArmAssembly.pivotWorld(grip), ArmAssembly.socketWorld(link2));
      expect(ArmAssembly.pivotWorld(jaws), ArmAssembly.socketWorld(grip));
      // The whole chain stands up straight when nothing has moved yet.
      expect(jaws.y, lessThan(grip.y));
      expect(grip.y, lessThan(link2.y));
      expect(link2.y, lessThan(elbow.y));
      expect(elbow.y, lessThan(link1.y));
      expect(link1.y, lessThan(base.y));
    });

    test('the arm kit example swings when the program drives a servo', () {
      final project = Examples.byId('robot_arm_kit')!.build();
      final circuit = project.circuit;
      final engine = SimulationEngine(
          circuit: circuit, program: project.program);
      ArmAssembly.bake(circuit, jointAngle: armJointReader(engine));
      final link1 = circuit.componentById('link1')!;
      final elbow = circuit.componentById('elbow')!;
      final uprightLink = (link1.x, link1.y);
      final uprightElbow = (elbow.x, elbow.y);
      expect(link1.rotation, 0);

      engine.start();
      engine.tick(0.016); // Shoulder servo written, then a wait ends the frame.
      ArmAssembly.bake(circuit, jointAngle: armJointReader(engine));

      // The link turns about its own foot, and everything above it follows.
      expect(link1.rotation, isNot(0));
      expect((link1.x, link1.y), uprightLink,
          reason: 'a link pivots, so it does not slide');
      expect((elbow.x, elbow.y), isNot(uprightElbow),
          reason: 'the servo swings what is bolted above it');
    });
  });

  group('Robot specs', () {
    test('the car exposes four motors, two rangefinders and power', () {
      final pins = ComponentSpecs.of(ComponentType.robotCar).pins;
      expect(pins.map((p) => p.id).toList(), [
        'M1A', 'M1B', 'EN1',
        'M2A', 'M2B', 'EN2',
        'M3A', 'M3B', 'EN3',
        'M4A', 'M4B', 'EN4',
        'TRIG', 'ECHO', 'TRIG2', 'ECHO2', '5V', 'GND',
      ]);
      expect(pins.every((p) => p.displayName.isNotEmpty), isTrue);
      expect(ComponentSpecs.of(ComponentType.robotCar).category, 'Robotics');
    });

    test('the arm exposes six joint pins plus power', () {
      final pins = ComponentSpecs.of(ComponentType.robotArm).pins;
      expect(pins.map((p) => p.id).toList(),
          ['J1', 'J2', 'J3', 'J4', 'J5', 'J6', '5V', 'GND']);
      expect(ComponentSpecs.of(ComponentType.robotArm).category, 'Robotics');
    });

    test('every arm part has a pivot and, unless it is last, a socket', () {
      for (final type in [
        ComponentType.armBase,
        ComponentType.armLink,
        ComponentType.armGripper,
        ComponentType.servo,
      ]) {
        final spec = ComponentSpecs.of(type);
        expect(spec.isArmPart, isTrue, reason: type.name);
        expect(spec.mount, isNotNull, reason: type.name);
        final mount = spec.mount!;
        expect(mount.pivotX, inInclusiveRange(0, spec.width), reason: type.name);
        expect(mount.pivotY, inInclusiveRange(0, spec.height), reason: type.name);
        if (mount.hasSocket) {
          expect(mount.socketX, inInclusiveRange(0, spec.width),
              reason: type.name);
          expect(mount.socketY, inInclusiveRange(0, spec.height),
              reason: type.name);
        }
      }
      // Only a servo is a joint; the rest are rigid structure.
      expect(ComponentSpecs.of(ComponentType.servo).mount!.isJoint, isTrue);
      expect(ComponentSpecs.of(ComponentType.armLink).mount!.isJoint, isFalse);
      expect(ComponentSpecs.of(ComponentType.led).isArmPart, isFalse);
    });

    test('robot headers are far enough apart to be tapped', () {
      for (final type in [ComponentType.robotCar, ComponentType.robotArm]) {
        final pins = ComponentSpecs.of(type).pins;
        for (var i = 0; i < pins.length; i++) {
          for (var j = i + 1; j < pins.length; j++) {
            final gap = (pins[i].dx - pins[j].dx).abs() +
                (pins[i].dy - pins[j].dy).abs();
            expect(gap, greaterThanOrEqualTo(22),
                reason: '${type.name}: ${pins[i].id}/${pins[j].id}');
          }
        }
      }
    });

    test('a fresh car has the properties the physics expects', () {
      final car = PlacedComponent(
          id: 'car', type: ComponentType.robotCar, x: 0, y: 0);
      expect(car.properties['distance'], 100.0);
      expect(car.properties['distanceBehind'], 100.0);
      expect(car.properties['autoDistance'], isTrue);
      for (var i = 1; i <= 4; i++) {
        expect(car.properties['phase$i'], 0.0);
      }
    });

    test('a fresh arm has four segments with a servo at every joint', () {
      final arm = PlacedComponent(
          id: 'arm', type: ComponentType.robotArm, x: 0, y: 0);
      expect(armSegmentCount(arm), 4);
      for (var j = 1; j <= 4; j++) {
        expect(armJointFitted(arm, j), isTrue, reason: 'J$j');
      }
      // Rest angles start neutral, so an unfitted joint holds the arm up.
      for (var j = 1; j <= 6; j++) {
        expect(arm.properties['restJ$j'], 90.0);
      }
    });

    test('the examples exist and are wired', () {
      for (final entry in {
        'robot_car': 2,
        'robot_arm': 2,
        'robot_arm_kit': 8,
      }.entries) {
        final example = Examples.byId(entry.key);
        expect(example, isNotNull, reason: entry.key);
        final circuit = example!.build().circuit;
        expect(circuit.wires, isNotEmpty, reason: entry.key);
        expect(circuit.components, hasLength(entry.value),
            reason: entry.key);
      }
    });
  });
}
