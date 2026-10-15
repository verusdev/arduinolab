import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'canvas/canvas_view.dart';
import 'widgets/block_editor.dart';
import 'widgets/code_preview.dart';
import 'widgets/examples_dialog.dart';
import 'widgets/palette.dart';
import 'widgets/properties_panel.dart';
import 'widgets/serial_monitor.dart';

/// Root screen. Adapts between a three-pane desktop layout and a stacked
/// mobile layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  AppState? _app;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppChanged);
      _app = app..addListener(_onAppChanged);
    }
  }

  void _onTabChanged() => setState(() {});

  void _onAppChanged() {
    final msg = _app?.message;
    if (msg == null || msg == _lastMessage) return;
    _lastMessage = msg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ));
    });
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _app?.removeListener(_onAppChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      appBar: _appBar(context, app, wide),
      drawer: wide ? null : const Drawer(child: SafeArea(child: Palette())),
      body: wide ? _wideBody() : _narrowBody(),
    );
  }

  // ------------------------------------------------------------------- app bar

  PreferredSizeWidget _appBar(BuildContext context, AppState app, bool wide) {
    return AppBar(
      titleSpacing: wide ? 16 : 0,
      title: Row(
        children: [
          if (!wide)
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Components',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          const Icon(Icons.developer_board, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              app.project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        if (wide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: _runButton(app)),
          )
        else
          _runButton(app),
        IconButton(
          tooltip: 'Reset simulation',
          icon: const Icon(Icons.restart_alt),
          onPressed: app.resetSimulation,
        ),
        if (wide)
          IconButton(
            tooltip: 'Examples & lessons',
            icon: const Icon(Icons.school_outlined),
            onPressed: () => showExamplesDialog(context),
          ),
        PopupMenuButton<String>(
          tooltip: 'Project',
          icon: const Icon(Icons.more_vert),
          onSelected: (v) => _onMenu(v, app),
          itemBuilder: (ctx) => [
            if (!wide)
              const PopupMenuItem(
                  value: 'examples', child: Text('Examples & lessons')),
            const PopupMenuItem(value: 'rename', child: Text('Rename project')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'save', child: Text('Save to slot...')),
            const PopupMenuItem(value: 'open', child: Text('Open slot…')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'export', child: Text('Export JSON…')),
            const PopupMenuItem(value: 'import', child: Text('Import JSON…')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'new', child: Text('New project')),
          ],
        ),
      ],
    );
  }

  Widget _runButton(AppState app) {
    final running = app.running;
    final enabled = running || app.canRun;
    return Tooltip(
      message: running ? 'Stop' : 'Run',
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: running ? const Color(0xFFC62828) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: !enabled ? null : () => running ? app.stop() : app.run(),
        icon: Icon(running ? Icons.stop : Icons.play_arrow, size: 18),
        label: Text(running ? 'Stop' : 'Run'),
      ),
    );
  }

  void _onMenu(String value, AppState app) {
    switch (value) {
      case 'examples':
        showExamplesDialog(context);
        break;
      case 'rename':
        _showRenameDialog(app);
        break;
      case 'save':
        _showSaveDialog(app);
        break;
      case 'open':
        _showOpenDialog(app);
        break;
      case 'export':
        _showExportDialog(app);
        break;
      case 'import':
        _showImportDialog(app);
        break;
      case 'new':
        _confirmNew(app);
        break;
    }
  }

  // --------------------------------------------------------------------- body

  Widget _wideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: 232,
          child: Material(color: Colors.white, child: Palette()),
        ),
        const VerticalDivider(width: 1),
        const Expanded(child: CanvasView()),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 440,
          child: Material(color: Colors.white, child: _sidePanel()),
        ),
      ],
    );
  }

  Widget _narrowBody() {
    return Column(
      children: [
        const Expanded(child: CanvasView()),
        const Divider(height: 1),
        SizedBox(
          height: 320,
          child: Material(color: Colors.white, child: _sidePanel()),
        ),
      ],
    );
  }

  Widget _sidePanel() {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Blocks', icon: Icon(Icons.extension, size: 18)),
            Tab(text: 'Sketch', icon: Icon(Icons.code, size: 18)),
            Tab(text: 'Serial', icon: Icon(Icons.terminal, size: 18)),
            Tab(text: 'Inspector', icon: Icon(Icons.tune, size: 18)),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              BlockEditor(),
              CodePreview(),
              SerialMonitor(),
              PropertiesPanel(),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ dialogs

  Future<void> _showRenameDialog(AppState app) async {
    final controller = TextEditingController(text: app.project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      app.renameProject(name.trim());
    }
  }

  Future<void> _confirmNew(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New project?'),
        content:
            const Text('Unsaved changes to the current project will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Start new')),
        ],
      ),
    );
    if (ok == true) app.newProject();
  }

  Future<void> _showSaveDialog(AppState app) async {
    final slots = await app.storage.slots();
    if (!mounted) return;
    final controller = TextEditingController(text: app.project.name);
    final slot = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Save project',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Slot name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (slots.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Saved slots', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final s in slots)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder_open, size: 18),
                              title: Text(s),
                              onTap: () => Navigator.of(ctx).pop(s),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(controller.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (slot != null && slot.trim().isNotEmpty) {
      await app.saveToSlot(slot.trim());
    }
  }

  Future<void> _showOpenDialog(AppState app) async {
    final slots = await app.storage.slots();
    if (!mounted) return;
    final slot = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open project'),
        content: SizedBox(
          width: 380,
          child: slots.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No saved projects yet.',
                      style: TextStyle(color: Colors.black54)),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final s in slots)
                          ListTile(
                            leading: const Icon(Icons.folder_open),
                            title: Text(s),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                await app.storage.delete(s);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                _showOpenDialog(app);
                              },
                            ),
                            onTap: () => Navigator.of(ctx).pop(s),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
    if (slot != null) await app.openFromSlot(slot);
  }

  Future<void> _showExportDialog(AppState app) async {
    final json = app.exportJson();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Project JSON'),
        content: SizedBox(
          width: 620,
          height: 400,
          child: Container(
            color: const Color(0xFFF3F5F7),
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: SelectableText(json,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.of(ctx).pop();
            },
            child: const Text('Copy'),
          ),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(AppState app) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import project JSON'),
        content: SizedBox(
          width: 620,
          height: 400,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste exported JSON here',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Clipboard.getData(Clipboard.kTextPlain).then((data) {
                final text = data?.text;
                if (text != null && text.isNotEmpty) {
                  controller.text = text;
                }
              });
            },
            child: const Text('Paste'),
          ),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import')),
        ],
      ),
    );
    if (submitted == true) app.importJson(controller.text);
  }
}
