import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ArduinoLabApp());
}

class ArduinoLabApp extends StatelessWidget {
  const ArduinoLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Arduino Lab',
        debugShowCheckedModeBanner: false,
        theme: labTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
