import '../models/pin.dart';
import 'block_model.dart';

/// One place in the sketch the parser could not turn into blocks.
class SketchError {
  const SketchError(this.line, this.code, [this.detail]);

  /// 1-based line in the source.
  final int line;

  /// Stable code the interface renders as `parse.<code>`; the parser never
  /// carries user-facing wording, so the editor stays the only place that
  /// knows how to say things.
  final String code;

  /// Offending token or name, when the message has room for one.
  final String? detail;

  @override
  String toString() => 'SketchError(line $line, $code'
      '${detail == null ? '' : ', $detail'})';
}

/// The outcome of reading a sketch: either a block tree, or the places it could
/// not be understood.
class SketchParseResult {
  const SketchParseResult({this.program, this.errors = const []});

  /// The blocks the sketch describes. Null whenever there was any error, so a
  /// half-understood sketch can never quietly replace a good program.
  final BlockProgram? program;
  final List<SketchError> errors;

  bool get ok => program != null && errors.isEmpty;
}

/// Reads Arduino C++ back into the block tree.
///
/// This is the inverse of `SketchPrinter`: everything the printer writes is
/// understood here, and `SketchPrinter.print(SketchParser.parse(s).program)`
/// reproduces [source] byte for byte. Anything the printer cannot express — a
/// helper function of your own, `delayMicroseconds` outside the ultrasonic
/// idiom, a loop that is not a plain "repeat N times" — is reported as an
/// error rather than guessed at, because a block tree that only approximates
/// the code is worse than no blocks at all.
class SketchParser {
  SketchParser._();

  /// Every code [parse] can report.
  ///
  /// The parser never carries wording, so the interface turns each of these
  /// into a `parse.<code>` message; this list is the contract between the two,
  /// and the tests hold the catalogue to it.
  static const List<String> errorCodes = [
    'noSections',
    'unknownStatement',
    'unknownFunction',
    'expectedToken',
    'unexpectedToken',
    'badDelay',
    'badFor',
    'badWhile',
    'badCondition',
    'badExpression',
    'badPin',
    'badValue',
    'badName',
    'unterminated',
  ];

  /// Parses [source]. Never throws: a broken sketch comes back as
  /// [SketchParseResult.errors] carrying line numbers.
  static SketchParseResult parse(String source) =>
      _Parser(_Lexer(source).scan()).run();
}

// ------------------------------------------------------------------- lexing

bool _isDigit(int u) => u >= 0x30 && u <= 0x39;
bool _isAlpha(int u) => (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A);
bool _isWordChar(int u) => _isDigit(u) || _isAlpha(u) || u == 0x5F;
bool _isHexDigit(int u) =>
    _isDigit(u) || (u >= 0x41 && u <= 0x46) || (u >= 0x61 && u <= 0x66);

enum _Kind { word, number, string, punct, directive, eof }

class _Tok {
  const _Tok(this.kind, this.text, this.line);

  final _Kind kind;
  final String text;
  final int line;

  @override
  String toString() => '${kind.name}($text)@$line';
}

/// Turns the source into tokens. Comments and `#include` lines survive only as
/// the lines they occupy, which is what the line numbers of the errors need.
class _Lexer {
  _Lexer(this.src);

  final String src;
  int _at = 0;
  int _line = 1;

  List<_Tok> scan() {
    final out = <_Tok>[];
    while (true) {
      _skipSpace();
      if (_at >= src.length) break;
      final u = src.codeUnitAt(_at);
      if (u == 0x23) {
        out.add(_Tok(_Kind.directive, _directive(), _line));
      } else if (u == 0x22) {
        out.add(_string());
      } else if (_isDigit(u)) {
        out.add(_number());
      } else if (_isWordChar(u)) {
        out.add(_word());
      } else {
        out.add(_punct());
      }
    }
    out.add(_Tok(_Kind.eof, '', _line));
    return out;
  }

  void _skipSpace() {
    while (_at < src.length) {
      final u = src.codeUnitAt(_at);
      if (u == 0x0A) {
        _line++;
        _at++;
      } else if (u == 0x20 || u == 0x09 || u == 0x0D) {
        _at++;
      } else if (u == 0x2F &&
          _at + 1 < src.length &&
          src.codeUnitAt(_at + 1) == 0x2F) {
        while (_at < src.length && src.codeUnitAt(_at) != 0x0A) {
          _at++;
        }
      } else if (u == 0x2F &&
          _at + 1 < src.length &&
          src.codeUnitAt(_at + 1) == 0x2A) {
        _at += 2;
        while (_at < src.length) {
          if (src.codeUnitAt(_at) == 0x0A) _line++;
          if (src.codeUnitAt(_at) == 0x2A &&
              _at + 1 < src.length &&
              src.codeUnitAt(_at + 1) == 0x2F) {
            _at += 2;
            break;
          }
          _at++;
        }
      } else {
        break;
      }
    }
  }

  String _directive() {
    final start = _at;
    while (_at < src.length && src.codeUnitAt(_at) != 0x0A) {
      _at++;
    }
    return src.substring(start, _at);
  }

  _Tok _string() {
    final line = _line;
    _at++; // opening quote
    final b = StringBuffer();
    while (_at < src.length && src.codeUnitAt(_at) != 0x22) {
      final u = src.codeUnitAt(_at);
      if (u == 0x5C && _at + 1 < src.length) {
        // The printer escapes `\`, `"`, newline and tab; anything else keeps
        // the character it escapes, so the trip back is lossless.
        _at++;
        final e = src.codeUnitAt(_at);
        b.write(e == 0x6E
            ? '\n'
            : e == 0x74
                ? '\t'
                : src[_at]);
        _at++;
      } else {
        if (u == 0x0A) _line++;
        b.write(src[_at]);
        _at++;
      }
    }
    if (_at < src.length) _at++; // closing quote
    return _Tok(_Kind.string, b.toString(), line);
  }

  _Tok _number() {
    final line = _line;
    final start = _at;
    if (src.codeUnitAt(_at) == 0x30 &&
        _at + 1 < src.length &&
        (src.codeUnitAt(_at + 1) == 0x78 || src.codeUnitAt(_at + 1) == 0x58)) {
      _at += 2;
      while (_at < src.length && _isHexDigit(src.codeUnitAt(_at))) {
        _at++;
      }
      return _Tok(_Kind.number, src.substring(start, _at), line);
    }
    while (_at < src.length && _isDigit(src.codeUnitAt(_at))) {
      _at++;
    }
    if (_at < src.length && src.codeUnitAt(_at) == 0x2E) {
      _at++;
      while (_at < src.length && _isDigit(src.codeUnitAt(_at))) {
        _at++;
      }
    }
    if (_at < src.length &&
        (src.codeUnitAt(_at) == 0x65 || src.codeUnitAt(_at) == 0x45)) {
      var k = _at + 1;
      if (k < src.length &&
          (src.codeUnitAt(k) == 0x2B || src.codeUnitAt(k) == 0x2D)) {
        k++;
      }
      if (k < src.length && _isDigit(src.codeUnitAt(k))) {
        _at = k;
        while (_at < src.length && _isDigit(src.codeUnitAt(_at))) {
          _at++;
        }
      }
    }
    return _Tok(_Kind.number, src.substring(start, _at), line);
  }

  _Tok _word() {
    final line = _line;
    final start = _at;
    while (_at < src.length && _isWordChar(src.codeUnitAt(_at))) {
      _at++;
    }
    return _Tok(_Kind.word, src.substring(start, _at), line);
  }

  _Tok _punct() {
    final line = _line;
    if (_at + 1 < src.length) {
      final two = src.substring(_at, _at + 2);
      if (_twoChar.contains(two)) {
        _at += 2;
        return _Tok(_Kind.punct, two, line);
      }
    }
    final one = src[_at];
    _at++;
    return _Tok(_Kind.punct, one, line);
  }

  static const Set<String> _twoChar = {
    '==', '!=', '<=', '>=', '&&', '||',
    '+=', '-=', '*=', '/=', '++', '--',
  };
}

// ----------------------------------------------------------------- parsing

/// Types a declaration may start with, including the two library objects the
/// printer declares.
const Set<String> _types = {
  'void',
  'int',
  'long',
  'float',
  'double',
  'bool',
  'boolean',
  'byte',
  'char',
  'unsigned',
  'word',
  'String',
  'Servo',
  'DHT',
  'LiquidCrystal_I2C',
};

const Set<String> _modes = {'OUTPUT', 'INPUT', 'INPUT_PULLUP'};
const Set<String> _assignOps = {'+=', '-=', '*=', '/='};

/// Functions the runtime can actually evaluate; a call to anything else is
/// reported instead of quietly evaluating to zero.
const Set<String> _callable = {
  'analogRead',
  'digitalRead',
  'millis',
  'micros',
  'map',
  'constrain',
  'abs',
  'sqrt',
  'pow',
  'min',
  'max',
  'random',
  'pulseIn',
  'readTemperature',
  'readHumidity',
  'ultrasonicDistance',
};

/// A board label such as `D13` or `A0`.
final RegExp _pinLabel = RegExp(r'^[DA]\d{1,2}$', caseSensitive: false);

class _Parser {
  _Parser(this.toks);

  final List<_Tok> toks;
  int i = 0;

  final List<SketchError> errors = [];
  final List<Block> setup = [];
  final List<Block> loop = [];
  bool sawSection = false;

  SketchParseResult run() {
    while (!_eof) {
      _global();
    }
    if (!sawSection) errors.add(const SketchError(1, 'noSections'));
    if (errors.isNotEmpty) return SketchParseResult(errors: errors);
    return SketchParseResult(program: BlockProgram(setup: setup, loop: loop));
  }

  // ------------------------------------------------------------- token help

  _Tok get _cur => toks[i];
  bool get _eof => _cur.kind == _Kind.eof;
  bool _at(String text) => _cur.text == text;

  _Tok _peek(int off) =>
      toks[i + off < toks.length ? i + off : toks.length - 1];

  bool _eat(String text) {
    if (_cur.text != text) return false;
    i++;
    return true;
  }

  void _advance() {
    if (!_eof) i++;
  }

  void _panic(int line, String code, [String? detail]) {
    errors.add(SketchError(line, code, detail));
  }

  /// Skips to just past the next `;`, or to the `}` that closes the block, so
  /// that one bad statement cannot derail the rest of the sketch.
  void _recover() {
    while (!_eof && !_at(';') && !_at('}')) {
      _advance();
    }
    if (_at(';')) _advance();
  }

  /// Consumes a declaration or a statement without turning it into blocks —
  /// the shape is understood, it just has no behaviour of its own.
  void _skipStatement() => _recover();

  void _skipParens() {
    if (!_eat('(')) return;
    var depth = 1;
    while (!_eof && depth > 0) {
      if (_at('(')) {
        depth++;
      } else if (_at(')')) {
        depth--;
      }
      _advance();
    }
  }

  void _skipBlock() {
    if (!_eat('{')) {
      _recover();
      return;
    }
    var depth = 1;
    while (!_eof && depth > 0) {
      if (_at('{')) {
        depth++;
      } else if (_at('}')) {
        depth--;
      }
      _advance();
    }
  }

  /// Finishes the argument list a statement is inside, so that what follows it
  /// can still be skipped. Used when a statement has already gone wrong and
  /// [\_recover] would run straight into the body it is meant to swallow.
  void _skipRestOfParens() {
    var depth = 0;
    while (!_eof) {
      if (_at('(')) {
        depth++;
      } else if (_at(')')) {
        if (depth == 0) {
          _advance();
          return;
        }
        depth--;
      }
      _advance();
    }
  }

  int _matchingParen(int open) {
    if (toks[open].text != '(') return -1;
    var depth = 0;
    for (var k = open; k < toks.length; k++) {
      final t = toks[k].text;
      if (t == '(') {
        depth++;
      } else if (t == ')') {
        depth--;
        if (depth == 0) return k;
      }
    }
    return -1;
  }

  /// Runs [matcher] and undoes everything it did when it declines to match, so
  /// statement forms can be tried one after another.
  List<Block>? _try(List<Block>? Function() matcher) {
    final mark = i;
    final depth = errors.length;
    final result = matcher();
    if (result == null) {
      i = mark;
      errors.removeRange(depth, errors.length);
    }
    return result;
  }

  // ------------------------------------------------------------- top level

  void _global() {
    final t = _cur;
    if (t.kind == _Kind.directive) {
      _advance();
      return;
    }
    if (_eat(';')) return;
    if (t.kind == _Kind.word && _types.contains(t.text)) {
      _globalDeclaration();
      return;
    }
    _panic(t.line, 'unexpectedToken', t.text);
    _advance();
    _recover();
  }

  /// A function definition, an object, or a global variable.
  void _globalDeclaration() {
    final line = _cur.line;
    if (_readType() == null) return; // unreachable: the caller checked

    // `void setup() {` versus `DHT dht2(2, DHT11);` — the body decides.
    if (_cur.kind == _Kind.word && _peek(1).text == '(') {
      final close = _matchingParen(i + 1);
      if (close >= 0 && toks[close + 1].text == '{') {
        final name = _cur.text;
        final nameLine = _cur.line;
        _advance(); // name
        _skipParens(); // parameters
        if (name == 'setup' || name == 'loop') {
          sawSection = true;
          (name == 'setup' ? setup : loop).addAll(_body());
        } else {
          _panic(nameLine, 'unknownFunction', name);
          _skipBlock();
        }
        return;
      }
      // An object built from arguments, like the LCD.
      _advance(); // name
      _skipParens();
      _skipStatement();
      return;
    }

    if (_cur.kind != _Kind.word) {
      _panic(line, 'badName', _cur.text);
      _recover();
      return;
    }
    final name = _cur.text;
    _advance();
    if (_eat('=')) {
      final value = _expr();
      if (value == null) {
        _recover();
        return;
      }
      if (!_eat(';')) {
        _panic(line, 'expectedToken', ';');
        _recover();
        return;
      }
      // A global with an initial value runs once, before setup.
      setup.add(
          Block(kind: BlockKind.setVar, params: {'name': name, 'value': value}));
      return;
    }
    // `float x;`, `Servo servo9;` — a declaration carries no behaviour, so it
    // maps to no block at all.
    _skipStatement();
  }

  String? _readType() {
    final t = _cur;
    if (t.kind != _Kind.word || !_types.contains(t.text)) return null;
    _advance();
    return t.text;
  }

  // ------------------------------------------------------------ statements

  List<Block> _body() {
    final out = <Block>[];
    if (!_eat('{')) {
      _panic(_cur.line, 'expectedToken', '{');
      _recover();
      return out;
    }
    while (!_eof && !_at('}')) {
      out.addAll(_statement());
    }
    if (!_eat('}')) _panic(_cur.line, 'unterminated');
    return out;
  }

  List<Block> _statement() {
    if (_cur.kind == _Kind.word) {
      switch (_cur.text) {
        case 'if':
          return _ifBlock() ?? const [];
        case 'for':
          return _forBlock() ?? const [];
        case 'while':
          return _whileBlock() ?? const [];
        default:
          if (_types.contains(_cur.text)) return _declaration();
      }
    }
    return _simpleStatement();
  }

  /// Tries every single-statement form; the first one that recognises the
  /// tokens wins, and what none of them recognises is an error.
  List<Block> _simpleStatement() {
    final result = _try(_ultrasonic) ??
        _try(_sensorRead) ??
        _try(_servoAttach) ??
        _try(_servoWrite) ??
        _try(_display) ??
        _try(_serial) ??
        _try(_knownCall) ??
        _try(_assignment);
    if (result != null) return result;
    final line = _cur.line;
    _panic(line, 'unknownStatement', _cur.text);
    _advance();
    _recover();
    return const [];
  }

  List<Block> _declaration() {
    final line = _cur.line;
    _readType();
    if (_cur.kind != _Kind.word) {
      _panic(line, 'badName', _cur.text);
      _advance();
      _recover();
      return const [];
    }
    final name = _cur.text;
    _advance();
    if (_eat('=')) {
      final value = _expr();
      if (value == null) {
        _recover();
        return const [];
      }
      if (!_eat(';')) {
        _panic(line, 'expectedToken', ';');
        _recover();
        return const [];
      }
      return [
        Block(kind: BlockKind.setVar, params: {'name': name, 'value': value})
      ];
    }
    _skipStatement();
    return const [];
  }

  List<Block>? _ifBlock() {
    if (!_at('if')) return null;
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'badCondition');
      _recover();
      return const [];
    }
    final condition = _expr();
    if (condition == null) {
      _recover();
      return const [];
    }
    if (!_eat(')')) {
      _panic(line, 'badCondition');
      _recover();
      return const [];
    }
    final body = _body();
    if (_eat('else')) {
      return [
        Block(
          kind: BlockKind.ifElse,
          params: {'condition': condition},
          body: body,
          elseBody: _body(),
        )
      ];
    }
    return [
      Block(kind: BlockKind.ifDo, params: {'condition': condition}, body: body)
    ];
  }

  /// `for (int i = 0; i < n; i++) { ... }`, plus the endless `for (;;)`.
  List<Block>? _forBlock() {
    if (!_at('for')) return null;
    final line = _cur.line;
    _advance();
    if (!_eat('(')) return _badFor(line);
    if (_eat(';') && _eat(';')) {
      if (!_eat(')')) return _badFor(line);
      return [
        Block(kind: BlockKind.forever, body: _body())
      ];
    }
    if (!_eat('int') || _cur.kind != _Kind.word) return _badFor(line);
    final counter = _cur.text;
    _advance();
    if (!_eat('=') || !_eat('0') || !_eat(';')) return _badFor(line);
    if (!_eat(counter) || !_eat('<')) return _badFor(line);
    final times = _expr();
    if (times == null) return _badFor(line);
    if (times.kind != ValueKind.number) return _badFor(line);
    if (!_eat(';') || !_eat(counter) || !_eat('++') || !_eat(')')) {
      return _badFor(line);
    }
    return [
      Block(
          kind: BlockKind.repeatTimes,
          params: {'times': times.number},
          body: _body())
    ];
  }

  List<Block> _badFor(int line) {
    _panic(line, 'badFor');
    _skipRestOfParens();
    if (_at('{')) {
      _skipBlock();
    } else {
      _recover();
    }
    return const [];
  }

  /// `while (true) { ... }` — the only loop a `forever` block can mean.
  List<Block>? _whileBlock() {
    if (!_at('while')) return null;
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'badWhile');
      _recover();
      return const [];
    }
    final endless = _eat('true') || _eat('1');
    if (!endless || !_eat(')')) {
      _panic(line, 'badWhile');
      _skipRestOfParens();
      if (_at('{')) {
        _skipBlock();
      } else {
        _recover();
      }
      return const [];
    }
    return [
      Block(kind: BlockKind.forever, body: _body())
    ];
  }

  // -------------------------------------------------------------- sensors

  /// The six statements an ultrasonic measurement is written as. Every one of
  /// them is also a block on its own, so the whole shape has to line up before
  /// any of it is claimed.
  List<Block>? _ultrasonic() {
    final mark = i;
    final depth = errors.length;
    List<Block>? undo() {
      i = mark;
      errors.removeRange(depth, errors.length);
      return null;
    }

    final trig = _digitalWritePin('LOW');
    if (trig == null) return undo();
    if (!_delayMicroseconds(2)) return undo();
    if (_digitalWritePin('HIGH') != trig) return undo();
    if (!_delayMicroseconds(10)) return undo();
    if (_digitalWritePin('LOW') != trig) return undo();
    if (_cur.kind != _Kind.word || _peek(1).text != '=') return undo();
    final name = _cur.text;
    _advance(); // name
    _advance(); // =
    if (!_eat('pulseIn') || !_eat('(')) return undo();
    final echo = _plainPin();
    if (echo == null) return undo();
    if (!_eat(',') || !_eat('HIGH') || !_eat(')')) return undo();
    if (!_eat('/')) return undo();
    if (_cur.kind != _Kind.number || _number(_cur) != 58) return undo();
    _advance();
    if (!_eat(';')) return undo();
    return [
      Block(
        kind: BlockKind.readUltrasonic,
        params: {'name': name, 'trig': trig, 'echo': echo},
      )
    ];
  }

  /// `digitalWrite(<pin>, <value>);`, or null when this is something else.
  int? _digitalWritePin(String value) {
    final mark = i;
    if (!_eat('digitalWrite') || !_eat('(')) {
      i = mark;
      return null;
    }
    final pin = _plainPin();
    if (pin == null ||
        !_eat(',') ||
        !_eat(value) ||
        !_eat(')') ||
        !_eat(';')) {
      i = mark;
      return null;
    }
    return pin;
  }

  bool _delayMicroseconds(int want) {
    final mark = i;
    if (!_eat('delayMicroseconds') || !_eat('(')) {
      i = mark;
      return false;
    }
    if (_cur.kind != _Kind.number || _number(_cur) != want) {
      i = mark;
      return false;
    }
    _advance();
    if (!_eat(')') || !_eat(';')) {
      i = mark;
      return false;
    }
    return true;
  }

  /// `<name> = dht<pin>.readTemperature();`
  List<Block>? _sensorRead() {
    final t = _cur;
    if (t.kind != _Kind.word || _peek(1).text != '=') return null;
    final object = _peek(2);
    if (object.kind != _Kind.word || _peek(3).text != '.') return null;
    final pin = _numberedObject(object.text, 'dht');
    if (pin == null) return null;
    final method = _peek(4).text;
    final kind = method == 'readTemperature'
        ? BlockKind.readTemperature
        : method == 'readHumidity'
            ? BlockKind.readHumidity
            : null;
    if (kind == null) return null;
    _advance(); // name
    _advance(); // =
    _advance(); // object
    _advance(); // .
    _advance(); // method
    if (!_eat('(') || !_eat(')') || !_eat(';')) {
      _panic(t.line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(kind: kind, params: {'name': t.text, 'pin': pin})
    ];
  }

  // ----------------------------------------------------------- components

  /// `servo9.attach(9);` — the wiring a servo needs, with no block of its own
  /// because the pin already says which servo this is.
  List<Block>? _servoAttach() {
    final t = _cur;
    if (t.kind != _Kind.word ||
        _peek(1).text != '.' ||
        _peek(2).text != 'attach') {
      return null;
    }
    if (_numberedObject(t.text, 'servo') == null) return null;
    _advance();
    _advance();
    _advance();
    _skipParens();
    _skipStatement();
    return const [];
  }

  /// `servo9.write(<angle>);`
  List<Block>? _servoWrite() {
    final t = _cur;
    if (t.kind != _Kind.word ||
        _peek(1).text != '.' ||
        _peek(2).text != 'write') {
      return null;
    }
    final pin = _numberedObject(t.text, 'servo');
    if (pin == null) return null;
    final line = t.line;
    _advance();
    _advance();
    _advance();
    final angle = _singleArgument(line);
    if (angle == null) return const [];
    return [
      Block(kind: BlockKind.servoWrite, params: {'pin': pin, 'angle': angle})
    ];
  }

  /// The four `lcd` calls.
  List<Block>? _display() {
    if (!_at('lcd') || _peek(1).text != '.') return null;
    final line = _cur.line;
    final method = _peek(2);
    _advance(); // lcd
    _advance(); // .
    if (method.kind != _Kind.word) {
      _panic(line, 'unexpectedToken', method.text);
      _recover();
      return const [];
    }
    _advance(); // method
    switch (method.text) {
      case 'init':
      case 'clear':
        if (!_eat('(') || !_eat(')') || !_eat(';')) {
          _panic(line, 'expectedToken', ';');
          _recover();
          return const [];
        }
        return [
          Block(
              kind: method.text == 'init'
                  ? BlockKind.lcdInit
                  : BlockKind.lcdClear)
        ];
      case 'setCursor':
        if (!_eat('(')) {
          _panic(line, 'expectedToken', '(');
          _recover();
          return const [];
        }
        final col = _expr();
        if (col == null) {
          _recover();
          return const [];
        }
        if (!_eat(',')) {
          _panic(line, 'expectedToken', ',');
          _recover();
          return const [];
        }
        final row = _expr();
        if (row == null) {
          _recover();
          return const [];
        }
        if (!_eat(')') || !_eat(';')) {
          _panic(line, 'expectedToken', ';');
          _recover();
          return const [];
        }
        return [
          Block(kind: BlockKind.lcdSetCursor, params: {'col': col, 'row': row})
        ];
      case 'print':
        final value = _singleArgument(line);
        if (value == null) return const [];
        return [
          Block(kind: BlockKind.lcdPrint, params: {'value': value})
        ];
      default:
        _panic(line, 'unknownStatement', 'lcd.${method.text}');
        _recover();
        return const [];
    }
  }

  /// `Serial.begin/print/println`.
  List<Block>? _serial() {
    if (!_at('Serial') || _peek(1).text != '.') return null;
    final line = _cur.line;
    final method = _peek(2);
    _advance(); // Serial
    _advance(); // .
    if (method.kind != _Kind.word) {
      _panic(line, 'unexpectedToken', method.text);
      _recover();
      return const [];
    }
    _advance(); // method
    switch (method.text) {
      case 'begin':
        final baud = _singleArgument(line);
        if (baud == null) return const [];
        if (baud.kind != ValueKind.number) {
          _panic(line, 'badValue', _spell(baud));
          return const [];
        }
        return [
          Block(kind: BlockKind.serialBegin, params: {'baud': baud.number})
        ];
      case 'print':
      case 'println':
        final value = _singleArgument(line);
        if (value == null) return const [];
        return [
          Block(
            kind: method.text == 'print'
                ? BlockKind.serialPrint
                : BlockKind.serialPrintln,
            params: {'value': value},
          )
        ];
      default:
        _panic(line, 'unknownStatement', 'Serial.${method.text}');
        _recover();
        return const [];
    }
  }

  // ------------------------------------------------------------- pin calls

  List<Block>? _knownCall() {
    final t = _cur;
    if (t.kind != _Kind.word) return null;
    switch (t.text) {
      case 'delay':
        return _delay();
      case 'pinMode':
        return _pinMode();
      case 'digitalWrite':
        return _digitalWrite();
      case 'analogWrite':
        return _pinAndValue(BlockKind.analogWrite);
      case 'tone':
        return _pinAndValue(BlockKind.tone);
      case 'noTone':
        return _noTone();
      default:
        return null;
    }
  }

  List<Block> _delay() {
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return const [];
    }
    final value = _expr();
    if (value == null) {
      _recover();
      return const [];
    }
    if (value.kind != ValueKind.number) {
      _panic(line, 'badDelay', _spell(value));
      _recover();
      return const [];
    }
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(kind: BlockKind.wait, params: {'ms': value.number})
    ];
  }

  List<Block> _pinMode() {
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return const [];
    }
    final pin = _pin();
    if (pin == null) return _bail();
    if (!_eat(',')) {
      _panic(line, 'expectedToken', ',');
      _recover();
      return const [];
    }
    final mode = _cur;
    if (mode.kind != _Kind.word || !_modes.contains(mode.text)) {
      _panic(mode.line, 'badValue', mode.text);
      _recover();
      return const [];
    }
    _advance();
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(kind: BlockKind.setPinMode, params: {'pin': pin, 'mode': mode.text})
    ];
  }

  List<Block> _digitalWrite() {
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return const [];
    }
    final pin = _pin();
    if (pin == null) return _bail();
    if (!_eat(',')) {
      _panic(line, 'expectedToken', ',');
      _recover();
      return const [];
    }
    final value = _cur;
    final level = value.text.toUpperCase();
    if (value.kind != _Kind.word || (level != 'HIGH' && level != 'LOW')) {
      _panic(value.line, 'badValue', value.text);
      _recover();
      return const [];
    }
    _advance();
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(kind: BlockKind.digitalWrite, params: {'pin': pin, 'value': level})
    ];
  }

  /// `analogWrite(pin, value);` and `tone(pin, frequency);`.
  List<Block> _pinAndValue(BlockKind kind) {
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return const [];
    }
    final pin = _pin();
    if (pin == null) return _bail();
    if (!_eat(',')) {
      _panic(line, 'expectedToken', ',');
      _recover();
      return const [];
    }
    final value = _expr();
    if (value == null) {
      _recover();
      return const [];
    }
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(
        kind: kind,
        params: kind == BlockKind.tone
            ? {'pin': pin, 'frequency': value}
            : {'pin': pin, 'value': value},
      )
    ];
  }

  List<Block> _noTone() {
    final line = _cur.line;
    _advance();
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return const [];
    }
    final pin = _pin();
    if (pin == null) return _bail();
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return [
      Block(kind: BlockKind.noTone, params: {'pin': pin})
    ];
  }

  List<Block> _bail() {
    _recover();
    return const [];
  }

  // ---------------------------------------------------------- assignments

  /// `<name> = <expr>;` and `<name> += <expr>;`.
  List<Block>? _assignment() {
    final t = _cur;
    if (t.kind != _Kind.word) return null;
    final op = _peek(1).text;
    final isSet = op == '=';
    final isChange = _assignOps.contains(op);
    if (!isSet && !isChange) return null;
    _advance(); // name
    _advance(); // operator
    final value = _expr();
    if (value == null) {
      _recover();
      return const [];
    }
    if (!_eat(';')) {
      _panic(t.line, 'expectedToken', ';');
      _recover();
      return const [];
    }
    return isSet
        ? [
            Block(
                kind: BlockKind.setVar,
                params: {'name': t.text, 'value': value})
          ]
        : [
            Block(
                kind: BlockKind.changeVar,
                params: {'name': t.text, 'op': op, 'value': value})
          ];
  }

  // ---------------------------------------------------------- expressions

  Value? _expr() => _or();

  Value? _or() => _binary(_and, const ['||']);
  Value? _and() => _binary(_equality, const ['&&']);
  Value? _equality() => _binary(_relational, const ['==', '!=']);
  Value? _relational() => _binary(_additive, const ['<', '>', '<=', '>=']);
  Value? _additive() => _binary(_multiplicative, const ['+', '-']);
  Value? _multiplicative() => _binary(_unary, const ['*', '/', '%']);

  Value? _binary(Value? Function() next, List<String> ops) {
    final first = next();
    if (first == null) return null;
    var left = first;
    while (ops.contains(_cur.text)) {
      final line = _cur.line;
      final op = _cur.text;
      _advance();
      final right = next();
      if (right == null) {
        _panic(line, 'badExpression', op);
        return null;
      }
      left = Value.binary(op, left, right);
    }
    return left;
  }

  Value? _unary() {
    if (!_at('-')) return _primary();
    final line = _cur.line;
    _advance();
    final value = _unary();
    if (value == null) {
      _panic(line, 'badExpression', '-');
      return null;
    }
    // A literal keeps its sign; anything else becomes `0 - x`, which is the
    // spelling the printer gives it back.
    return value.kind == ValueKind.number
        ? Value.num(-value.number)
        : Value.binary('-', Value.zero, value);
  }

  Value? _primary() {
    final t = _cur;
    switch (t.kind) {
      case _Kind.number:
        _advance();
        return Value.num(_number(t));
      case _Kind.string:
        _advance();
        return Value.text(t.text);
      case _Kind.word:
        _advance();
        if (_at('(')) {
          final args = _arguments();
          if (args == null) return null;
          if (!_callable.contains(t.text)) {
            _panic(t.line, 'unknownFunction', t.text);
            return null;
          }
          return Value.call(t.text, args);
        }
        if (t.text == 'HIGH' || t.text == 'true') return Value.num(1);
        if (t.text == 'LOW' || t.text == 'false') return Value.num(0);
        if (_pinLabel.hasMatch(t.text)) {
          final pin = BoardPins.fromLabel(t.text);
          if (pin != null) return Value.num(pin.toDouble());
        }
        return Value.varRef(t.text);
      case _Kind.punct:
        if (t.text != '(') {
          _panic(t.line, 'badExpression', t.text);
          return null;
        }
        _advance();
        final value = _expr();
        if (value == null) return null;
        if (!_eat(')')) {
          _panic(t.line, 'expectedToken', ')');
          return null;
        }
        return value;
      case _Kind.directive:
      case _Kind.eof:
        _panic(t.line, 'unterminated');
        return null;
    }
  }

  List<Value>? _arguments() {
    final line = _cur.line;
    if (!_eat('(')) return null;
    final args = <Value>[];
    if (_eat(')')) return args;
    while (true) {
      final value = _expr();
      if (value == null) return null;
      args.add(value);
      if (_eat(',')) continue;
      if (_eat(')')) return args;
      _panic(line, 'expectedToken', ')');
      return null;
    }
  }

  /// Reads `(<expr>) ;` — the tail every single-argument call shares.
  Value? _singleArgument(int line) {
    if (!_eat('(')) {
      _panic(line, 'expectedToken', '(');
      _recover();
      return null;
    }
    final value = _expr();
    if (value == null) {
      _recover();
      return null;
    }
    if (!_eat(')') || !_eat(';')) {
      _panic(line, 'expectedToken', ';');
      _recover();
      return null;
    }
    return value;
  }

  // ------------------------------------------------------------------ pins

  /// A pin written as a number or a board label.
  int? _pin() {
    final t = _cur;
    if (t.kind == _Kind.number) {
      _advance();
      return _number(t).toInt();
    }
    if (t.kind == _Kind.word && _pinLabel.hasMatch(t.text)) {
      final pin = BoardPins.fromLabel(t.text);
      if (pin != null) {
        _advance();
        return pin;
      }
    }
    _panic(t.line, 'badPin', t.text);
    return null;
  }

  /// The same, but silent: used while probing whether a shape matches at all.
  int? _plainPin() {
    final t = _cur;
    if (t.kind == _Kind.number) {
      _advance();
      return _number(t).toInt();
    }
    if (t.kind == _Kind.word && _pinLabel.hasMatch(t.text)) {
      final pin = BoardPins.fromLabel(t.text);
      if (pin != null) {
        _advance();
        return pin;
      }
    }
    return null;
  }

  /// The trailing number of an object named after the pin it sits on, such as
  /// `servo9` or `dht2`.
  static int? _numberedObject(String word, String prefix) {
    if (!word.startsWith(prefix)) return null;
    final digits = word.substring(prefix.length);
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  static double _number(_Tok t) {
    if (t.text.startsWith('0x') || t.text.startsWith('0X')) {
      return int.parse(t.text.substring(2), radix: 16).toDouble();
    }
    return double.parse(t.text);
  }

  static String _spell(Value v) {
    switch (v.kind) {
      case ValueKind.number:
        return v.number.toString();
      case ValueKind.text:
        return '"${v.name}"';
      case ValueKind.variable:
        return v.name;
      case ValueKind.call:
        return '${v.name}(…)';
      case ValueKind.binary:
        return '${_spell(v.args[0])} ${v.name} ${_spell(v.args[1])}';
    }
  }
}
