import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/app_lang.dart';
import '../../i18n/locale_controller.dart';
import '../../i18n/strings.dart';

/// App bar control that switches the interface language. The choice is
/// persisted by [LocaleController] and applied to the whole tree at once.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    return PopupMenuButton<AppLang>(
      tooltip: S.t('bar.language'),
      onSelected: locale.set,
      itemBuilder: (ctx) => [
        for (final lang in AppLang.values)
          CheckedPopupMenuItem<AppLang>(
            value: lang,
            checked: lang == locale.lang,
            child: Text(lang.name),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 20),
            const SizedBox(width: 4),
            Text(
              locale.lang.code.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
