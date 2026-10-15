import 'dart:math' as math;

import '../models/circuit.dart';
import '../models/component_type.dart';
import 'simulation_engine.dart';

/// Commands a rig reads off its own header pins.
class RigCommands {
  const RigCommands({
    this.left = 0,
    this.right = 0,
    this.joints = const <double>[0, 0, 0, 0],
  });

  /// Drive duty for the left and right motor, each in -1..1.
  final double left;
  final double right;

  /// Servo angles in degrees, in header order:
  /// base, shoulder, elbow, gripper.
  final List<double> joints;

  bool get isIdle => left == 0 && right == 0;
}

/// Where a rig's header pins are wired, and what the program drives them to.
///
/// Everything is resolved through the netlist, so a rig works the same whether
/// it is wired straight to the board or through a breadboard.
class RigWiring {
  RigWiring(this.engine, this.component);

  final SimulationEngine engine;
  final PlacedComponent component;

  /// Logical Arduino pin this header reaches, or null when it is not wired.
  int? logicOf(String pinId) => engine.resolveLogicPin(component.id, pinId);

  /// Logic level driven onto [pinId]. Null when the header floats.
  bool? level(String pinId) {
    final logic = logicOf(pinId);
    if (logic == null) return null;
    final rt = engine.runtime;
    if (!rt.isPinOutput(logic)) return null;
    final pwm = rt.pwmValue[logic];
    if (pwm != null) return pwm > 127;
    return (rt.digitalValue[logic] ?? 0) > 0.5;
  }

  /// PWM duty driven onto [pinId], 0..1. Null when the header floats, which for
  /// a motor driver input means "no signal" and for an enable pin means the
  /// bridge runs at full speed (the usual jumper default).
  double? duty(String pinId) {
    final logic = logicOf(pinId);
    if (logic == null) return null;
    final rt = engine.runtime;
    if (!rt.isPinOutput(logic)) return null;
    final pwm = rt.pwmValue[logic];
    if (pwm != null) return (pwm / 255.0).clamp(0.0, 1.0);
    return (rt.digitalValue[logic] ?? 0) > 0.5 ? 1.0 : 0.0;
  }

  /// Servo angle the program wrote to [pinId], in degrees.
  double angle(String pinId) {
    final logic = logicOf(pinId);
    if (logic == null) return 0;
    return engine.runtime.servoAngle[logic] ?? 0;
  }

  /// Mixes a full H-bridge: two direction inputs plus one enable input.
  ///
  /// Both directions equal (or both floating) means the bridge is braking, so
  /// the motor produces nothing.
  double motor(String forwardPin, String reversePin, String enablePin) {
    final forward = level(forwardPin) ?? false;
    final reverse = level(reversePin) ?? false;
    if (forward == reverse) return 0;
    final speed = duty(enablePin) ?? 1.0;
    return forward ? speed : -speed;
  }
}

/// Reads the state of a rig from the simulated program.
RigCommands readRigCommands(SimulationEngine engine, PlacedComponent component) {
  final wiring = RigWiring(engine, component);
  switch (component.type) {
    case ComponentType.robotCar:
      return RigCommands(
        left: wiring.motor('IN1', 'IN2', 'EN1'),
        right: wiring.motor('IN3', 'IN4', 'EN2'),
      );
    case ComponentType.robotArm:
      return RigCommands(joints: [
        wiring.angle('BASE'),
        wiring.angle('SHLD'),
        wiring.angle('ELBW'),
        wiring.angle('GRIP'),
      ]);
    default:
      return const RigCommands();
  }
}

/// Pose of a rig on the workspace: top-left corner plus heading in degrees.
class RigPose {
  const RigPose(this.x, this.y, this.headingDeg);

  final double x;
  final double y;
  final double headingDeg;

  @override
  String toString() =>
      'RigPose(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${headingDeg.toStringAsFixed(1)}°)';

  @override
  bool operator ==(Object other) =>
      other is RigPose &&
      other.x == x &&
      other.y == y &&
      other.headingDeg == headingDeg;

  @override
  int get hashCode => Object.hash(x, y, headingDeg);
}

/// Differential-drive kinematics for the robot car.
///
/// Pure functions only: the tests drive this directly, with no rendering.
class CarPhysics {
  /// Wheel travel at full duty, in workspace pixels per second.
  static const double fullSpeedPx = 260;

  /// Track width between the wheels, in pixels. Narrower means it turns faster.
  static const double wheelBasePx = 84;

  /// Wheel radius in pixels, used to spin the wheel graphics.
  static const double wheelRadiusPx = 9;

  /// Workspace pixels per centimetre, so distances read like a real HC-SR04.
  static const double pxPerCm = 7.0;

  /// Integrates one step of differential drive.
  static RigPose step(RigPose pose, double left, double right, double dt) {
    final vl = left * fullSpeedPx;
    final vr = right * fullSpeedPx;
    final speed = (vl + vr) / 2;
    final turn = (vr - vl) / wheelBasePx;
    final heading = pose.headingDeg * math.pi / 180.0;
    final x = pose.x + math.cos(heading) * speed * dt;
    final y = pose.y + math.sin(heading) * speed * dt;
    final deg = pose.headingDeg + turn * dt * 180 / math.pi;
    return RigPose(x, y, deg % 360);
  }

  /// Spins the wheel graphics forward by however far the wheels rolled.
  static double advanceWheelPhase(double phaseDeg, double left, double right,
      double dt) {
    final travelled = (left + right) / 2 * fullSpeedPx * dt;
    final circumference = 2 * math.pi * wheelRadiusPx;
    return (phaseDeg + travelled / circumference * 360) % 360;
  }

  /// Half the car's extent along [headingDeg]; a rotated body is longer than
  /// its wheelbase, so the sensor must not start inside a wall.
  static double halfExtentAlong(double width, double height, double headingDeg) {
    final h = headingDeg * math.pi / 180.0;
    return (math.cos(h).abs() * width + math.sin(h).abs() * height) / 2;
  }

  /// Distance in pixels from ([x],[y]) to the workspace border along a heading.
  static double rayToBorder(
      double x, double y, double headingDeg, double fieldWidth, double fieldHeight) {
    final h = headingDeg * math.pi / 180.0;
    final dx = math.cos(h);
    final dy = math.sin(h);
    var best = double.infinity;
    if (dx > 1e-9) best = math.min(best, (fieldWidth - x) / dx);
    if (dx < -1e-9) best = math.min(best, (0 - x) / dx);
    if (dy > 1e-9) best = math.min(best, (fieldHeight - y) / dy);
    if (dy < -1e-9) best = math.min(best, (0 - y) / dy);
    if (!best.isFinite || best < 0) return 0;
    return best;
  }

  /// What the onboard HC-SR04 would report: the clearance ahead, in cm.
  static double clearanceCm(
      RigPose pose, PlacedComponent car, double fieldWidth, double fieldHeight) {
    final centreX = pose.x + car.width / 2;
    final centreY = pose.y + car.height / 2;
    final ahead =
        rayToBorder(centreX, centreY, pose.headingDeg, fieldWidth, fieldHeight);
    final gap =
        ahead - halfExtentAlong(car.width, car.height, pose.headingDeg);
    // Same working range the solver clamps hand-set sensors to.
    return (gap / pxPerCm).clamp(2.0, 400.0);
  }

  /// Keeps the body fully inside the workspace.
  static RigPose clampToField(
      RigPose pose, double width, double height, double fieldWidth, double fieldHeight) {
    return RigPose(
      pose.x.clamp(0.0, math.max(0.0, fieldWidth - width)),
      pose.y.clamp(0.0, math.max(0.0, fieldHeight - height)),
      pose.headingDeg,
    );
  }
}
