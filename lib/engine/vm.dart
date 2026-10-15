import 'dart:math' as math;

import '../blocks/block_model.dart';
import 'runtime.dart';
import 'solver.dart';

/// Bytecode opcodes of the virtual machine that executes block programs.
enum Op {
  pushConst,
  loadVar,
  storeVar,
  binOp,
  call,
  pinMode,
  digitalWrite,
  analogWrite,
  delay,
  serialBegin,
  serialPrint,
  servoWrite,
  toneOut,
  noToneOut,
  lcdInit,
  lcdClear,
  lcdSetCursor,
  lcdPrint,
  jump,
  jumpIfFalse,
  pop,
  halt,
  serialPrintText,
  lcdPrintText,
}

/// A single VM instruction (a compact tagged union).
class Instr {
  const Instr(this.op,
      {this.i1 = 0, this.d1 = 0, this.s1 = '', this.b1 = false});

  final Op op;
  final int i1;
  final double d1;
  final String s1;
  final bool b1;
}

/// Emits instructions and resolves jump targets.
class _Emitter {
  final List<Instr> out = [];

  int emit(Instr i) {
    out.add(i);
    return out.length - 1;
  }

  int jumpTo(int target) => emit(Instr(Op.jump, i1: target));

  int jumpPlaceholder() => emit(const Instr(Op.jump, i1: -1));

  int jumpIfFalsePlaceholder() => emit(const Instr(Op.jumpIfFalse, i1: -1));

  void patch(int index, int target) {
    final ins = out[index];
    out[index] = Instr(ins.op,
        i1: target, d1: ins.d1, s1: ins.s1, b1: ins.b1);
  }
}

/// Compiles a [BlockProgram] into VM instructions.
///
/// The block tree is the intermediate representation: both the C++ preview
/// (see `SketchPrinter`) and this bytecode are derived from it.
class SketchCompiler {
  static List<Instr> compile(BlockProgram program) {
    final e = _Emitter();
    for (final b in program.setup) {
      _block(b, e);
    }
    final entry = e.jumpPlaceholder();
    final loopStart = e.out.length;
    for (final b in program.loop) {
      _block(b, e);
    }
    if (program.loop.isEmpty) {
      e.out[entry] = const Instr(Op.halt);
    } else {
      e.jumpTo(loopStart);
      e.patch(entry, loopStart);
    }
    return e.out;
  }

  static void _blocks(List<Block> list, _Emitter e) {
    for (final b in list) {
      _block(b, e);
    }
  }

  static void _block(Block b, _Emitter e) {
    switch (b.kind) {
      case BlockKind.wait:
        _value(b.valueParam('ms'), e);
        e.emit(const Instr(Op.delay));
        break;

      case BlockKind.repeatTimes:
        final iVar = '__i_${b.id}';
        final nVar = '__n_${b.id}';
        _value(b.valueParam('times'), e);
        e.emit(Instr(Op.storeVar, s1: nVar));
        e.emit(const Instr(Op.pushConst, d1: 0));
        e.emit(Instr(Op.storeVar, s1: iVar));
        final top = e.out.length;
        e.emit(Instr(Op.loadVar, s1: iVar));
        e.emit(Instr(Op.loadVar, s1: nVar));
        e.emit(const Instr(Op.binOp, s1: '<'));
        final exit = e.jumpIfFalsePlaceholder();
        _blocks(b.body, e);
        e.emit(Instr(Op.loadVar, s1: iVar));
        e.emit(const Instr(Op.pushConst, d1: 1));
        e.emit(const Instr(Op.binOp, s1: '+'));
        e.emit(Instr(Op.storeVar, s1: iVar));
        e.jumpTo(top);
        e.patch(exit, e.out.length);
        break;

      case BlockKind.forever:
        final top = e.out.length;
        _blocks(b.body, e);
        e.jumpTo(top);
        break;

      case BlockKind.ifDo:
        _value(b.valueParam('condition'), e);
        final skip = e.jumpIfFalsePlaceholder();
        _blocks(b.body, e);
        e.patch(skip, e.out.length);
        break;

      case BlockKind.ifElse:
        _value(b.valueParam('condition'), e);
        final onFalse = e.jumpIfFalsePlaceholder();
        _blocks(b.body, e);
        final over = e.jumpPlaceholder();
        e.patch(onFalse, e.out.length);
        _blocks(b.elseBody, e);
        e.patch(over, e.out.length);
        break;

      case BlockKind.setPinMode:
        e.emit(Instr(Op.pinMode,
            i1: b.intParam('pin', 13), s1: b.stringParam('mode', 'OUTPUT')));
        break;

      case BlockKind.digitalWrite:
        final raw = b.params['value'];
        if (raw is String) {
          e.emit(Instr(Op.pushConst,
              d1: raw.toUpperCase() == 'HIGH' ? 1 : 0));
        } else {
          _value(b.valueParam('value'), e);
        }
        e.emit(Instr(Op.digitalWrite, i1: b.intParam('pin', 13)));
        break;

      case BlockKind.analogWrite:
        _value(b.valueParam('value'), e);
        e.emit(Instr(Op.analogWrite, i1: b.intParam('pin', 9)));
        break;

      case BlockKind.setVar:
        _value(b.valueParam('value'), e);
        e.emit(Instr(Op.storeVar, s1: b.stringParam('name', 'x')));
        break;

      case BlockKind.changeVar:
        final name = b.stringParam('name', 'x');
        final op = b.stringParam('op', '+=');
        e.emit(Instr(Op.loadVar, s1: name));
        _value(b.valueParam('value'), e);
        e.emit(Instr(Op.binOp,
            s1: op == '-=' ? '-' : op == '*=' ? '*' : op == '/=' ? '/' : '+'));
        e.emit(Instr(Op.storeVar, s1: name));
        break;

      case BlockKind.serialBegin:
        e.emit(Instr(Op.serialBegin, d1: b.valueParam('baud').number));
        break;

      case BlockKind.serialPrint:
        _printBlock(b, Op.serialPrintText, const Instr(Op.serialPrint, b1: false), e);
        break;

      case BlockKind.serialPrintln:
        _printBlock(b, Op.serialPrintText, const Instr(Op.serialPrint, b1: true), e);
        break;

      case BlockKind.servoWrite:
        _value(b.valueParam('angle'), e);
        e.emit(Instr(Op.servoWrite, i1: b.intParam('pin', 9)));
        break;

      case BlockKind.tone:
        _value(b.valueParam('frequency'), e);
        e.emit(Instr(Op.toneOut, i1: b.intParam('pin', 8)));
        break;

      case BlockKind.noTone:
        e.emit(Instr(Op.noToneOut, i1: b.intParam('pin', 8)));
        break;

      case BlockKind.lcdInit:
        e.emit(const Instr(Op.lcdInit));
        break;

      case BlockKind.lcdClear:
        e.emit(const Instr(Op.lcdClear));
        break;

      case BlockKind.lcdSetCursor:
        _value(b.valueParam('col'), e);
        _value(b.valueParam('row'), e);
        e.emit(const Instr(Op.lcdSetCursor));
        break;

      case BlockKind.lcdPrint:
        _printBlock(b, Op.lcdPrintText, const Instr(Op.lcdPrint), e);
        break;

      case BlockKind.readUltrasonic:
        e.emit(Instr(Op.pushConst, d1: b.intParam('trig', 7).toDouble()));
        e.emit(Instr(Op.pushConst, d1: b.intParam('echo', 6).toDouble()));
        e.emit(const Instr(Op.call, i1: 2, s1: 'ultrasonicDistance'));
        e.emit(Instr(Op.storeVar, s1: b.stringParam('name', 'distance')));
        break;

      case BlockKind.readTemperature:
        e.emit(Instr(Op.pushConst, d1: b.intParam('pin', 2).toDouble()));
        e.emit(const Instr(Op.call, i1: 1, s1: 'readTemperature'));
        e.emit(Instr(Op.storeVar, s1: b.stringParam('name', 'temp')));
        break;

      case BlockKind.readHumidity:
        e.emit(Instr(Op.pushConst, d1: b.intParam('pin', 2).toDouble()));
        e.emit(const Instr(Op.call, i1: 1, s1: 'readHumidity'));
        e.emit(Instr(Op.storeVar, s1: b.stringParam('name', 'hum')));
        break;
    }
  }

  static void _printBlock(
      Block b, Op textOp, Instr valueInstr, _Emitter e) {
    final raw = b.params['value'];
    if (raw is Value && raw.kind == ValueKind.text) {
      e.emit(Instr(textOp, s1: raw.name, b1: valueInstr.b1));
    } else if (raw is String) {
      e.emit(Instr(textOp, s1: raw, b1: valueInstr.b1));
    } else {
      _value(b.valueParam('value'), e);
      e.emit(valueInstr);
    }
  }

  static void _value(Value v, _Emitter e) {
    switch (v.kind) {
      case ValueKind.number:
        e.emit(Instr(Op.pushConst, d1: v.number));
        break;
      case ValueKind.text:
        e.emit(const Instr(Op.pushConst, d1: 0));
        break;
      case ValueKind.variable:
        e.emit(Instr(Op.loadVar, s1: v.name));
        break;
      case ValueKind.binary:
        _value(v.args[0], e);
        _value(v.args[1], e);
        e.emit(Instr(Op.binOp, s1: v.name));
        break;
      case ValueKind.call:
        for (final a in v.args) {
          _value(a, e);
        }
        e.emit(Instr(Op.call, i1: v.args.length, s1: v.name));
        break;
    }
  }
}

/// The virtual machine that runs compiled block programs.
class Vm {
  Vm(this.code);

  final List<Instr> code;
  final List<double> _stack = [];
  final Map<String, double> vars = {};
  final math.Random _rng = math.Random();

  int pc = 0;
  bool halted = false;

  void reset() {
    pc = 0;
    halted = false;
    _stack.clear();
    vars.clear();
  }

  bool get finished => halted || pc >= code.length;

  double _pop() => _stack.isEmpty ? 0 : _stack.removeLast();

  /// Executes exactly one instruction.
  void step(ArduinoRuntime rt, CircuitSolution sol) {
    if (finished) return;
    final ins = code[pc];
    switch (ins.op) {
      case Op.pushConst:
        _stack.add(ins.d1);
        pc++;
        break;
      case Op.loadVar:
        _stack.add(vars[ins.s1] ?? 0);
        pc++;
        break;
      case Op.storeVar:
        vars[ins.s1] = _pop();
        pc++;
        break;
      case Op.binOp:
        final b = _pop();
        final a = _pop();
        _stack.add(_bin(ins.s1, a, b));
        pc++;
        break;
      case Op.call:
        _call(ins, rt, sol);
        pc++;
        break;
      case Op.pinMode:
        if (ins.s1 == 'OUTPUT') {
          rt.isOutput[ins.i1] = true;
          rt.pullup[ins.i1] = false;
        } else if (ins.s1 == 'INPUT_PULLUP') {
          rt.isOutput[ins.i1] = false;
          rt.pullup[ins.i1] = true;
        } else {
          rt.isOutput[ins.i1] = false;
          rt.pullup[ins.i1] = false;
        }
        pc++;
        break;
      case Op.digitalWrite:
        final v = _pop();
        rt.isOutput[ins.i1] = true;
        rt.digitalValue[ins.i1] = v > 0.5 ? 1 : 0;
        rt.pwmValue.remove(ins.i1);
        pc++;
        break;
      case Op.analogWrite:
        final v = _pop();
        rt.isOutput[ins.i1] = true;
        rt.pwmValue[ins.i1] = v.clamp(0, 255);
        pc++;
        break;
      case Op.delay:
        final ms = _pop();
        rt.timeUs += (ms < 0 ? 0 : ms * 1000).round();
        pc++;
        break;
      case Op.serialBegin:
        pc++;
        break;
      case Op.serialPrint:
        final v = _pop();
        rt.serialWrite(_format(v), newline: ins.b1);
        pc++;
        break;
      case Op.servoWrite:
        final angle = _pop();
        rt.servoAngle[ins.i1] = angle.clamp(0, 180);
        pc++;
        break;
      case Op.toneOut:
        final freq = _pop();
        rt.toneFreq[ins.i1] = freq <= 0 ? 0 : freq;
        pc++;
        break;
      case Op.noToneOut:
        rt.toneFreq[ins.i1] = 0;
        pc++;
        break;
      case Op.lcdInit:
        rt.lcdInited = true;
        pc++;
        break;
      case Op.lcdClear:
        rt.lcdClear();
        pc++;
        break;
      case Op.lcdSetCursor:
        final row = _pop();
        final col = _pop();
        rt.lcdSetCursor(col.toInt(), row.toInt());
        pc++;
        break;
      case Op.lcdPrint:
        final v = _pop();
        rt.lcdPrint(_format(v));
        pc++;
        break;
      case Op.jump:
        pc = ins.i1;
        break;
      case Op.jumpIfFalse:
        final v = _pop();
        pc = v == 0 ? ins.i1 : pc + 1;
        break;
      case Op.pop:
        _pop();
        pc++;
        break;
      case Op.halt:
        halted = true;
        break;
      case Op.serialPrintText:
        rt.serialWrite(ins.s1, newline: ins.b1);
        pc++;
        break;
      case Op.lcdPrintText:
        rt.lcdPrint(ins.s1);
        pc++;
        break;
    }
  }

  void _call(Instr ins, ArduinoRuntime rt, CircuitSolution sol) {
    final args = <double>[];
    for (var i = 0; i < ins.i1; i++) {
      args.insert(0, _pop());
    }
    double result;
    switch (ins.s1) {
      case 'analogRead':
        result = sol.analogRead(args[0].toInt());
        break;
      case 'digitalRead':
        result = sol.digitalRead(args[0].toInt()) ? 1 : 0;
        break;
      case 'millis':
        result = rt.timeUs / 1000.0;
        break;
      case 'micros':
        result = rt.timeUs.toDouble();
        break;
      case 'map':
        final x = args[0], inMin = args[1], inMax = args[2];
        final outMin = args[3], outMax = args[4];
        final span = inMax - inMin;
        result = span == 0 ? outMin : (x - inMin) * (outMax - outMin) / span + outMin;
        break;
      case 'constrain':
        result = args[0] < args[1]
            ? args[1]
            : (args[0] > args[2] ? args[2] : args[0]);
        break;
      case 'abs':
        result = args[0].abs();
        break;
      case 'sqrt':
        result = math.sqrt(math.max(args[0], 0));
        break;
      case 'pow':
        result = math.pow(args[0], args[1]).toDouble();
        break;
      case 'min':
        result = math.min(args[0], args[1]);
        break;
      case 'max':
        result = math.max(args[0], args[1]);
        break;
      case 'random':
        if (args.length >= 2) {
          final lo = args[0].toInt();
          final hi = args[1].toInt();
          result = hi <= lo ? lo.toDouble() : (lo + _rng.nextInt(hi - lo)).toDouble();
        } else {
          result = (_rng.nextInt(math.max(args[0].toInt(), 1))).toDouble();
        }
        break;
      case 'pulseIn':
        result = sol.pulseInMicros(args[0].toInt());
        break;
      case 'ultrasonicDistance':
        result = sol.pulseInMicros(args[1].toInt()) / 58.0;
        break;
      case 'readTemperature':
        result = sol.temperature(args[0].toInt());
        break;
      case 'readHumidity':
        result = sol.humidity(args[0].toInt());
        break;
      default:
        result = 0;
    }
    _stack.add(result);
  }

  static double _bin(String op, double a, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        return b == 0 ? 0 : a / b;
      case '%':
        return b == 0 ? 0 : a % b;
      case '==':
        return a == b ? 1 : 0;
      case '!=':
        return a != b ? 1 : 0;
      case '<':
        return a < b ? 1 : 0;
      case '>':
        return a > b ? 1 : 0;
      case '<=':
        return a <= b ? 1 : 0;
      case '>=':
        return a >= b ? 1 : 0;
      case '&&':
        return (a != 0 && b != 0) ? 1 : 0;
      case '||':
        return (a != 0 || b != 0) ? 1 : 0;
      default:
        return 0;
    }
  }

  static String _format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2);
  }
}
