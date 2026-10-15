import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../examples/examples.dart';
import '../../i18n/strings.dart';
import '../../state/app_state.dart';

/// Shows the built-in library of examples and lessons.
Future<void> showExamplesDialog(BuildContext context) async {
  final app = context.read<AppState>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Color(0xFF00796B)),
                  const SizedBox(width: 10),
                  Text(S.t('examples.title'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: S.t('common.close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: Examples.all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final example = Examples.all[i];
                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.play_circle_outline,
                          color: Color(0xFF00796B)),
                      title: Text(S.t('lesson.${example.id}.title')),
                      subtitle: Text(S.t('lesson.${example.id}.summary'),
                          style: const TextStyle(fontSize: 12)),
                      children: [
                        for (var s = 0; s < example.steps.length; s++)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.check, size: 16),
                            title: Text(
                                S.t('lesson.${example.id}.s${s + 1}'),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.download),
                              label: Text(S.t('examples.load')),
                              onPressed: () {
                                app.loadExample(example.id);
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
