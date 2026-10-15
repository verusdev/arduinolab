/// What kind of thing a suggestion is; used for the order and the colour of
/// the autocomplete popup.
enum SuggestionKind { keyword, type, constant, function, object, pin, variable }

/// One entry in the sketch editor's autocomplete popup.
class Suggestion {
  const Suggestion(this.label, this.kind, {String? insert, this.detail = ''})
      : insert = insert ?? label;

  /// Text shown in the list.
  final String label;

  /// Text put in the sketch when the entry is accepted.
  final String insert;

  final SuggestionKind kind;

  /// Short hint drawn on the right of the row.
  final String detail;
}

/// The vocabulary and the matching rules behind the autocomplete popup.
///
/// This is plain Dart on purpose: it lists only the shapes the parser
/// understands, so the two stay honest about each other, and the matcher can
/// be unit tested without a widget.
class SketchCompletions {
  SketchCompletions._();

  /// The words a sketch is built from.
  static const List<Suggestion> keywords = [
    Suggestion('void', SuggestionKind.keyword, insert: 'void ', detail: 'function'),
    Suggestion('int', SuggestionKind.type, insert: 'int '),
    Suggestion('float', SuggestionKind.type, insert: 'float '),
    Suggestion('long', SuggestionKind.type, insert: 'long '),
    Suggestion('bool', SuggestionKind.type, insert: 'bool '),
    Suggestion('if', SuggestionKind.keyword, insert: 'if ('),
    Suggestion('else', SuggestionKind.keyword, insert: 'else {'),
    Suggestion('for', SuggestionKind.keyword, insert: 'for () {\n  \n}'),
    Suggestion('while', SuggestionKind.keyword, insert: 'while (true) {\n  \n}'),
    Suggestion('return', SuggestionKind.keyword, insert: 'return '),
    Suggestion('true', SuggestionKind.constant),
    Suggestion('false', SuggestionKind.constant),
  ];

  /// Constants the pin blocks accept verbatim.
  static const List<Suggestion> constants = [
    Suggestion('HIGH', SuggestionKind.constant),
    Suggestion('LOW', SuggestionKind.constant),
    Suggestion('OUTPUT', SuggestionKind.constant),
    Suggestion('INPUT', SuggestionKind.constant),
    Suggestion('INPUT_PULLUP', SuggestionKind.constant),
  ];

  /// Library calls, spelled the way `SketchPrinter` spells them.
  static const List<Suggestion> functions = [
    Suggestion('delay(', SuggestionKind.function, detail: 'wait'),
    Suggestion('pinMode(', SuggestionKind.function),
    Suggestion('digitalWrite(', SuggestionKind.function),
    Suggestion('analogWrite(', SuggestionKind.function, detail: 'PWM'),
    Suggestion('analogRead(', SuggestionKind.function),
    Suggestion('digitalRead(', SuggestionKind.function),
    Suggestion('millis()', SuggestionKind.function),
    Suggestion('map(', SuggestionKind.function),
    Suggestion('constrain(', SuggestionKind.function),
    Suggestion('abs(', SuggestionKind.function),
    Suggestion('sqrt(', SuggestionKind.function),
    Suggestion('pow(', SuggestionKind.function),
    Suggestion('min(', SuggestionKind.function),
    Suggestion('max(', SuggestionKind.function),
    Suggestion('random(', SuggestionKind.function),
    Suggestion('tone(', SuggestionKind.function),
    Suggestion('noTone(', SuggestionKind.function),
    Suggestion('pulseIn(', SuggestionKind.function),
    Suggestion('Serial.begin(', SuggestionKind.object),
    Suggestion('Serial.print(', SuggestionKind.object),
    Suggestion('Serial.println(', SuggestionKind.object),
    Suggestion('lcd.init();', SuggestionKind.object, detail: 'LCD'),
    Suggestion('lcd.clear();', SuggestionKind.object, detail: 'LCD'),
    Suggestion('lcd.setCursor(', SuggestionKind.object, detail: 'LCD'),
    Suggestion('lcd.print(', SuggestionKind.object, detail: 'LCD'),
    // Servos and DHT sensors are named after the pin they sit on, so the pin
    // survives the trip through the C++ and back.
    Suggestion('servo9.write(', SuggestionKind.object, detail: 'pin 9'),
    Suggestion('dht2.readTemperature();', SuggestionKind.object, detail: 'pin 2'),
    Suggestion('dht2.readHumidity();', SuggestionKind.object, detail: 'pin 2'),
  ];

  /// Board labels, offered wherever a pin is expected.
  static List<Suggestion> get pins => [
        for (var i = 0; i <= 13; i++)
          Suggestion('D$i', SuggestionKind.pin, detail: 'pin $i'),
        for (var i = 0; i <= 5; i++)
          Suggestion('A$i', SuggestionKind.pin, detail: 'pin ${14 + i}'),
      ];

  static List<Suggestion>? _vocabulary;

  static List<Suggestion> get _all =>
      _vocabulary ??= [...keywords, ...constants, ...functions, ...pins];

  /// The word being typed just before [caret], or `''` when there is none.
  ///
  /// A word that follows a `.` is a member name, not something worth
  /// completing, so it is reported as empty.
  static String wordBefore(String text, int caret) {
    if (caret <= 0 || caret > text.length) return '';
    var start = caret;
    while (start > 0 && _isWordChar(text.codeUnitAt(start - 1))) {
      start--;
    }
    if (start == caret) return '';
    if (start > 0 && text.codeUnitAt(start - 1) == 0x2E) return '';
    return text.substring(start, caret);
  }

  static bool _isWordChar(int c) =>
      (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      c == 0x5F; // _

  /// Identifiers the sketch declares or assigns, so the popup can offer them.
  static Set<String> variablesIn(String source) {
    final names = <String>{};
    for (final m in _declaration.allMatches(source)) {
      names.add(m.group(1)!);
    }
    for (final m in _assignment.allMatches(source)) {
      names.add(m.group(1)!);
    }
    names.removeAll(_reserved);
    return names;
  }

  static final RegExp _declaration = RegExp(
      r'\b(?:int|long|float|double|bool|byte|char|String)\s+'
      r'([A-Za-z_]\w*)\s*[;=,]');

  // Matches `x = 1` and `x += 1`, but never `x == 1`.
  static final RegExp _assignment =
      RegExp(r'\b([A-Za-z_]\w*)\s*(?:[-+*/]=|=(?!=))');

  static const Set<String> _reserved = {
    'setup',
    'loop',
    'void',
    'int',
    'long',
    'float',
    'double',
    'bool',
    'byte',
    'char',
    'String',
    'if',
    'else',
    'for',
    'while',
    'return',
    'true',
    'false',
  };

  /// Entries that start with [prefix], grouped by kind and then alphabetical.
  /// An empty prefix offers nothing, so the popup stays out of the way.
  static List<Suggestion> forPrefix(String prefix,
      {Set<String> variables = const {}, int limit = 8}) {
    if (prefix.isEmpty) return const [];
    final lower = prefix.toLowerCase();
    final hits = <Suggestion>[];
    for (final s in _all) {
      if (s.label.toLowerCase().startsWith(lower)) hits.add(s);
    }
    for (final name in variables) {
      if (name.toLowerCase().startsWith(lower)) {
        hits.add(Suggestion(name, SuggestionKind.variable, detail: 'variable'));
      }
    }
    hits.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }
}
