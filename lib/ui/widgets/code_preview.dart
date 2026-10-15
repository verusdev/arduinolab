import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../blocks/sketch_printer.dart';
import '../../i18n/strings.dart';
import '../../state/app_state.dart';

/// Read-only view of the Arduino C++ sketch generated from the blocks.
class CodePreview extends StatelessWidget {
  const CodePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = SketchPrinter.print(app.project.program);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.code, size: 18),
              const SizedBox(width: 8),
              Text(S.t('sketch.title'),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: S.t('sketch.copy'),
                icon: const Icon(Icons.copy_all, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.t('sketch.copied'))),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF213547),
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
