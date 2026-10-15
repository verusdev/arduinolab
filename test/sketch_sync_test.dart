import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/blocks/block_model.dart';
import 'package:arduino_lab/blocks/sketch_parser.dart';
import 'package:arduino_lab/blocks/sketch_printer.dart';
import 'package:arduino_lab/i18n/app_lang.dart';
import 'package:arduino_lab/i18n/strings.dart';
import 'package:arduino_lab/state/app_state.dart';

/// The two directions of the sketch/block sync: typing changes the blocks, and
/// changing the blocks writes the code out again.
void main() {
  setUp(() => S.set(AppLang.en));
  tearDown(() => S.set(AppLang.ru));

  test('the code starts out as the blocks printed', () {
    final app = AppState()..addBlock(BlockKind.digitalWrite);
    expect(app.sketchAhead, isFalse);
    expect(app.sketchErrors, isEmpty);
    expect(app.sketchText, SketchPrinter.print(app.project.program));
    expect(app.sketchText, contains('digitalWrite('));
  });

  test('a sketch typed out becomes the blocks', () {
    final app = AppState();
    app.updateSketch('void setup() {\n'
        '  pinMode(13, OUTPUT);\n'
        '}\n'
        'void loop() {\n'
        '  digitalWrite(13, HIGH);\n'
        '  delay(250);\n'
        '}\n');

    expect(app.sketchAhead, isFalse);
    expect(app.sketchErrors, isEmpty);
    expect(app.project.program.setup.single.kind, BlockKind.setPinMode);
    expect(app.project.program.setup.single.stringParam('mode'), 'OUTPUT');
    expect(app.project.program.loop.map((b) => b.kind),
        [BlockKind.digitalWrite, BlockKind.wait]);
    expect(app.project.program.loop.first.intParam('pin'), 13);
    expect(app.project.program.loop.last.valueParam('ms').number, 250);
  });

  test('code with no blocks behind it leaves the blocks alone', () {
    final app = AppState()..addBlock(BlockKind.wait);
    final before = SketchPrinter.print(app.project.program);

    app.updateSketch('void loop() {\n  delay(t);\n}\n');

    expect(app.sketchAhead, isTrue);
    expect(app.sketchErrors.single.code, 'badDelay');
    expect(app.sketchErrors.single.line, 2);
    expect(app.project.program.loop.single.kind, BlockKind.wait);
    expect(SketchPrinter.print(app.project.program), before);
    // The text is kept as written, so the next keystroke is not thrown away.
    expect(app.sketchText, contains('delay(t);'));
  });

  test('a sketch that is still being written does no damage', () {
    final app = AppState()..addBlock(BlockKind.wait);
    for (final text in const [
      'v',
      'void lo',
      'void loop() {',
      'void loop() {\n  del',
    ]) {
      app.updateSketch(text);
      expect(app.project.program.loop.single.kind, BlockKind.wait, reason: text);
      expect(app.sketchErrors, isNotEmpty, reason: text);
    }
  });

  test('editing a block writes the code out again', () {
    final app = AppState()..addBlock(BlockKind.wait);
    app.updateSketch('void loop() {\n  delay(t);\n}\n');
    expect(app.sketchAhead, isTrue);

    app.updateBlockParam(app.project.program.loop.single.id, 'ms', 500.0);

    expect(app.sketchAhead, isFalse);
    expect(app.sketchErrors, isEmpty);
    expect(app.sketchText, contains('delay(500);'));
  });

  test('adding a block does too', () {
    final app = AppState();
    app.updateSketch('void loop() {\n  delay(t);\n}\n');
    app.addBlock(BlockKind.serialBegin);
    expect(app.sketchAhead, isFalse);
    expect(app.sketchText, contains('Serial.begin('));
  });

  test('rebuilding throws the typed code away', () {
    final app = AppState()..addBlock(BlockKind.wait);
    app.updateSketch('void loop() {\n  nonsense;\n}\n');
    expect(app.sketchAhead, isTrue);

    app.rebuildSketch();

    expect(app.sketchAhead, isFalse);
    expect(app.sketchErrors, isEmpty);
    expect(app.sketchText, SketchPrinter.print(app.project.program));
  });

  test('a new project starts from its own blocks', () {
    final app = AppState()..addBlock(BlockKind.wait);
    app.updateSketch('void loop() {\n  nonsense;\n}\n');
    expect(app.sketchAhead, isTrue);

    app.newProject();

    expect(app.sketchAhead, isFalse);
    expect(app.sketchErrors, isEmpty);
    expect(app.sketchText, SketchPrinter.print(app.project.program));
  });

  test('every code the parser reports can be said out loud', () {
    expect(SketchParser.errorCodes, isNotEmpty);
    for (final code in SketchParser.errorCodes) {
      expect(S.keys, contains('parse.$code'), reason: code);
    }
  });
}
