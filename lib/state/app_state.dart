import 'dart:async';

import 'package:flutter/foundation.dart';

import '../blocks/block_catalog.dart';
import '../blocks/block_model.dart';
import '../core/ids.dart';
import '../engine/simulation_engine.dart';
import '../examples/examples.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
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
    _kick();
  }

  void moveComponent(String id, double x, double y) {
    final c = project.circuit.componentById(id);
    if (c == null) return;
    c.x = x;
    c.y = y;
    _kick();
  }

  void rotateComponent(String id) {
    final c = project.circuit.componentById(id);
    if (c == null) return;
    c.rotation = (c.rotation + 90) % 360;
    _kick();
  }

  void deleteComponent(String id) {
    project.circuit.removeComponent(id);
    engine.invalidate();
    if (selectedComponentId == id) selectedComponentId = null;
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      engine.tick(0.016);
      notifyListeners();
    });
    setMessage(null);
    _kick();
  }

  void stop() {
    engine.stop();
    _timer?.cancel();
    _timer = null;
    _kick();
  }

  void resetSimulation() {
    stop();
    engine.reset();
    _kick();
  }

  // ---------------------------------------------------------------- project

  void replaceProject(Project next) {
    stop();
    project = next;
    engine =
        SimulationEngine(circuit: project.circuit, program: project.program);
    selectedComponentId = null;
    selectedWireId = null;
    selectedBlockId = null;
    pendingWire = null;
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
