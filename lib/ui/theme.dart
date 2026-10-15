import 'package:flutter/material.dart';

/// Arduino-inspired theme (teal accents on a light workspace).
ThemeData labTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00979D),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF1F4F7),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF0B3C49),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    visualDensity: VisualDensity.compact,
  );
}

/// Colour used for the workspace grid.
const Color kGridColor = Color(0xFFD9E1E8);
const Color kWorkspaceColor = Color(0xFFFBFCFD);
