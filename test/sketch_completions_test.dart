import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/blocks/sketch_completions.dart';

void main() {
  group('wordBefore', () {
    test('reads the identifier being typed', () {
      expect(SketchCompletions.wordBefore('  del', 5), 'del');
      expect(SketchCompletions.wordBefore('x = ana', 7), 'ana');
      expect(SketchCompletions.wordBefore('delay', 5), 'delay');
    });

    test('is empty when the caret is not on a word', () {
      expect(SketchCompletions.wordBefore('delay(', 6), '');
      expect(SketchCompletions.wordBefore('', 0), '');
      expect(SketchCompletions.wordBefore('x = ', 4), '');
    });

    test('leaves member names alone', () {
      // `Serial.pr` is a member, not a name of its own.
      expect(SketchCompletions.wordBefore('Serial.pr', 9), '');
    });
  });

  group('forPrefix', () {
    test('offers nothing for an empty prefix', () {
      expect(SketchCompletions.forPrefix(''), isEmpty);
    });

    test('matches from the start of the name', () {
      final hits = SketchCompletions.forPrefix('dig');
      expect(hits.map((s) => s.label),
          containsAll(<String>['digitalRead(', 'digitalWrite(']));
      expect(hits.every((s) => s.label.toLowerCase().startsWith('dig')), isTrue);
    });

    test('offers nothing when nothing matches', () {
      expect(SketchCompletions.forPrefix('zzz'), isEmpty);
    });

    test('puts pins on the list with the number they stand for', () {
      final hit = SketchCompletions.forPrefix('A1').single;
      expect(hit.label, 'A1');
      expect(hit.detail, 'pin 15');
      expect(hit.kind, SuggestionKind.pin);
    });

    test('leads with keywords', () {
      expect(SketchCompletions.forPrefix('i').first.label, 'if');
    });

    test('keeps the list short', () {
      expect(SketchCompletions.forPrefix('d', limit: 3).length, 3);
    });

    test('inserts more than the label where that helps', () {
      final hit =
          SketchCompletions.forPrefix('if').first;
      expect(hit.label, 'if');
      expect(hit.insert, 'if (');
    });

    test('offers the variables of the sketch being typed', () {
      final hits = SketchCompletions.forPrefix('sp',
          variables: SketchCompletions.variablesIn('float speed;'));
      expect(hits.single.label, 'speed');
      expect(hits.single.kind, SuggestionKind.variable);
    });
  });

  group('variablesIn', () {
    test('collects declarations and assignments', () {
      final vars = SketchCompletions.variablesIn('float speed;\n'
          'void loop() {\n  speed = 1;\n  other += 2;\n}\n');
      expect(vars, containsAll(<String>['speed', 'other']));
    });

    test('never mistakes a keyword for a variable', () {
      final vars = SketchCompletions.variablesIn('void loop() {\n  x = 1;\n}\n');
      expect(vars, isNot(contains('loop')));
      expect(vars, isNot(contains('void')));
    });

    test('is not fooled by a comparison', () {
      final vars = SketchCompletions.variablesIn('if (a == b) { }\n');
      expect(vars, isNot(contains('a')));
    });
  });
}
