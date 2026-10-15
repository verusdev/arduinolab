import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/blocks/block_catalog.dart';
import 'package:arduino_lab/blocks/block_model.dart';
import 'package:arduino_lab/blocks/sketch_parser.dart';
import 'package:arduino_lab/blocks/sketch_printer.dart';
import 'package:arduino_lab/examples/examples.dart';

/// The parser is the exact inverse of the printer, so this is the property the
/// whole sketch editor rests on: whatever the printer writes, the parser reads
/// back into the same program, and the printer writes it out identically.
void expectRoundTrip(BlockProgram program, String what) {
  final code = SketchPrinter.print(program);
  final result = SketchParser.parse(code);
  expect(result.errors, isEmpty, reason: '$what:\n$code');
  expect(result.program, isNotNull, reason: what);
  expect(SketchPrinter.print(result.program!), code, reason: what);
}

/// One block of every kind, with the catalogue's own defaults — the same
/// values the palette hands to a user.
BlockProgram allKinds() {
  final blocks = <Block>[];
  for (final def in BlockCatalog.all) {
    final block = def.build();
    if (def.hasBody) {
      block.body.add(Block(kind: BlockKind.wait, params: {'ms': 100.0}));
    }
    if (def.hasElse) {
      block.elseBody.add(Block(kind: BlockKind.wait, params: {'ms': 200.0}));
    }
    blocks.add(block);
  }
  // A nested one as well: bodies have to nest as deep as the editor allows.
  blocks.add(Block(
    kind: BlockKind.repeatTimes,
    params: {'times': 3.0},
    body: [
      Block(
        kind: BlockKind.ifDo,
        params: {
          'condition':
              Value.binary('<', Value.varRef('x'), Value.num(10)),
        },
        body: [Block(kind: BlockKind.wait, params: {'ms': 50.0})],
      ),
    ],
  ));
  return BlockProgram(setup: blocks.take(3).toList(), loop: blocks.skip(3).toList());
}

void main() {
  group('round trip', () {
    test('every built-in example', () {
      for (final example in Examples.all) {
        expectRoundTrip(example.build().program, example.id);
      }
    });

    test('every block kind', () {
      expectRoundTrip(allKinds(), 'all kinds');
    });

    test('is stable when applied twice', () {
      for (final example in Examples.all) {
        final code = SketchPrinter.print(example.build().program);
        final once = SketchParser.parse(code).program!;
        final twice = SketchParser.parse(SketchPrinter.print(once)).program!;
        expect(SketchPrinter.print(twice), code, reason: example.id);
      }
    });

    test('keeps quoted text, escapes and all', () {
      final program = BlockProgram(loop: [
        Block(
            kind: BlockKind.serialPrintln,
            params: {'value': Value.text('say "hi"\n\tby')}),
      ]);
      expectRoundTrip(program, 'text with escapes');
    });
  });

  group('reference sketch', () {
    const source = '''
// Arduino Lab sketch
#include <Servo.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>
Servo servo9;
LiquidCrystal_I2C lcd(0x27, 16, 2);
DHT dht2(2, DHT11);
float x;

void setup() {
  servo9.attach(9);
  Serial.begin(9600);
  pinMode(13, OUTPUT);
}

void loop() {
  if (digitalRead(2) == 0) {
    digitalWrite(13, HIGH);
  } else {
    digitalWrite(13, LOW);
  }
  for (int i = 0; i < 4; i++) {
    delay(100);
  }
  while (true) {
    x += 1;
  }
  lcd.setCursor(0, 1);
  lcd.print("hi");
  tone(8, 440);
  noTone(8);
  servo9.write(90);
  x = map(analogRead(A0), 0, 1023, 0, 255);
  temp = dht2.readTemperature();
}
''';

    test('reads every section and call', () {
      final result = SketchParser.parse(source);
      expect(result.errors, isEmpty);
      final program = result.program!;

      expect(program.setup.map((b) => b.kind),
          [BlockKind.serialBegin, BlockKind.setPinMode]);
      expect(program.setup.first.valueParam('baud').number, 9600);

      final kinds = program.loop.map((b) => b.kind).toList();
      expect(kinds, [
        BlockKind.ifElse,
        BlockKind.repeatTimes,
        BlockKind.forever,
        BlockKind.lcdSetCursor,
        BlockKind.lcdPrint,
        BlockKind.tone,
        BlockKind.noTone,
        BlockKind.servoWrite,
        BlockKind.setVar,
        BlockKind.readTemperature,
      ]);

      final branch = program.loop.first;
      expect(branch.body.single.stringParam('value'), 'HIGH');
      expect(branch.elseBody.single.stringParam('value'), 'LOW');
      expect(branch.valueParam('condition').name, '==');

      expect(program.loop[1].valueParam('times').number, 4);
      expect(program.loop[5].intParam('pin'), 8);
      expect(program.loop[5].valueParam('frequency').number, 440);
      expect(program.loop[7].intParam('pin'), 9);
      expect(program.loop[9].stringParam('name'), 'temp');
      expect(program.loop[9].intParam('pin'), 2);
    });

    test('a servo on a pin implies its attach line', () {
      final result = SketchParser.parse(source);
      // `servo9.attach(9);` is wiring, not behaviour, so it makes no block.
      expect(result.program!.setup.length, 2);
    });

    test('an endless for is a forever block', () {
      final result = SketchParser.parse('void loop() {\n  for (;;) {\n  }\n}\n');
      expect(result.errors, isEmpty);
      expect(result.program!.loop.single.kind, BlockKind.forever);
    });

    test('a while (1) is a forever block too', () {
      final result = SketchParser.parse('void loop() {\n  while (1) {\n  }\n}\n');
      expect(result.errors, isEmpty);
      expect(result.program!.loop.single.kind, BlockKind.forever);
    });
  });

  group('pins', () {
    test('board labels become pin numbers', () {
      final result =
          SketchParser.parse('void loop() {\n  digitalWrite(D13, HIGH);\n'
              '  analogWrite(A0, 1);\n}\n');
      expect(result.errors, isEmpty);
      expect(result.program!.loop[0].intParam('pin'), 13);
      expect(result.program!.loop[0].stringParam('value'), 'HIGH');
      expect(result.program!.loop[1].intParam('pin'), 14);
    });

    test('a label inside an expression becomes its number', () {
      final result =
          SketchParser.parse('void loop() {\n  x = analogRead(A0);\n}\n');
      final value = result.program!.loop.single.valueParam('value');
      expect(value.kind, ValueKind.call);
      expect(value.name, 'analogRead');
      expect(value.args.single.number, 14);
    });
  });

  group('variables', () {
    test('a declaration with a value runs in setup', () {
      final result = SketchParser.parse('int speed = 5;\nvoid loop() {\n}\n');
      final block = result.program!.setup.single;
      expect(block.kind, BlockKind.setVar);
      expect(block.stringParam('name'), 'speed');
      expect(block.valueParam('value').number, 5);
    });

    test('a bare declaration makes no block', () {
      final result = SketchParser.parse('float x;\nvoid loop() {\n}\n');
      expect(result.program!.setup, isEmpty);
      expect(result.program!.loop, isEmpty);
    });

    test('a declaration inside a body makes a set block', () {
      final result =
          SketchParser.parse('void loop() {\n  int y = 5;\n}\n');
      final block = result.program!.loop.single;
      expect(block.kind, BlockKind.setVar);
      expect(block.stringParam('name'), 'y');
      expect(result.program!.setup, isEmpty);
    });
  });

  group('errors', () {
    SketchParseResult parseBody(String body) =>
        SketchParser.parse('void loop() {\n$body\n}\n');

    test('an empty sketch has no sections', () {
      final result = SketchParser.parse('// nothing here\n');
      expect(result.program, isNull);
      expect(result.errors.single.code, 'noSections');
      expect(result.errors.single.line, 1);
    });

    test('a statement with no block behind it', () {
      final result = parseBody('  delayMicroseconds(5);');
      expect(result.program, isNull);
      expect(result.errors.single.code, 'unknownStatement');
      expect(result.errors.single.line, 2);
      expect(result.errors.single.detail, 'delayMicroseconds');
    });

    test('digitalWrite wants HIGH or LOW', () {
      final result = parseBody('  digitalWrite(13, 2);');
      expect(result.errors.single.code, 'badValue');
      expect(result.errors.single.line, 2);
    });

    test('a variable is not a pin', () {
      final result = parseBody('  analogWrite(x, 5);');
      expect(result.errors.single.code, 'badPin');
      expect(result.errors.single.detail, 'x');
      expect(result.errors.single.line, 2);
    });

    test('delay needs a plain number', () {
      final result = parseBody('  delay(t);');
      expect(result.errors.single.code, 'badDelay');
      expect(result.errors.single.line, 2);
    });

    test('a function of your own has no block', () {
      final result = SketchParser.parse('void setup() {\n}\nvoid helper() {\n}\n');
      expect(result.errors.single.code, 'unknownFunction');
      expect(result.errors.single.detail, 'helper');
      expect(result.errors.single.line, 3);
    });

    test('a call to a function of your own', () {
      final result = parseBody('  x = helper(1);');
      expect(result.errors.single.code, 'unknownFunction');
      expect(result.errors.single.detail, 'helper');
    });

    test('only repeat-count loops are understood', () {
      final result = parseBody('  for (int i = 0; i < 10; i--) {\n  }');
      expect(result.errors.single.code, 'badFor');
      expect(result.errors.single.line, 2);
    });

    test('only while (true) is understood', () {
      final result = parseBody('  while (x) {\n  }');
      expect(result.errors.single.code, 'badWhile');
      expect(result.errors.single.line, 2);
    });

    test('a sketch that stops mid-sentence', () {
      final result = SketchParser.parse('void loop() {\n  delay(100);\n');
      expect(result.program, isNull);
      expect(result.errors.map((e) => e.code), contains('unterminated'));
    });

    test('several mistakes are all reported', () {
      final result = parseBody('  delayMicroseconds(5);\n  digitalWrite(13, 2);');
      expect(result.errors.map((e) => e.code),
          containsAll(<String>['unknownStatement', 'badValue']));
    });

    test('a mistake does not hide the rest of the sketch', () {
      final result = SketchParser.parse('void loop() {\n  delay(t);\n'
          '  digitalWrite(13, HIGH);\n}\n');
      expect(result.errors.length, 1);
      expect(result.errors.single.code, 'badDelay');
    });

    test('every code it can report is declared', () {
      final produced = <String>{};
      for (final source in const [
        '',
        'void loop() {\n  delayMicroseconds(5);\n}\n',
        'void setup() {\n}\nvoid helper() {\n}\n',
        'void loop() {\n  delay(100)\n}\n',
        'void loop() {\n}\n{\n}\n',
        'void loop() {\n  delay(t);\n}\n',
        'void loop() {\n  for (int i = 0; i < 9; i--) {\n  }\n}\n',
        'void loop() {\n  while (x) {\n  }\n}\n',
        'void loop() {\n  if (x {\n  }\n}\n',
        'void loop() {\n  x = 1 +;\n}\n',
        'void loop() {\n  analogWrite(x, 1);\n}\n',
        'void loop() {\n  digitalWrite(13, 2);\n}\n',
        'void loop() {\n  int = 5;\n}\n',
        'void loop() {\n  delay(100);\n',
      ]) {
        produced.addAll(SketchParser.parse(source).errors.map((e) => e.code));
      }
      // Nothing is reported that the catalogue has no wording for...
      expect(SketchParser.errorCodes.toSet(), containsAll(produced));
      // ...and nothing declared is unreachable.
      expect(produced, containsAll(SketchParser.errorCodes));
    });
  });

  group('expressions', () {
    BlockProgram loopWith(Value value) =>
        BlockProgram(loop: [Block(kind: BlockKind.setVar, params: {'name': 'x', 'value': value})]);

    test('operator precedence follows C', () {
      final program = SketchParser.parse(
              'void loop() {\n  x = 1 + 2 * 3 == 7 && y || z;\n}\n')
          .program!;
      final value = program.loop.single.valueParam('value');
      expect(value.name, '||');
      expect(value.args[0].name, '&&');
      expect(value.args[0].args[0].name, '==');
      expect(value.args[0].args[0].args[1].number, 7);
      expectRoundTrip(program, 'precedence');
    });

    test('unary minus keeps a literal negative', () {
      final program =
          SketchParser.parse('void loop() {\n  x = -5;\n}\n').program!;
      expect(program.loop.single.valueParam('value').number, -5);
      expectRoundTrip(program, 'negative literal');
    });

    test('unary minus on a variable is written as a subtraction', () {
      expectRoundTrip(loopWith(Value.binary('-', Value.zero, Value.varRef('y'))),
          'negated variable');
    });

    test('a hex literal is read as a number', () {
      final program =
          SketchParser.parse('void loop() {\n  x = 0x27;\n}\n').program!;
      expect(program.loop.single.valueParam('value').number, 39);
    });
  });
}
