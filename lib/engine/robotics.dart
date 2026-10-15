import 'dart:math' as math;

import '../models/circuit.dart';
import '../models/component_type.dart';
import '../models/geometry.dart';
import 'simulation_engine.dart';

/// Commands a rig reads off its own header pins.
class RigCommands {
  const RigCommands({
    this.wheels = const <double>[0, 0, 0, 0],
    this.joints = const <double>[90, 90, 90, 90, 90, 90],
  });

  /// Drive duty for the car's four wheels, each in -1..1, in the order
  /// front-left, front-right, rear-left, rear-right.
  final List<double> wheels;

  /// Servo angles in degrees, one per active arm joint, from the shoulder up.
  final List<double> joints;

  /// Duty of the left and right side, averaged over the pair of wheels.
  double get left => wheels.length < 4 ? 0 : (wheels[0] + wheels[2]) / 2;
  double get right => wheels.length < 4 ? 0 : (wheels[1] + wheels[3]) / 2;

  bool get isIdle => wheels.every((w) => w == 0);
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

  /// Servo angle the program wrote to [pinId], in degrees. Defaults to the
  /// neutral 90° so an unwired or not-yet-driven joint stands straight instead
  /// of slamming to an end stop.
  double angle(String pinId, {double fallback = 90}) {
    final logic = logicOf(pinId);
    if (logic == null) return fallback;
    return engine.runtime.servoAngle[logic] ?? fallback;
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

/// Which pins drive each of the car's four wheels, in wheel order.
const List<(String, String, String)> kCarMotors = [
  ('M1A', 'M1B', 'EN1'),
  ('M2A', 'M2B', 'EN2'),
  ('M3A', 'M3B', 'EN3'),
  ('M4A', 'M4B', 'EN4'),
];

/// Joint pins of the configurable arm, in order up the arm.
const List<String> kArmJointPins = ['J1', 'J2', 'J3', 'J4', 'J5', 'J6'];

/// How many segments the configurable arm has, clamped to what it can draw.
int armSegmentCount(PlacedComponent arm) =>
    ((arm.properties['segments'] as num?)?.toInt() ?? 4).clamp(2, 6);

/// True when the user has fitted a servo to joint [joint] (1 based).
bool armJointFitted(PlacedComponent arm, int joint) =>
    (arm.properties['servoJ$joint'] as bool?) ?? joint <= 4;

/// Angles of the arm's joints, in degrees (0..180), from the shoulder up.
///
/// A joint with a servo follows `servo write` on its own pin; a joint without
/// one simply holds the angle dialled in by hand, so an arm can be posed and
/// then have a single joint animated.
List<double> readArmJoints(SimulationEngine engine, PlacedComponent arm) {
  final wiring = RigWiring(engine, arm);
  final segments = armSegmentCount(arm);
  return [
    for (var j = 1; j <= segments; j++)
      if (!armJointFitted(arm, j))
        (arm.properties['restJ$j'] as num?)?.toDouble() ?? 90
      else if (wiring.logicOf(kArmJointPins[j - 1]) == null)
        90
      else
        wiring.angle(kArmJointPins[j - 1]),
  ];
}

/// Reads the state of a rig from the simulated program.
RigCommands readRigCommands(SimulationEngine engine, PlacedComponent component) {
  final wiring = RigWiring(engine, component);
  switch (component.type) {
    case ComponentType.robotCar:
      return RigCommands(
        wheels: [
          for (final (forward, reverse, enable) in kCarMotors)
            wiring.motor(forward, reverse, enable),
        ],
      );
    case ComponentType.robotArm:
      return RigCommands(joints: readArmJoints(engine, component));
    default:
      return const RigCommands();
  }
}

/// Rotation a servo contributes at a joint: 0..180° of servo travel mapped to
/// ±90° of swing around the neutral 90°.
double servoRotation(double angleDeg) => (angleDeg - 90).clamp(-90.0, 90.0);

/// Swing a servo part of a built-up arm drives its child with.
double servoJointDegrees(SimulationEngine engine, PlacedComponent servo) {
  final logic = engine.resolveLogicPin(servo.id, 'SIG');
  if (logic == null) return 0;
  return servoRotation(engine.runtime.servoAngle[logic] ?? 90);
}

/// Joint angle of a built-up arm: everything above a servo swings by it.
///
/// The reader returns the servo's own 0..180° angle; the assembly turns that
/// into swing with [servoRotation]. An unwired servo reads neutral, so a half
/// built arm stands still instead of folding over.
double Function(PlacedComponent) armJointReader(SimulationEngine engine) =>
    (part) => (part.spec.mount?.isJoint ?? false)
        ? RigWiring(engine, part).angle('SIG')
        : 0;

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

  /// Spins one wheel's graphics by however far that wheel rolled.
  static double advancePhase(double phaseDeg, double duty, double dt) {
    final travelled = duty * fullSpeedPx * dt;
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
  static double rayToBorder(double x, double y, double headingDeg,
      double fieldWidth, double fieldHeight) {
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

  /// What a sensor bolted to the [directionDeg] face of the car reads, in cm.
  static double clearanceCmFrom(RigPose pose, PlacedComponent car,
      double directionDeg, double fieldWidth, double fieldHeight) {
    final centreX = pose.x + car.width / 2;
    final centreY = pose.y + car.height / 2;
    final ahead = rayToBorder(
        centreX, centreY, directionDeg, fieldWidth, fieldHeight);
    final gap =
        ahead - halfExtentAlong(car.width, car.height, directionDeg);
    // Same working range the solver clamps hand-set sensors to.
    return (gap / pxPerCm).clamp(2.0, 400.0);
  }

  /// What the front sensor reads: the clearance along the car's nose.
  static double clearanceCm(
          RigPose pose, PlacedComponent car, double fieldWidth, double fieldHeight) =>
      clearanceCmFrom(pose, car, pose.headingDeg, fieldWidth, fieldHeight);

  /// What the rear sensor reads.
  static double clearanceBehindCm(
          RigPose pose, PlacedComponent car, double fieldWidth, double fieldHeight) =>
      clearanceCmFrom(
          pose, car, pose.headingDeg + 180, fieldWidth, fieldHeight);

  /// Keeps the body fully inside the workspace.
  static RigPose clampToField(RigPose pose, double width, double height,
      double fieldWidth, double fieldHeight) {
    return RigPose(
      pose.x.clamp(0.0, math.max(0.0, fieldWidth - width)),
      pose.y.clamp(0.0, math.max(0.0, fieldHeight - height)),
      pose.headingDeg,
    );
  }
}

/// Where a joint of the configurable arm ends up, in the component's own space.
class ArmPose {
  const ArmPose({
    required this.joints,
    required this.directions,
    required this.openness,
    required this.fitted,
  });

  /// Joint centres from the shoulder outwards, in local coordinates.
  final List<(double, double)> joints;

  /// Direction each link leaves its joint at, in degrees counter-clockwise from
  /// the +x axis, shoulder first.
  final List<double> directions;

  /// How far the jaws are open, 0 closed .. 1 wide.
  final double openness;

  /// Whether a servo is fitted at each joint, shoulder first. The last entry is
  /// the jaw joint at the very tip.
  final List<bool> fitted;

  /// The tip of the arm, where the gripper sits.
  (double, double) get tip => joints.isEmpty ? (0, 0) : joints.last;

  /// Heading the gripper points along.
  double get tipDirection => directions.isEmpty ? -90 : directions.last;
}

/// Forward kinematics of the configurable arm.
///
/// A planar arm: every joint swings in the plane of the drawing, so all of the
/// motion is visible at once instead of hiding half of it behind a dial.
class ArmKinematics {
  /// Straight up the screen, the arm's rest direction. Angles run the same way
  /// the canvas rotates: measured from +x, growing clockwise on screen.
  static const double _restDir = -90;

  static (double, double) along((double, double) from, double deg, double len) {
    final a = deg * math.pi / 180.0;
    return (from.$1 + math.cos(a) * len, from.$2 + math.sin(a) * len);
  }

  static ArmPose of(PlacedComponent arm, List<double> jointAngles) {
    final segments = jointAngles.isEmpty ? 2 : jointAngles.length;
    final shoulder = (arm.width / 2, arm.height - 30);
    // Longer arms get shorter links so the whole thing still fits the body.
    final link =
        ((arm.height - 50) / (segments - 1)).clamp(22.0, 40.0).toDouble();

    var dir = _restDir;
    var at = shoulder;
    final joints = <(double, double)>[at];
    final directions = <double>[];
    for (var j = 0; j < segments - 1; j++) {
      dir += servoRotation(jointAngles[j]);
      directions.add(dir);
      at = along(at, dir, link);
      joints.add(at);
    }

    return ArmPose(
      joints: joints,
      directions: directions,
      openness: (jointAngles.last / 180.0).clamp(0.0, 1.0),
      fitted: [
        for (var j = 1; j <= segments; j++) armJointFitted(arm, j),
      ],
    );
  }
}

/// The arm you build yourself out of parts.
///
/// Every part has a pivot (its rotation point) and, unless it is the last one,
/// a socket the next part bolts onto. Poses are baked back into the components'
/// `x`/`y`/`rotation`, so wires, selection and hit testing keep working with no
/// knowledge of the assembly at all.
class ArmAssembly {
  /// True when the component can be bolted onto another arm part.
  static bool isPart(PlacedComponent c) => c.spec.isArmPart;

  static String? parentOf(PlacedComponent c) => c.properties['parent'] as String?;

  /// World position a part rotates about.
  static (double, double) pivotWorld(PlacedComponent part) {
    final mount = part.spec.mount!;
    return (part.x + mount.pivotX, part.y + mount.pivotY);
  }

  /// World position of the socket a child bolts onto.
  static (double, double) socketWorld(PlacedComponent part) {
    final mount = part.spec.mount!;
    if (!mount.hasSocket) return pivotWorld(part);
    return rotatePoint(
      part.x + mount.socketX!,
      part.y + mount.socketY!,
      part.x + mount.pivotX,
      part.y + mount.pivotY,
      degToRad(part.rotation),
    );
  }

  /// Recomputes every arm part's pose from the chain it hangs off.
  ///
  /// [jointAngle] returns a servo's own 0..180° angle for a part; it is turned
  /// into swing with [servoRotation].
  static void bake(Circuit circuit,
      {double Function(PlacedComponent)? jointAngle}) {
    final parts = circuit.components.where(isPart).toList();
    if (parts.isEmpty) return;

    final known = {for (final p in parts) p.id};
    final childOf = <String, PlacedComponent>{};
    for (final p in parts) {
      final parent = parentOf(p);
      if (parent != null && parent != p.id && known.contains(parent)) {
        // One occupant per socket: the first part that claimed it keeps it.
        childOf.putIfAbsent(parent, () => p);
      }
    }

    final angleOf = jointAngle ?? (_) => 90.0;
    for (final root in parts) {
      final parent = parentOf(root);
      if (parent == null || parent == root.id || !known.contains(parent)) {
        _place(root, root.x + root.spec.mount!.pivotX,
            root.y + root.spec.mount!.pivotY, root.rotation, childOf, angleOf);
      }
    }
  }

  static void _place(
      PlacedComponent part,
      double pivotX,
      double pivotY,
      double rotation,
      Map<String, PlacedComponent> childOf,
      double Function(PlacedComponent) angleOf) {
    final mount = part.spec.mount!;
    part.x = pivotX - mount.pivotX;
    part.y = pivotY - mount.pivotY;
    part.rotation = rotation % 360;

    if (!mount.hasSocket) return;
    final child = childOf[part.id];
    if (child == null) return;

    // A servo bolted onto a gripper's socket is what works its jaws.
    if (part.type == ComponentType.armGripper &&
        (child.spec.mount?.isJoint ?? false)) {
      part.properties['openness'] = (angleOf(child) / 180.0).clamp(0.0, 1.0);
    }

    final (sx, sy) = socketWorld(part);
    _place(
      child,
      sx,
      sy,
      part.rotation +
          (mount.isJoint ? servoRotation(angleOf(part)) : 0),
      childOf,
      angleOf,
    );
  }

  /// Every part bolted above [id], including [id] itself.
  static Set<String> subtree(Circuit circuit, String id) {
    final children = <String, List<PlacedComponent>>{};
    for (final c in circuit.components) {
      final parent = parentOf(c);
      if (parent != null) children.putIfAbsent(parent, () => []).add(c);
    }
    final found = <String>{};
    void walk(String at) {
      if (!found.add(at)) return;
      for (final c in children[at] ?? const <PlacedComponent>[]) {
        walk(c.id);
      }
    }

    walk(id);
    return found;
  }

  /// The nearest free socket [moved] could bolt onto, if any is close enough.
  static String? socketWithin(
      Circuit circuit, PlacedComponent moved, double radius) {
    final mount = moved.spec.mount;
    if (mount == null) return null;
    final (px, py) = pivotWorld(moved);
    final blocked = subtree(circuit, moved.id);

    String? best;
    var bestDistance = radius;
    for (final host in circuit.components) {
      final hostMount = host.spec.mount;
      if (hostMount == null || !hostMount.hasSocket) continue;
      if (blocked.contains(host.id)) continue;
      // A socket that already carries something is taken.
      final occupied = circuit.components
          .any((c) => parentOf(c) == host.id && c.id != moved.id);
      if (occupied) continue;

      final (sx, sy) = socketWorld(host);
      final distance = math.sqrt(math.pow(sx - px, 2) + math.pow(sy - py, 2));
      if (distance < bestDistance) {
        bestDistance = distance;
        best = host.id;
      }
    }
    return best;
  }

  /// Bolts [moved] onto the nearest free socket, or lets it go when there is
  /// nothing close enough, then refreshes every pose.
  static void snap(Circuit circuit, PlacedComponent moved,
      {double radius = 46, double Function(PlacedComponent)? jointAngle}) {
    moved.properties['parent'] = socketWithin(circuit, moved, radius);
    bake(circuit, jointAngle: jointAngle);
  }

  /// Frees everything bolted directly onto [id], so deleting one part does not
  /// take the rest of the arm with it.
  static void orphan(Circuit circuit, String id) {
    for (final c in circuit.components) {
      if (parentOf(c) == id) c.properties['parent'] = null;
    }
  }
}
