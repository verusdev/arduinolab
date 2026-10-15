import '../core/ids.dart';

/// Value expression kind.
enum ValueKind { number, variable, binary, call, text }

/// A small expression tree used inside block fields and conditions.
class Value {
  const Value._(this.kind, {this.number = 0, this.name = '', this.args = const []});

  factory Value.num(double v) => Value._(ValueKind.number, number: v);
  factory Value.varRef(String name) => Value._(ValueKind.variable, name: name);
  factory Value.binary(String op, Value a, Value b) =>
      Value._(ValueKind.binary, name: op, args: [a, b]);
  factory Value.call(String fn, [List<Value> args = const []]) =>
      Value._(ValueKind.call, name: fn, args: args);
  factory Value.text(String s) => Value._(ValueKind.text, name: s);

  final ValueKind kind;
  final double number;

  /// Variable name, operator symbol or function name depending on [kind].
  final String name;
  final List<Value> args;

  /// A literal zero value used as a safe default.
  static final Value zero = Value.num(0);

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'number': number,
        'name': name,
        'args': args.map((a) => a.toJson()).toList(),
      };

  factory Value.fromJson(Map<String, Object?> j) {
    final kind = ValueKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => ValueKind.number);
    final args = ((j['args'] as List?) ?? const [])
        .map((e) => Value.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    return Value._(kind,
        number: (j['number'] as num?)?.toDouble() ?? 0,
        name: j['name'] as String? ?? '',
        args: args);
  }
}

/// Every block type the editor offers.
enum BlockKind {
  // Control
  wait, // delay(ms)
  repeatTimes, // repeat N times { body }
  forever, // forever { body }
  ifDo, // if <cond> { body }
  ifElse, // if <cond> { body } else { elseBody }
  // Pins
  setPinMode, // pinMode(pin, mode)
  digitalWrite, // digitalWrite(pin, HIGH/LOW)
  analogWrite, // analogWrite(pin, value)
  // Variables
  setVar, // var = value
  changeVar, // var += value
  // Serial
  serialBegin, // Serial.begin(baud)
  serialPrint, // Serial.print(value)
  serialPrintln, // Serial.println(value)
  // Components
  servoWrite, // servoWrite(pin, angle)
  tone, // tone(pin, frequency)
  noTone, // noTone(pin)
  lcdInit, // lcd.init()
  lcdClear, // lcd.clear()
  lcdSetCursor, // lcd.setCursor(col, row)
  lcdPrint, // lcd.print(value)
  // Sensors
  readUltrasonic, // var = ultrasonic(trig, echo)
  readTemperature, // var = dht.temperature(pin)
  readHumidity, // var = dht.humidity(pin)
}

/// A single block with its parameters and nested bodies.
class Block {
  Block({
    required this.kind,
    String? id,
    Map<String, Object?>? params,
    List<Block>? body,
    List<Block>? elseBody,
  })  : id = id ?? newId('b'),
        params = params ?? {},
        body = body ?? [],
        elseBody = elseBody ?? [];

  final String id;
  BlockKind kind;
  final Map<String, Object?> params;

  /// Nested blocks (loop / condition body).
  final List<Block> body;

  /// Blocks executed when an `if/else` condition is false.
  final List<Block> elseBody;

  /// Reads an integer parameter with a default.
  int intParam(String key, [int fallback = 0]) {
    final v = params[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String stringParam(String key, [String fallback = '']) =>
      params[key] as String? ?? fallback;

  bool boolParam(String key, [bool fallback = false]) {
    final v = params[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    return fallback;
  }

  Value valueParam(String key) {
    final v = params[key];
    if (v is Value) return v;
    if (v is num) return Value.num(v.toDouble());
    return Value.zero;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'params': params.map((k, v) => MapEntry(k, _encodeParam(v))),
        'body': body.map((b) => b.toJson()).toList(),
        'elseBody': elseBody.map((b) => b.toJson()).toList(),
      };

  static Object? _encodeParam(Object? v) => v is Value ? v.toJson() : v;

  factory Block.fromJson(Map<String, Object?> j) {
    final kind = BlockKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => BlockKind.wait);
    final rawParams = (j['params'] as Map?)?.cast<String, Object?>() ?? {};
    final params = <String, Object?>{};
    rawParams.forEach((k, v) {
      if (v is Map && v['kind'] != null) {
        params[k] = Value.fromJson(v.cast<String, Object?>());
      } else {
        params[k] = v;
      }
    });
    return Block(
      id: j['id'] as String?,
      kind: kind,
      params: params,
      body: ((j['body'] as List?) ?? const [])
          .map((e) => Block.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
      elseBody: ((j['elseBody'] as List?) ?? const [])
          .map((e) => Block.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}

/// A complete block program split into the one-shot setup section and the
/// repeatedly executed loop section.
class BlockProgram {
  BlockProgram({List<Block>? setup, List<Block>? loop})
      : setup = setup ?? [],
        loop = loop ?? [];

  final List<Block> setup;
  final List<Block> loop;

  bool get isEmpty => setup.isEmpty && loop.isEmpty;

  BlockProgram copy() => BlockProgram(
        setup: setup.map((b) => Block.fromJson(b.toJson())).toList(),
        loop: loop.map((b) => Block.fromJson(b.toJson())).toList(),
      );

  Map<String, Object?> toJson() => {
        'setup': setup.map((b) => b.toJson()).toList(),
        'loop': loop.map((b) => b.toJson()).toList(),
      };

  factory BlockProgram.fromJson(Map<String, Object?> j) => BlockProgram(
        setup: ((j['setup'] as List?) ?? const [])
            .map((e) => Block.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        loop: ((j['loop'] as List?) ?? const [])
            .map((e) => Block.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );
}
