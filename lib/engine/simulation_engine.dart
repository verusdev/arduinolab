import '../blocks/block_model.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
import 'netlist.dart';
import 'runtime.dart';
import 'solver.dart';
import 'vm.dart';

/// Orchestrates netlist building, circuit solving and VM execution.
class SimulationEngine {
  SimulationEngine({Circuit? circuit, BlockProgram? program})
      : circuit = circuit ?? Circuit(),
        program = program ?? BlockProgram();

  static const int _instrCostUs = 2;
  static const int _maxStepsPerFrame = 400000;
  static const int _maxSerialLines = 500;

  Circuit circuit;
  BlockProgram program;

  final ArduinoRuntime runtime = ArduinoRuntime();

  /// Component ids whose push button is currently held down.
  final Set<String> pressedButtons = {};

  CircuitSolution solution = CircuitSolution.empty();

  Netlist? _netlist;
  List<Instr> _code = const [];
  Vm? _vm;

  bool running = false;
  bool overloaded = false;
  String? compileMessage;

  List<Instr> get code => _code;
  Map<String, double> get variables => _vm?.vars ?? const {};

  List<String> get serial => runtime.serial;

  String get serialText => runtime.serial.join('\n');

  void setCircuit(Circuit c) {
    circuit = c;
    invalidate();
  }

  void setProgram(BlockProgram p) {
    program = p;
  }

  /// Call after any structural change to the circuit.
  void invalidate() => _netlist = null;

  Netlist _netlistFor() => _netlist ??= Netlist.build(circuit);

  void start() {
    _code = SketchCompiler.compile(program);
    _vm = Vm(_code)..reset();
    runtime.reset();
    runtime.started = true;
    overloaded = false;
    running = true;
    compileMessage = program.isEmpty
        ? 'Program is empty — add blocks, then press Run.'
        : null;
    solution = Solver.solve(circuit, _netlistFor(), runtime, pressedButtons);
  }

  void stop() => running = false;

  void reset() {
    stop();
    runtime.reset();
    _vm?.reset();
    solution = CircuitSolution.empty();
    overloaded = false;
  }

  /// Advances the simulation by [dtSeconds] of real time.
  void tick(double dtSeconds) {
    if (!running) return;
    final vm = _vm;
    if (vm == null) return;

    solution = Solver.solve(circuit, _netlistFor(), runtime, pressedButtons);

    final dtUs = (dtSeconds * 1e6).round().clamp(0, 500000);
    final target = runtime.timeUs + dtUs;

    var steps = 0;
    while (!vm.finished &&
        runtime.timeUs < target &&
        steps < _maxStepsPerFrame) {
      vm.step(runtime, solution);
      steps++;
      runtime.timeUs += _instrCostUs;
    }
    if (steps >= _maxStepsPerFrame) {
      overloaded = true;
      runtime.timeUs = target;
    }
    if (runtime.serial.length > _maxSerialLines) {
      runtime.serial.removeRange(0, runtime.serial.length - _maxSerialLines);
    }
  }

  bool get isEmptyProgram => program.isEmpty;

  /// Finds the logical Arduino pin number that the given component pin is
  /// connected to (through wires and breadboard rows), or null.
  int? resolveLogicPin(String componentId, String pinId) {
    final netlist = _netlistFor();
    final net = netlist.netOf(componentId, pinId);
    if (net < 0) return null;
    for (final key in netlist.pinsOfNet(net)) {
      final split = key.indexOf('::');
      if (split < 0) continue;
      final comp = circuit.componentById(key.substring(0, split));
      if (comp == null || comp.type != ComponentType.arduinoUno) continue;
      final logic = comp.pinById(key.substring(split + 2))?.logic;
      if (logic != null) return logic;
    }
    return null;
  }
}
