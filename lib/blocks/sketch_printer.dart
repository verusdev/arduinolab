import 'block_model.dart';

/// Renders a block program as an Arduino C++ sketch.
///
/// The sketch is a faithful projection of the block tree: [SketchParser] reads
/// exactly these shapes back, so the sketch editor can round-trip between code
/// and blocks. Anything the printer emits, the parser understands; keeping the
/// two in step is what makes "edit the code, watch the blocks follow" work.
///
/// Two conventions carry information that C++ itself would spell differently:
/// a servo and a DHT sensor are declared per pin (`Servo servo9;`, `DHT
/// dht2(2, DHT11);`), so the pin travels in the object's name.
class SketchPrinter {
  static String print(BlockProgram p) {
    final scan = _Scan();
    scan.walk(p.setup);
    scan.walk(p.loop);

    final sb = StringBuffer();
    sb.writeln('// Arduino Lab sketch — edit it here, or build it from blocks.');

    if (scan.servoPins.isNotEmpty) sb.writeln('#include <Servo.h>');
    if (scan.usesLcd) sb.writeln('#include <LiquidCrystal_I2C.h>');
    if (scan.dhtPins.isNotEmpty) sb.writeln('#include <DHT.h>');

    for (final pin in _sortedInts(scan.servoPins)) {
      sb.writeln('Servo servo$pin;');
    }
    if (scan.usesLcd) sb.writeln('LiquidCrystal_I2C lcd(0x27, 16, 2);');
    for (final pin in _sortedInts(scan.dhtPins)) {
      sb.writeln('DHT dht$pin($pin, DHT11);');
    }
    for (final name in _sortedStrings(scan.vars)) {
      sb.writeln('float $name;');
    }

    final preamble = scan.servoPins.isNotEmpty ||
        scan.usesLcd ||
        scan.dhtPins.isNotEmpty ||
        scan.vars.isNotEmpty;
    if (preamble) sb.writeln();

    sb.writeln('void setup() {');
    for (final pin in _sortedInts(scan.servoPins)) {
      sb.writeln('  servo$pin.attach($pin);');
    }
    for (final b in p.setup) {
      _block(b, sb, 1);
    }
    sb.writeln('}');
    sb.writeln();
    sb.writeln('void loop() {');
    for (final b in p.loop) {
      _block(b, sb, 1);
    }
    sb.writeln('}');
    return sb.toString();
  }

  static List<int> _sortedInts(Set<int> s) => s.toList()..sort();

  static List<String> _sortedStrings(Set<String> s) => s.toList()..sort();

  static void _block(Block b, StringBuffer sb, int indent) {
    final pad = '  ' * indent;
    switch (b.kind) {
      case BlockKind.wait:
        sb.writeln('${pad}delay(${_expr(b.valueParam('ms'))});');
        break;
      case BlockKind.repeatTimes:
        sb.writeln(
            '${pad}for (int i = 0; i < ${_expr(b.valueParam('times'))}; i++) {');
        for (final c in b.body) {
          _block(c, sb, indent + 1);
        }
        sb.writeln('$pad}');
        break;
      case BlockKind.forever:
        // A real, compilable spelling of "forever": an endless while loop.
        sb.writeln('${pad}while (true) {');
        for (final c in b.body) {
          _block(c, sb, indent + 1);
        }
        sb.writeln('$pad}');
        break;
      case BlockKind.ifDo:
        sb.writeln('${pad}if (${_expr(b.valueParam('condition'))}) {');
        for (final c in b.body) {
          _block(c, sb, indent + 1);
        }
        sb.writeln('$pad}');
        break;
      case BlockKind.ifElse:
        sb.writeln('${pad}if (${_expr(b.valueParam('condition'))}) {');
        for (final c in b.body) {
          _block(c, sb, indent + 1);
        }
        sb.writeln('$pad} else {');
        for (final c in b.elseBody) {
          _block(c, sb, indent + 1);
        }
        sb.writeln('$pad}');
        break;
      case BlockKind.setPinMode:
        sb.writeln(
            '${pad}pinMode(${b.intParam('pin', 13)}, ${b.stringParam('mode', 'OUTPUT')});');
        break;
      case BlockKind.digitalWrite:
        final raw = b.params['value'];
        final v = raw is String
            ? raw.toUpperCase()
            : _expr(b.valueParam('value'));
        sb.writeln('${pad}digitalWrite(${b.intParam('pin', 13)}, $v);');
        break;
      case BlockKind.analogWrite:
        sb.writeln(
            '${pad}analogWrite(${b.intParam('pin', 9)}, ${_expr(b.valueParam('value'))});');
        break;
      case BlockKind.setVar:
        sb.writeln(
            '$pad${b.stringParam('name', 'x')} = ${_expr(b.valueParam('value'))};');
        break;
      case BlockKind.changeVar:
        sb.writeln(
            '$pad${b.stringParam('name', 'x')} ${b.stringParam('op', '+=')} ${_expr(b.valueParam('value'))};');
        break;
      case BlockKind.serialBegin:
        sb.writeln('${pad}Serial.begin(${_expr(b.valueParam('baud'))});');
        break;
      case BlockKind.serialPrint:
        sb.writeln('${pad}Serial.print(${_expr(b.valueParam('value'))});');
        break;
      case BlockKind.serialPrintln:
        sb.writeln('${pad}Serial.println(${_expr(b.valueParam('value'))});');
        break;
      case BlockKind.servoWrite:
        sb.writeln(
            '${pad}servo${b.intParam('pin', 9)}.write(${_expr(b.valueParam('angle'))});');
        break;
      case BlockKind.tone:
        sb.writeln(
            '${pad}tone(${b.intParam('pin', 8)}, ${_expr(b.valueParam('frequency'))});');
        break;
      case BlockKind.noTone:
        sb.writeln('${pad}noTone(${b.intParam('pin', 8)});');
        break;
      case BlockKind.lcdInit:
        sb.writeln('${pad}lcd.init();');
        break;
      case BlockKind.lcdClear:
        sb.writeln('${pad}lcd.clear();');
        break;
      case BlockKind.lcdSetCursor:
        sb.writeln(
            '${pad}lcd.setCursor(${_expr(b.valueParam('col'))}, ${_expr(b.valueParam('row'))});');
        break;
      case BlockKind.lcdPrint:
        sb.writeln('${pad}lcd.print(${_expr(b.valueParam('value'))});');
        break;
      case BlockKind.readUltrasonic:
        final trig = b.intParam('trig', 7);
        final echo = b.intParam('echo', 6);
        sb.writeln('${pad}digitalWrite($trig, LOW);');
        sb.writeln('${pad}delayMicroseconds(2);');
        sb.writeln('${pad}digitalWrite($trig, HIGH);');
        sb.writeln('${pad}delayMicroseconds(10);');
        sb.writeln('${pad}digitalWrite($trig, LOW);');
        sb.writeln(
            '$pad${b.stringParam('name', 'distance')} = pulseIn($echo, HIGH) / 58;');
        break;
      case BlockKind.readTemperature:
        sb.writeln(
            '$pad${b.stringParam('name', 'temp')} = dht${b.intParam('pin', 2)}.readTemperature();');
        break;
      case BlockKind.readHumidity:
        sb.writeln(
            '$pad${b.stringParam('name', 'hum')} = dht${b.intParam('pin', 2)}.readHumidity();');
        break;
    }
  }

  static String _expr(Value v) {
    switch (v.kind) {
      case ValueKind.number:
        return v.number == v.number.roundToDouble()
            ? v.number.toInt().toString()
            : v.number.toString();
      case ValueKind.variable:
        return v.name;
      case ValueKind.binary:
        return '(${_expr(v.args[0])} ${v.name} ${_expr(v.args[1])})';
      case ValueKind.call:
        return '${v.name}(${v.args.map(_expr).join(', ')})';
      case ValueKind.text:
        // Escaped so the parser can read the text back unchanged, whatever a
        // block field happens to contain.
        return '"${_escape(v.name)}"';
    }
  }

  static String _escape(String s) => s
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
}

/// Collects what the sketch has to declare up front.
class _Scan {
  final Set<int> servoPins = {};
  final Set<int> dhtPins = {};
  final Set<String> vars = {};
  bool usesLcd = false;

  void walk(List<Block> blocks) {
    for (final b in blocks) {
      _block(b);
    }
  }

  void _block(Block b) {
    switch (b.kind) {
      case BlockKind.servoWrite:
        servoPins.add(b.intParam('pin', 9));
        break;
      case BlockKind.lcdInit:
      case BlockKind.lcdClear:
      case BlockKind.lcdSetCursor:
      case BlockKind.lcdPrint:
        usesLcd = true;
        break;
      case BlockKind.setVar:
      case BlockKind.changeVar:
        vars.add(b.stringParam('name', 'x'));
        break;
      case BlockKind.readUltrasonic:
        vars.add(b.stringParam('name', 'distance'));
        break;
      case BlockKind.readTemperature:
        dhtPins.add(b.intParam('pin', 2));
        vars.add(b.stringParam('name', 'temp'));
        break;
      case BlockKind.readHumidity:
        dhtPins.add(b.intParam('pin', 2));
        vars.add(b.stringParam('name', 'hum'));
        break;
      default:
        break;
    }
    for (final v in b.params.values) {
      if (v is Value) _value(v);
    }
    walk(b.body);
    walk(b.elseBody);
  }

  void _value(Value v) {
    if (v.kind == ValueKind.variable) vars.add(v.name);
    for (final a in v.args) {
      _value(a);
    }
  }
}
