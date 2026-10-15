import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../blocks/sketch_completions.dart';
import '../../blocks/sketch_parser.dart';
import '../../i18n/strings.dart';
import '../../state/app_state.dart';

/// The sketch, editable.
///
/// Typing here is parsed as it goes: code the blocks can express replaces them,
/// code they cannot is left alone and reported. The blocks keep writing the
/// sketch too, so an edit made there lands in the text a moment later.
class SketchEditor extends StatefulWidget {
  const SketchEditor({super.key});

  @override
  State<SketchEditor> createState() => _SketchEditorState();
}

/// Same font and metrics as the text field, so the caret can be measured and
/// the autocomplete popup placed under it.
const TextStyle _code = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: Color(0xFF213547),
  height: 1.35,
);

class _SketchEditorState extends State<SketchEditor> {
  final _controller = _CodeController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  AppState? _app;

  /// Set while this widget is the one changing the text, so the rebuild that
  /// follows does not overwrite the user's caret.
  bool _typing = false;

  List<Suggestion> _suggestions = const [];
  int _selected = 0;
  int _wordStart = 0;
  int _wordEnd = 0;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>()..addListener(_onAppChanged);
    _controller.text = _app!.sketchText;
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppChanged);
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The blocks changed: the text follows them.
  void _onAppChanged() {
    if (!mounted || _typing) return;
    _pushText(_app!.sketchText);
    setState(() {});
  }

  void _pushText(String text) {
    if (_controller.text == text) return;
    final caret = _controller.selection.baseOffset.clamp(0, text.length);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  /// Hands the whole text to the state, which turns it into blocks or explains
  /// why it cannot.
  void _commit(String text) {
    _typing = true;
    try {
      _app!.updateSketch(text);
    } finally {
      _typing = false;
    }
  }

  void _onChanged(String text) {
    if (_typing) return;
    _commit(text);
    _offerSuggestions(text, _controller.selection.baseOffset);
    setState(() {});
  }

  // --------------------------------------------------------- autocomplete

  void _offerSuggestions(String text, int caret) {
    if (caret < 0) {
      _closeSuggestions();
      return;
    }
    final word = SketchCompletions.wordBefore(text, caret);
    if (word.isEmpty) {
      _closeSuggestions();
      return;
    }
    final hits = SketchCompletions.forPrefix(
      word,
      variables: SketchCompletions.variablesIn(text),
    );
    if (hits.isEmpty) {
      _closeSuggestions();
      return;
    }
    _suggestions = hits;
    _selected = 0;
    _wordStart = caret - word.length;
    _wordEnd = caret;
  }

  void _closeSuggestions() {
    _suggestions = const [];
    _selected = 0;
  }

  void _move(int delta) {
    if (_suggestions.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % _suggestions.length;
      if (_selected < 0) _selected += _suggestions.length;
    });
  }

  /// Replaces the word under the caret with [suggestion], or with the selected
  /// one when the popup was clicked at.
  void _accept([Suggestion? suggestion]) {
    final choice = suggestion ??
        (_suggestions.isEmpty ? null : _suggestions[_selected]);
    if (choice == null) return;
    final text = _controller.text
        .replaceRange(_wordStart, _wordEnd, choice.insert);
    final caret = _wordStart + choice.insert.length;
    _typing = true;
    try {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
      );
      _app!.updateSketch(text);
    } finally {
      _typing = false;
    }
    setState(_closeSuggestions);
  }

  /// Tab completes; with the popup closed it indents instead.
  void _onTab() {
    if (_suggestions.isNotEmpty) {
      _accept();
      return;
    }
    final selection = _controller.selection;
    if (!selection.isValid) return;
    final text =
        _controller.text.replaceRange(selection.start, selection.end, '  ');
    _typing = true;
    try {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection.start + 2),
      );
      _app!.updateSketch(text);
    } finally {
      _typing = false;
    }
    setState(() {});
  }

  /// Where the caret sits inside the text area, in the text area's own
  /// coordinates. Null until the field has been laid out.
  Offset? _caretAnchor(double textWidth) {
    final text = _controller.text;
    final caret = _controller.selection.baseOffset;
    if (caret < 0 || caret > text.length) return null;
    final painter = TextPainter(
      text: TextSpan(text: text, style: _code),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    final position =
        painter.getOffsetForCaret(TextPosition(offset: caret), Rect.zero);
    final scrolled = _scroll.hasClients ? _scroll.offset : 0.0;
    return Offset(
      position.dx,
      position.dy - scrolled + painter.preferredLineHeight,
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final errors = app.sketchErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(app),
        if (errors.isNotEmpty) _errorBanner(app, errors),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: const Color(0xFFF7F8FA),
            child: _editor(),
          ),
        ),
      ],
    );
  }

  Widget _header(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.code, size: 18),
          const SizedBox(width: 8),
          Text(S.t('sketch.title'), style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (app.sketchAhead)
            IconButton(
              tooltip: S.t('sketch.rebuild'),
              icon: const Icon(Icons.restore, size: 18),
              onPressed: app.rebuildSketch,
            ),
          IconButton(
            tooltip: S.t('sketch.copy'),
            icon: const Icon(Icons.copy_all, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: app.sketchText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.t('sketch.copied'))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(AppState app, List<SketchError> errors) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFDECEA),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline,
                size: 16, color: Color(0xFFB3261E)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.t('sketch.errors', {'count': errors.length}),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8C1D18)),
                    ),
                    for (final error in errors.take(4))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _describe(error),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8C1D18)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: app.rebuildSketch,
            child: Text(S.t('sketch.rebuild'),
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// The parser reports codes, never wording, so the translation is looked up
  /// here — the one place that knows how to say things to a user.
  String _describe(SketchError error) {
    final line = S.t('sketch.line', {'line': error.line});
    final key = 'parse.${error.code}';
    final reason = S.t(key);
    return error.detail == null
        ? '$line · $reason'
        : '$line · $reason (${error.detail})';
  }

  Widget _editor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 10.0;
        final anchor = _caretAnchor(constraints.maxWidth - padding * 2);
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: _field(),
              ),
            ),
            if (_suggestions.isNotEmpty && anchor != null)
              _popup(anchor + const Offset(padding, padding), constraints),
          ],
        );
      },
    );
  }

  Widget _field() {
    final open = _suggestions.isNotEmpty;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.tab): const _CompleteIntent(),
        if (open) ...<ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _NextIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _PrevIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const _DismissIntent(),
        },
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CompleteIntent: CallbackAction<_CompleteIntent>(
            onInvoke: (_) {
              _onTab();
              return null;
            },
          ),
          if (open) ...<Type, Action<Intent>>{
            _NextIntent: CallbackAction<_NextIntent>(
              onInvoke: (_) {
                _move(1);
                return null;
              },
            ),
            _PrevIntent: CallbackAction<_PrevIntent>(
              onInvoke: (_) {
                _move(-1);
                return null;
              },
            ),
            _DismissIntent: CallbackAction<_DismissIntent>(
              onInvoke: (_) {
                setState(_closeSuggestions);
                return null;
              },
            ),
          },
        },
        child: TextField(
          key: const ValueKey('sketch.editor'),
          controller: _controller,
          scrollController: _scroll,
          focusNode: _focus,
          expands: true,
          maxLines: null,
          onChanged: _onChanged,
          style: _code,
          cursorWidth: 2,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: S.t('sketch.hint'),
          ),
        ),
      ),
    );
  }

  Widget _popup(Offset at, BoxConstraints bounds) {
    const height = 190.0;
    const width = 260.0;
    final fits = at.dy + height < bounds.maxHeight;
    return Positioned(
      left: at.dx.clamp(0.0, (bounds.maxWidth - width).clamp(0.0, width)),
      top: fits ? at.dy : (at.dy - height - 18).clamp(0.0, double.infinity),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: height),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return InkWell(
                onTap: () => _accept(suggestion),
                child: Container(
                  color: index == _selected
                      ? const Color(0xFFE3EEFB)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          suggestion.label,
                          overflow: TextOverflow.ellipsis,
                          style: _code.copyWith(
                              color: _colorFor(suggestion.kind)),
                        ),
                      ),
                      if (suggestion.detail.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          suggestion.detail,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Tab, while the popup is open, takes the highlighted suggestion.
class _CompleteIntent extends Intent {
  const _CompleteIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

Color _colorFor(SuggestionKind kind) {
  switch (kind) {
    case SuggestionKind.keyword:
      return const Color(0xFF0B5394);
    case SuggestionKind.type:
      return const Color(0xFF0F766E);
    case SuggestionKind.constant:
      return const Color(0xFF9333EA);
    case SuggestionKind.function:
      return const Color(0xFF7C3AED);
    case SuggestionKind.object:
      return const Color(0xFFB45309);
    case SuggestionKind.pin:
      return const Color(0xFFC2410C);
    case SuggestionKind.variable:
      return const Color(0xFF213547);
  }
}

/// Paints the sketch with the colours of a code editor.
///
/// Only the text inside the field is re-styled: what the controller holds is
/// untouched, so the parser still sees plain C++.
class _CodeController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <TextSpan>[];
    var end = 0;
    for (final match in _token.allMatches(text)) {
      if (match.start > end) {
        spans.add(TextSpan(text: text.substring(end, match.start)));
      }
      final token = match.group(0)!;
      spans.add(TextSpan(text: token, style: _styleFor(token)));
      end = match.end;
    }
    if (end < text.length) spans.add(TextSpan(text: text.substring(end)));
    return TextSpan(style: style, children: spans);
  }

  static TextStyle? _styleFor(String token) {
    final first = token.codeUnitAt(0);
    if (token.startsWith('//') || token.startsWith('/*')) {
      return const TextStyle(color: Color(0xFF8A94A6));
    }
    if (token.startsWith('#')) return const TextStyle(color: Color(0xFF9333EA));
    if (first == 0x22) return const TextStyle(color: Color(0xFF166534));
    if (first >= 0x30 && first <= 0x39) {
      return const TextStyle(color: Color(0xFFB45309));
    }
    if (_types.contains(token)) return const TextStyle(color: Color(0xFF0F766E));
    if (_constants.contains(token)) {
      return const TextStyle(color: Color(0xFF9333EA));
    }
    if (_keywords.contains(token)) {
      return const TextStyle(
          color: Color(0xFF0B5394), fontWeight: FontWeight.w600);
    }
    if (_pin.hasMatch(token)) return const TextStyle(color: Color(0xFFC2410C));
    return null;
  }

  static final RegExp _token = RegExp(
    r'//[^\n]*'
    r'|/\*[\s\S]*?\*/'
    r'|"(?:\\.|[^"\\])*"'
    r'|#[^\n]*'
    r'|[A-Za-z_]\w*'
    r'|\d+(?:\.\d+)?'
    r'|\s+'
    r'|.',
  );

  static final RegExp _pin = RegExp(r'^[DA]\d{1,2}$', caseSensitive: false);

  static const Set<String> _types = {
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

  static const Set<String> _constants = {
    'HIGH',
    'LOW',
    'OUTPUT',
    'INPUT',
    'INPUT_PULLUP',
    'true',
    'false',
  };

  static const Set<String> _keywords = {
    'if',
    'else',
    'for',
    'while',
    'return',
    'break',
    'continue',
    'setup',
    'loop',
  };
}
