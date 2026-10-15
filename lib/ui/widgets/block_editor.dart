import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../blocks/block_catalog.dart';
import '../../blocks/block_model.dart';
import '../../i18n/strings.dart';
import '../../models/pin.dart';
import '../../state/app_state.dart';

Color _categoryColor(String category) {
  switch (category) {
    case 'Control':
      return const Color(0xFF5C6BC0);
    case 'Pins':
      return const Color(0xFF00897B);
    case 'Variables':
      return const Color(0xFFEF6C00);
    case 'Serial':
      return const Color(0xFF546E7A);
    case 'Components':
      return const Color(0xFF7E57C2);
    case 'Sensors':
      return const Color(0xFF43A047);
    case 'Display':
      return const Color(0xFF0097A7);
    default:
      return const Color(0xFF455A64);
  }
}

/// Compact white-on-dark input decoration used by the block parameter fields.
InputDecoration _fieldDecoration() => const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      border: OutlineInputBorder(),
      enabledBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
      focusedBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
    );

/// The visual block programming editor.
class BlockEditor extends StatelessWidget {
  const BlockEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final blocks = app.activeSection == BlockSection.setup
        ? app.project.program.setup
        : app.project.program.loop;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Row(
            children: [
              SegmentedButton<BlockSection>(
                segments: [
                  ButtonSegment(
                      value: BlockSection.setup,
                      label: Text(S.t('block.setup'))),
                  ButtonSegment(
                      value: BlockSection.loop, label: Text(S.t('block.loop'))),
                ],
                selected: {app.activeSection},
                onSelectionChanged: (s) => app.setSection(s.first),
              ),
              const Spacer(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: blocks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.t('block.empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  children: [
                    for (final block in blocks)
                      _BlockCard(block: block, depth: 0),
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddBlockSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(S.t('block.addBlock')),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showAddBlockSheet(
  BuildContext context, {
  String? parentId,
  bool intoElse = false,
}) {
  final app = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => DefaultTabController(
      length: BlockCatalog.categories.length,
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                for (final c in BlockCatalog.categories)
                  Tab(text: S.t('blockcat.$c')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final c in BlockCatalog.categories)
                    ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final def in BlockCatalog.inCategory(c))
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.add_circle,
                                  color: _categoryColor(c)),
                              title: Text(S.t('blk.${def.kind.name}')),
                              onTap: () {
                                app.addBlock(def.kind,
                                    parentId: parentId, intoElse: intoElse);
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block, required this.depth});

  final Block block;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final def = BlockCatalog.def(block.kind);
    final selected = app.selectedBlockId == block.id;
    final color = _categoryColor(def.category);

    return Container(
      margin: EdgeInsets.only(left: depth * 10.0, bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? const Color(0xFFFFD54F) : Colors.transparent,
            width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(S.t('blk.${def.kind.name}'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              _miniIcon(Icons.arrow_upward, S.t('block.moveUp'),
                  () => app.moveBlock(block.id, -1)),
              _miniIcon(Icons.arrow_downward, S.t('block.moveDown'),
                  () => app.moveBlock(block.id, 1)),
              _miniIcon(Icons.close, S.t('block.delete'),
                  () => app.deleteBlock(block.id)),
            ],
          ),
          if (def.params.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final p in def.params) _ParamField(block: block, def: p),
                ],
              ),
            ),
          if (def.hasBody) _BodySection(block: block, isElse: false),
          if (def.hasElse) _BodySection(block: block, isElse: true),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, String tip, VoidCallback onTap) => IconButton(
        tooltip: tip,
        icon: Icon(icon, size: 16, color: Colors.white),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      );
}

class _BodySection extends StatelessWidget {
  const _BodySection({required this.block, required this.isElse});

  final Block block;
  final bool isElse;

  @override
  Widget build(BuildContext context) {
    final children = isElse ? block.elseBody : block.body;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isElse ? S.t('block.else') : S.t('block.do'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _showAddBlockSheet(context,
                    parentId: block.id, intoElse: isElse),
                icon: const Icon(Icons.add, size: 14),
                label: Text(S.t('block.add'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(S.t('block.emptyBody'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          for (final child in children) _BlockCard(block: child, depth: 0),
          if (children.isNotEmpty) const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _ParamField extends StatelessWidget {
  const _ParamField({required this.block, required this.def});

  final Block block;
  final ParamDef def;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    void update(Object? value) =>
        app.updateBlockParam(block.id, def.key, value);

    final Widget editor;
    switch (def.editor) {
      case ParamEditor.number:
        editor = _NumberField(
          value: (block.params[def.key] as num?)?.toDouble() ?? 0,
          onChanged: (v) => update(v),
        );
        break;
      case ParamEditor.value:
        editor =
            ValueEditor(value: block.valueParam(def.key), onChanged: update);
        break;
      case ParamEditor.pin:
        editor = _PinDropdown(
            value: block.intParam(def.key, def.defaultValue as int),
            onChanged: update);
        break;
      case ParamEditor.condition:
        editor = ConditionEditor(
            value: block.valueParam(def.key), onChanged: update);
        break;
      case ParamEditor.varName:
        editor = _SyncTextField(
          value: block.stringParam(def.key),
          onChanged: update,
          width: 84,
        );
        break;
      case ParamEditor.mode:
      case ParamEditor.digitalValue:
      case ParamEditor.op:
      case ParamEditor.dropdown:
        editor = _StringDropdown(
          value: block.stringParam(def.key, def.defaultValue as String),
          options: def.options,
          onChanged: update,
        );
        break;
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        if (def.label.isNotEmpty)
          Text(S.t('par.${def.label}'),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        editor,
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    final text = _fmt(widget.value);
    if (text != _controller.text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ],
        onChanged: (t) => widget.onChanged(double.tryParse(t) ?? 0),
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: _fieldDecoration(),
      ),
    );
  }
}

class _SyncTextField extends StatefulWidget {
  const _SyncTextField({
    required this.value,
    required this.onChanged,
    this.width = 84,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  State<_SyncTextField> createState() => _SyncTextFieldState();
}

class _SyncTextFieldState extends State<_SyncTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SyncTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: _fieldDecoration(),
      ),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = options.contains(value) || value.isEmpty
        ? options
        : [value, ...options];
    final current = items.contains(value) ? value : items.first;
    return _DropdownShell(
      child: DropdownButton<String>(
        value: current,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF12313B),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        iconEnabledColor: Colors.white,
        items: [
          for (final o in items)
            DropdownMenuItem(
                value: o, child: Text(o, style: const TextStyle(fontSize: 12))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _PinDropdown extends StatelessWidget {
  const _PinDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static final List<int> _pins = [
    for (var i = 0; i <= 13; i++) i,
    for (var i = 0; i <= 5; i++) BoardPins.analogBase + i,
  ];

  @override
  Widget build(BuildContext context) {
    final pins = _pins.contains(value) ? _pins : [value, ..._pins];
    return _DropdownShell(
      child: DropdownButton<int>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF12313B),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        iconEnabledColor: Colors.white,
        items: [
          for (final p in pins)
            DropdownMenuItem(
                value: p,
                child: Text(BoardPins.label(p),
                    style: const TextStyle(fontSize: 12))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// Editor for a [Value] expression (number / variable / text / sensor call).
class ValueEditor extends StatefulWidget {
  const ValueEditor({super.key, required this.value, required this.onChanged});

  final Value value;
  final ValueChanged<Value> onChanged;

  @override
  State<ValueEditor> createState() => _ValueEditorState();
}

class _ValueEditorState extends State<ValueEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: _display(widget.value));

  static const List<String> _kinds = [
    'number',
    'variable',
    'text',
    'analogRead',
    'digitalRead',
    'millis',
  ];

  static String _display(Value v) {
    switch (v.kind) {
      case ValueKind.number:
        return v.number == v.number.roundToDouble()
            ? v.number.toInt().toString()
            : v.number.toString();
      case ValueKind.variable:
      case ValueKind.text:
        return v.name;
      default:
        return '';
    }
  }

  String get _option {
    final v = widget.value;
    if (v.kind == ValueKind.call && _kinds.contains(v.name)) return v.name;
    switch (v.kind) {
      case ValueKind.number:
        return 'number';
      case ValueKind.variable:
        return 'variable';
      case ValueKind.text:
        return 'text';
      default:
        return 'number';
    }
  }

  @override
  void didUpdateWidget(covariant ValueEditor old) {
    super.didUpdateWidget(old);
    final text = _display(widget.value);
    if (text != _controller.text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pinOf {
    final args = widget.value.args;
    if (args.isNotEmpty && args.first.kind == ValueKind.number) {
      return args.first.number.toInt();
    }
    return widget.value.name == 'digitalRead' ? 2 : 14;
  }

  void _changeKind(String option) {
    switch (option) {
      case 'number':
        widget.onChanged(Value.num(double.tryParse(_controller.text) ?? 0));
        break;
      case 'variable':
        widget.onChanged(Value.varRef(_controller.text));
        break;
      case 'text':
        widget.onChanged(Value.text(_controller.text));
        break;
      case 'analogRead':
        widget.onChanged(Value.call('analogRead', [Value.num(14)]));
        break;
      case 'digitalRead':
        widget.onChanged(Value.call('digitalRead', [Value.num(2)]));
        break;
      case 'millis':
        widget.onChanged(Value.call('millis'));
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final option = _option;
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DropdownShell(
          child: DropdownButton<String>(
            value: option,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF12313B),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            iconEnabledColor: Colors.white,
            items: [
              for (final k in _kinds)
                DropdownMenuItem(
                    value: k,
                    child: Text(S.t('val.$k'),
                        style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v != null) _changeKind(v);
            },
          ),
        ),
        if (option == 'number' || option == 'variable' || option == 'text')
          SizedBox(
            width: option == 'text' ? 116 : 62,
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: _fieldDecoration(),
              onChanged: (t) {
                switch (option) {
                  case 'number':
                    widget.onChanged(Value.num(double.tryParse(t) ?? 0));
                    break;
                  case 'variable':
                    widget.onChanged(Value.varRef(t));
                    break;
                  case 'text':
                    widget.onChanged(Value.text(t));
                    break;
                }
              },
            ),
          ),
        if (option == 'analogRead' || option == 'digitalRead')
          _PinDropdown(
            value: _pinOf,
            onChanged: (p) =>
                widget.onChanged(Value.call(option, [Value.num(p.toDouble())])),
          ),
      ],
    );
  }
}

/// Editor for a comparison/boolean condition.
class ConditionEditor extends StatelessWidget {
  const ConditionEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Value value;
  final ValueChanged<Value> onChanged;

  static const List<String> _ops = [
    '<',
    '>',
    '<=',
    '>=',
    '==',
    '!=',
    '&&',
    '||',
  ];

  @override
  Widget build(BuildContext context) {
    final isBinary = value.kind == ValueKind.binary;
    final op = isBinary ? value.name : '<';
    final a = isBinary ? value.args[0] : Value.num(0);
    final b = isBinary && value.args.length > 1 ? value.args[1] : Value.num(0);
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ValueEditor(value: a, onChanged: (v) => _fire(op, v, b)),
        _DropdownShell(
          child: DropdownButton<String>(
            value: _ops.contains(op) ? op : '<',
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF12313B),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            iconEnabledColor: Colors.white,
            items: [
              for (final o in _ops)
                DropdownMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v != null) _fire(v, a, b);
            },
          ),
        ),
        ValueEditor(value: b, onChanged: (v) => _fire(op, a, v)),
      ],
    );
  }

  void _fire(String op, Value a, Value b) => onChanged(Value.binary(op, a, b));
}
