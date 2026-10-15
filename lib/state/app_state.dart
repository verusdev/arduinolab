import 'dart:async';

import 'package:flutter/foundation.dart';

import '../blocks/block_catalog.dart';
import '../blocks/block_model.dart';
import '../core/ids.dart';
import '../engine/robotics.dart';
import '../engine/simulation_engine.dart';
import '../examples/examples.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import '../services/storage_service.dart';

enum BlockSection { setup, loop }

/// Which pin the user tapped first while drawing a wire.
class PendingWire {
  PendingWire(this.componentId, this.pinId);
  final String componentId;
  final String pinId;
}

/// Central application controller: owns the project, the simulation engine and
/// the interactive editing state.
class AppState extends ChangeNotifier {
  AppState() {
    engine =
        SimulationEngine(circuit: project.circuit, program: project.program);
  }

  final StorageService storage = StorageService();

  Project project = Project(name: 'New project');
  late SimulationEngine engine;

  Timer? _timer;

  /// Where each vehicle was parked when the run started, so Reset can put it
  /// back instead of leaving it wherever it happened to stop.
  final Map<String, RigPose> _spawns = {};

  /// Firmware clock reading at the previous frame, used to step the vehicles by
  /// the same amount of time the program believes has passed.
  int _lastTimeUs = 0;

  String? selectedComponentId;
  String? selectedWireId;
  String? selectedBlockId;
  PendingWire? pendingWire;
  BlockSection activeSection = BlockSection.loop;

  String? message;

  bool get running => engine.running;
  bool get canRun => !project.program.isEmpty;

  List<Block> get setupBlocks => project.program.setup;
  List<Block> get loopBlocks => project.program.loop;

  PlacedComponent? get selectedComponent => selectedComponentId == null
      ? null
      : project.circuit.componentById(selectedComponentId!);

  void _kick() => notifyListeners();

  void setMessage(String? text) {
    message = text;
    _kick();
  }

  // ---------------------------------------------------------------- circuit

  void addComponent(ComponentType type, double x, double y) {
    final c = PlacedComponent(id: newId(type.name), type: type, x: x, y: y);
    project.circuit.components.add(c);
    engine.invalidate();
    selectedComponentId = c.id;
    selectedWireId = null;
    _bakeArms();
    _kick();
  }

  void moveComponent(String id, double x, double y) {
    final c = project.circuit.componentById(id);
    if (c == null) return;
    c.x = x;
    c.y = y;
    // Anything bolted to this part rides along with it.
    _bakeArms();
    _kick();
  }

  /// Takes an arm part off the chain it was bolted to, so the drag that follows
  /// moves that part (and everything hanging off it) rather than the whole arm.
  void detachArmPart(String id) {
    final c = project.circuit.componentById(id);
    if (c == null || !ArmAssembly.isPart(c)) return;
    c.properties['parent'] = null;
    _bakeArms();
    _kick();
  }

  /// Bolts a dropped arm part onto the nearest free socket, or lets it go.
  void dropArmPart(String id) {
    final c = project.circuit.componentById(id);
    if (c == null || !ArmAssembly.isPart(c)) return;
    ArmAssembly.snap(project.circuit, c, jointAngle: armJointReader(engine));
    _kick();
  }

  void rotateComponent(String id) {
    final c = project.circuit.componentById(id);
    if (c == null) return;
    c.rotation = (c.rotation + 90) % 360;
    _bakeArms();
    _kick();
  }

  void deleteComponent(String id) {
    // Free whatever was bolted on, so deleting one part does not drag the rest
    // of the arm away with it.
    ArmAssembly.orphan(project.circuit, id);
    project.circuit.removeComponent(id);
    engine.invalidate();
    if (selectedComponentId == id) selectedComponentId = null;
    _bakeArms();
    _kick();
  }

  void deleteSelected() {
    if (selectedWireId != null) {
      project.circuit.removeWire(selectedWireId!);
      engine.invalidate();
      selectedWireId = null;
    } else if (selectedComponentId != null) {
      deleteComponent(selectedComponentId!);
    }
    _kick();
  }

  void selectComponent(String? id) {
    selectedComponentId = id;
    selectedWireId = null;
    _kick();
  }

  void selectWire(String? id) {
    selectedWireId = id;
    selectedComponentId = null;
    _kick();
  }

  void tapPin(String componentId, String pinId) {
    final pending = pendingWire;
    if (pending == null) {
      pendingWire = PendingWire(componentId, pinId);
      _kick();
      return;
    }
    if (pending.componentId == componentId && pending.pinId == pinId) {
      pendingWire = null;
      _kick();
      return;
    }
    if (!project.circuit
        .wireExists(componentId, pinId, pending.componentId, pending.pinId)) {
      project.circuit.wires.add(Wire(
        id: newId('wire'),
        aComponent: componentId,
        aPin: pinId,
        bComponent: pending.componentId,
        bPin: pending.pinId,
      ));
      engine.invalidate();
    }
    pendingWire = null;
    _kick();
  }

  void cancelWire() {
    pendingWire = null;
    _kick();
  }

  void setProperty(String componentId, String key, Object? value) {
    final c = project.circuit.componentById(componentId);
    if (c == null) return;
    c.properties[key] = value;
    engine.invalidate();
    // Joint angles and segment counts change the shape of a built-up arm.
    if (c.spec.isArmPart) _bakeArms();
    _kick();
  }

  void setButtonPressed(String componentId, bool pressed) {
    if (pressed) {
      engine.pressedButtons.add(componentId);
    } else {
      engine.pressedButtons.remove(componentId);
    }
    _kick();
  }

  bool isButtonPressed(String componentId) =>
      engine.pressedButtons.contains(componentId);

  // ----------------------------------------------------------------- blocks

  List<Block> _sectionList(BlockSection section) =>
      section == BlockSection.setup
          ? project.program.setup
          : project.program.loop;

  void addBlock(BlockKind kind, {String? parentId, bool intoElse = false}) {
    final block = BlockCatalog.def(kind).build();
    if (parentId == null) {
      _sectionList(activeSection).add(block);
    } else {
      final parent = _findBlock(project.program.setup, parentId) ??
          _findBlock(project.program.loop, parentId);
      if (parent == null) return;
      (intoElse ? parent.elseBody : parent.body).add(block);
    }
    selectedBlockId = block.id;
    _kick();
  }

  void deleteBlock(String id) {
    if (!_removeBlock(project.program.setup, id)) {
      _removeBlock(project.program.loop, id);
    }
    if (selectedBlockId == id) selectedBlockId = null;
    _kick();
  }

  void updateBlockParam(String blockId, String key, Object? value) {
    final block = _findBlock(project.program.setup, blockId) ??
        _findBlock(project.program.loop, blockId);
    if (block == null) return;
    block.params[key] = value;
    _kick();
  }

  void moveBlock(String id, int delta) {
    for (final list in [project.program.setup, project.program.loop]) {
      if (_moveInList(list, id, delta)) break;
    }
    _kick();
  }

  bool _moveInList(List<Block> list, String id, int delta) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) {
        final target = i + delta;
        if (target < 0 || target >= list.length) return true;
        final b = list.removeAt(i);
        list.insert(target, b);
        return true;
      }
      if (_moveInList(list[i].body, id, delta)) return true;
      if (_moveInList(list[i].elseBody, id, delta)) return true;
    }
    return false;
  }

  Block? _findBlock(List<Block> list, String id) {
    for (final b in list) {
      if (b.id == id) return b;
      final inBody = _findBlock(b.body, id);
      if (inBody != null) return inBody;
      final inElse = _findBlock(b.elseBody, id);
      if (inElse != null) return inElse;
    }
    return null;
  }

  bool _removeBlock(List<Block> list, String id) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) {
        list.removeAt(i);
        return true;
      }
      if (_removeBlock(list[i].body, id)) return true;
      if (_removeBlock(list[i].elseBody, id)) return true;
    }
    return false;
  }

  void setSection(BlockSection section) {
    activeSection = section;
    _kick();
  }

  // ------------------------------------------------------------- simulation

  void run() {
    if (project.program.isEmpty) {
      setMessage('Add blocks to your program first.');
      return;
    }
    if (!project.circuit.hasArduino) {
      setMessage('Place an Arduino UNO on the board to run.');
      return;
    }
    engine.setCircuit(project.circuit);
    engine.setProgram(project.program);
    engine.start();
    _spawns.clear();
    for (final c in project.circuit.components) {
      if (c.type == ComponentType.robotCar) {
        _spawns[c.id] = RigPose(c.x, c.y, c.rotation);
      }
    }
    _lastTimeUs = engine.runtime.timeUs;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      engine.tick(0.016);
      final nowUs = engine.runtime.timeUs;
      // Vehicles are driven by the firmware's own clock, not the frame clock:
      // a `wait 300` really is 300 ms of motor time. The delay blocks jump the
      // clock forward, so the step is capped to keep the motion watchable.
      final elapsed = ((nowUs - _lastTimeUs) / 1e6).clamp(0.0, 0.5);
      _lastTimeUs = nowUs;
      _stepRigs(elapsed);
      notifyListeners();
    });
    setMessage(null);
    _kick();
  }

  /// Advances every rig by one frame.
  ///
  /// Runs after [SimulationEngine.tick] so the program has already written this
  /// frame's pin levels, and writes each sensor reading back into the component
  /// properties, which is where the solver looks for it.
  void _stepRigs(double dt) {
    for (final c in project.circuit.components) {
      if (c.type == ComponentType.robotCar) _driveCar(c, dt);
    }
    // Arms are posed straight from the servo angles each frame, so a servo
    // bolted into a joint swings everything above it.
    _bakeArms();
  }

  void _driveCar(PlacedComponent c, double dt) {
    final commands = readRigCommands(engine, c);
    final moved = CarPhysics.clampToField(
      CarPhysics.step(RigPose(c.x, c.y, c.rotation), commands.left,
          commands.right, dt),
      c.width,
      c.height,
      kWorkspaceWidth,
      kWorkspaceHeight,
    );
    c.x = moved.x;
    c.y = moved.y;
    c.rotation = moved.headingDeg;

    for (var i = 0; i < 4; i++) {
      final duty = commands.wheels[i];
      if (duty == 0) continue;
      final key = 'phase${i + 1}';
      c.properties[key] = CarPhysics.advancePhase(
        (c.properties[key] as num?)?.toDouble() ?? 0,
        duty,
        dt,
      );
    }
    if ((c.properties['autoDistance'] as bool?) ?? true) {
      c.properties['distance'] =
          CarPhysics.clearanceCm(moved, c, kWorkspaceWidth, kWorkspaceHeight);
      c.properties['distanceBehind'] = CarPhysics.clearanceBehindCm(
          moved, c, kWorkspaceWidth, kWorkspaceHeight);
    }
  }

  /// Refreshes the pose of every part of every built-up arm.
  void _bakeArms() => ArmAssembly.bake(project.circuit,
      jointAngle: armJointReader(engine));

  void stop() {
    engine.stop();
    _timer?.cancel();
    _timer = null;
    _kick();
  }

  void resetSimulation() {
    stop();
    engine.reset();
    _lastTimeUs = engine.runtime.timeUs;
    for (final entry in _spawns.entries) {
      final c = project.circuit.componentById(entry.key);
      if (c == null) continue;
      c.x = entry.value.x;
      c.y = entry.value.y;
      c.rotation = entry.value.headingDeg;
    }
    for (final c in project.circuit.components) {
      if (c.type != ComponentType.robotCar) continue;
      for (var i = 1; i <= 4; i++) {
        c.properties['phase$i'] = 0.0;
      }
    }
    // Servo angles are back to neutral, so the arms stand up straight again.
    _bakeArms();
    _kick();
  }

  // ---------------------------------------------------------------- project

  void replaceProject(Project next) {
    stop();
    _spawns.clear();
    project = next;
    engine =
        SimulationEngine(circuit: project.circuit, program: project.program);
    selectedComponentId = null;
    selectedWireId = null;
    selectedBlockId = null;
    pendingWire = null;
    // Bolted-on arms arrive as a chain of parent ids; rebuild their poses now
    // that the circuit is live again.
    _bakeArms();
    _kick();
  }

  void newProject() {
    replaceProject(Project(name: 'New project'));
    setMessage('New project created.');
  }

  void renameProject(String name) {
    project.name = name;
    _kick();
  }

  void loadExample(String id) {
    final example = Examples.byId(id);
    if (example == null) return;
    replaceProject(example.build());
    setMessage('Loaded example "${example.title}".');
  }

  Future<void> saveToSlot(String slot) async {
    await storage.save(slot, project);
    setMessage('Saved to slot "$slot".');
  }

  Future<void> openFromSlot(String slot) async {
    final loaded = await storage.load(slot);
    if (loaded == null) {
      setMessage('Slot "$slot" is empty.');
      return;
    }
    replaceProject(loaded);
    setMessage('Opened slot "$slot".');
  }

  String exportJson() => storage.encode(project);

  void importJson(String raw) {
    try {
      replaceProject(storage.decode(raw));
      setMessage('Project imported.');
    } catch (e) {
      setMessage('Import failed: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
