import 'block_model.dart';

/// Kind of editor to use for a block parameter in the UI.
enum ParamEditor {
  number,
  value,
  pin,
  mode,
  digitalValue,
  varName,
  op,
  condition,
  dropdown,
}

class ParamDef {
  const ParamDef(this.key, this.label, this.editor, this.defaultValue,
      {this.options = const []});

  final String key;

  /// Caption shown before the editor, written in English and used as the key
  /// `par.<label>` (empty when the block needs no caption).
  final String label;
  final ParamEditor editor;
  final Object? defaultValue;
  final List<String> options;
}

/// Description of one block type shown in the palette.
class BlockDef {
  const BlockDef({
    required this.kind,
    required this.label,
    required this.category,
    this.params = const [],
    this.hasBody = false,
    this.hasElse = false,
  });

  final BlockKind kind;

  /// English display name: the reference wording for translators. The editor
  /// shows the translation under the `blk.<kind.name>` key instead.
  final String label;

  /// English grouping, kept as a stable key; shown as `blockcat.<value>`.
  final String category;
  final List<ParamDef> params;
  final bool hasBody;
  final bool hasElse;

  Block build() {
    final map = <String, Object?>{};
    for (final p in params) {
      map[p.key] = p.defaultValue is Value
          ? Value.fromJson((p.defaultValue as Value).toJson())
          : p.defaultValue;
    }
    return Block(kind: kind, params: map);
  }
}

/// Registry of every available block.
class BlockCatalog {
  static final List<BlockDef> all = [
    // ---- Control ----
    BlockDef(
        kind: BlockKind.wait,
        label: 'wait',
        category: 'Control',
        params: [ParamDef('ms', 'ms', ParamEditor.number, 1000.0)]),
    BlockDef(
        kind: BlockKind.repeatTimes,
        label: 'repeat',
        category: 'Control',
        hasBody: true,
        params: [ParamDef('times', 'times', ParamEditor.number, 10.0)]),
    BlockDef(
        kind: BlockKind.forever, label: 'forever', category: 'Control', hasBody: true),
    BlockDef(
        kind: BlockKind.ifDo,
        label: 'if … then',
        category: 'Control',
        hasBody: true,
        params: [
          ParamDef(
              'condition',
              '',
              ParamEditor.condition,
              Value.binary('<', Value.call('analogRead', [Value.num(14)]),
                  Value.num(512)))
        ]),
    BlockDef(
        kind: BlockKind.ifElse,
        label: 'if … then / else',
        category: 'Control',
        hasBody: true,
        hasElse: true,
        params: [
          ParamDef(
              'condition',
              '',
              ParamEditor.condition,
              Value.binary('>', Value.call('analogRead', [Value.num(14)]),
                  Value.num(512)))
        ]),

    // ---- Pins ----
    BlockDef(
        kind: BlockKind.setPinMode,
        label: 'set pin mode',
        category: 'Pins',
        params: [
          ParamDef('pin', 'pin', ParamEditor.pin, 13),
          ParamDef('mode', 'mode', ParamEditor.dropdown, 'OUTPUT',
              options: ['OUTPUT', 'INPUT', 'INPUT_PULLUP']),
        ]),
    BlockDef(
        kind: BlockKind.digitalWrite,
        label: 'digital write',
        category: 'Pins',
        params: [
          ParamDef('pin', 'pin', ParamEditor.pin, 13),
          ParamDef('value', 'value', ParamEditor.digitalValue, 'HIGH'),
        ]),
    BlockDef(
        kind: BlockKind.analogWrite,
        label: 'analog write (PWM)',
        category: 'Pins',
        params: [
          ParamDef('pin', 'pin', ParamEditor.pin, 9),
          ParamDef('value', 'value 0-255', ParamEditor.value, 128.0),
        ]),

    // ---- Variables ----
    BlockDef(
        kind: BlockKind.setVar,
        label: 'set',
        category: 'Variables',
        params: [
          ParamDef('name', 'name', ParamEditor.varName, 'x'),
          ParamDef('value', 'to', ParamEditor.value, 0.0),
        ]),
    BlockDef(
        kind: BlockKind.changeVar,
        label: 'change',
        category: 'Variables',
        params: [
          ParamDef('name', 'name', ParamEditor.varName, 'x'),
          ParamDef('op', '', ParamEditor.dropdown, '+=',
              options: ['+=', '-=', '*=', '/=']),
          ParamDef('value', 'by', ParamEditor.value, 1.0),
        ]),

    // ---- Serial ----
    BlockDef(
        kind: BlockKind.serialBegin,
        label: 'Serial begin',
        category: 'Serial',
        params: [ParamDef('baud', 'baud', ParamEditor.number, 9600.0)]),
    BlockDef(
        kind: BlockKind.serialPrint,
        label: 'Serial print',
        category: 'Serial',
        params: [ParamDef('value', '', ParamEditor.value, Value.zero)]),
    BlockDef(
        kind: BlockKind.serialPrintln,
        label: 'Serial println',
        category: 'Serial',
        params: [ParamDef('value', '', ParamEditor.value, Value.text('Hello'))]),

    // ---- Components ----
    BlockDef(
        kind: BlockKind.servoWrite,
        label: 'servo write',
        category: 'Components',
        params: [
          ParamDef('pin', 'pin', ParamEditor.pin, 9),
          ParamDef('angle', 'angle', ParamEditor.value, 90.0),
        ]),
    BlockDef(
        kind: BlockKind.tone,
        label: 'play tone',
        category: 'Components',
        params: [
          ParamDef('pin', 'pin', ParamEditor.pin, 8),
          ParamDef('frequency', 'hz', ParamEditor.value, 440.0),
        ]),
    BlockDef(
        kind: BlockKind.noTone,
        label: 'stop tone',
        category: 'Components',
        params: [ParamDef('pin', 'pin', ParamEditor.pin, 8)]),
    BlockDef(kind: BlockKind.lcdInit, label: 'LCD init', category: 'Display'),
    BlockDef(kind: BlockKind.lcdClear, label: 'LCD clear', category: 'Display'),
    BlockDef(
        kind: BlockKind.lcdSetCursor,
        label: 'LCD cursor',
        category: 'Display',
        params: [
          ParamDef('col', 'col', ParamEditor.value, 0.0),
          ParamDef('row', 'row', ParamEditor.value, 0.0),
        ]),
    BlockDef(
        kind: BlockKind.lcdPrint,
        label: 'LCD print',
        category: 'Display',
        params: [ParamDef('value', '', ParamEditor.value, Value.text('Hello'))]),

    // ---- Sensors ----
    BlockDef(
        kind: BlockKind.readUltrasonic,
        label: 'read distance (cm)',
        category: 'Sensors',
        params: [
          ParamDef('name', 'into', ParamEditor.varName, 'distance'),
          ParamDef('trig', 'trig', ParamEditor.pin, 7),
          ParamDef('echo', 'echo', ParamEditor.pin, 6),
        ]),
    BlockDef(
        kind: BlockKind.readTemperature,
        label: 'read temperature',
        category: 'Sensors',
        params: [
          ParamDef('name', 'into', ParamEditor.varName, 'temp'),
          ParamDef('pin', 'pin', ParamEditor.pin, 2),
        ]),
    BlockDef(
        kind: BlockKind.readHumidity,
        label: 'read humidity',
        category: 'Sensors',
        params: [
          ParamDef('name', 'into', ParamEditor.varName, 'hum'),
          ParamDef('pin', 'pin', ParamEditor.pin, 2),
        ]),
  ];

  static final Map<BlockKind, BlockDef> byKind = {
    for (final d in all) d.kind: d
  };

  static BlockDef def(BlockKind kind) => byKind[kind]!;

  static List<String> get categories =>
      all.map((d) => d.category).toSet().toList();

  static List<BlockDef> inCategory(String category) =>
      all.where((d) => d.category == category).toList();
}
