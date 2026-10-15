import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'i18n/locale_controller.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve the saved language before the first frame, so the whole interface
  // (and the name of the starting project) comes up in the right language.
  final locale = LocaleController();
  await locale.load();
  runApp(ArduinoLabApp(locale: locale));
}

class ArduinoLabApp extends StatelessWidget {
  const ArduinoLabApp({super.key, this.locale});

  /// Supplied by [main]; tests may omit it and get a default controller.
  final LocaleController? locale;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: ChangeNotifierProvider<LocaleController>(
        create: (_) {
          final controller = locale ?? LocaleController();
          if (locale == null) controller.load();
          return controller;
        },
        child: Consumer<LocaleController>(
          builder: (context, controller, _) => KeyedSubtree(
            // Changing the key rebuilds the whole tree, so every label that was
            // resolved through S.t during a build is resolved again.
            key: ValueKey(controller.lang),
            child: MaterialApp(
              title: 'Arduino Lab',
              debugShowCheckedModeBanner: false,
              theme: labTheme(),
              home: const HomeScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
