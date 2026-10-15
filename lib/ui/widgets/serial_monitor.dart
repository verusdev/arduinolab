import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.dart';
import '../../state/app_state.dart';

/// Serial monitor window.
class SerialMonitor extends StatefulWidget {
  const SerialMonitor({super.key});

  @override
  State<SerialMonitor> createState() => _SerialMonitorState();
}

class _SerialMonitorState extends State<SerialMonitor> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final text = app.engine.runtime.serial.join('\n');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              Text(S.t('serial.title'),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: S.t('serial.clear'),
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () {
                  app.engine.runtime.serial.clear();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: const Color(0xFF0F1B21),
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              controller: _controller,
              child: SelectableText(
                text.isEmpty ? S.t('serial.empty') : text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: Color(0xFF8BE9A8),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
