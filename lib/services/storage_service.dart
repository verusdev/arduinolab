import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// Persists projects as JSON using shared preferences (works on every
/// platform without native file dialogs).
class StorageService {
  static const String _prefix = 'arduino_lab:project:';
  static const String _slotsKey = 'arduino_lab:slots';

  Future<List<String>> slots() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_slotsKey) ?? const [];
  }

  Future<void> save(String slot, Project project) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$slot', jsonEncode(project.toJson()));
    final list = (prefs.getStringList(_slotsKey) ?? const <String>[]).toList();
    if (!list.contains(slot)) {
      list.add(slot);
      await prefs.setStringList(_slotsKey, list);
    }
  }

  Future<Project?> load(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$slot');
    if (raw == null) return null;
    return decode(raw);
  }

  Future<void> delete(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$slot');
    final list = (prefs.getStringList(_slotsKey) ?? const <String>[]).toList()
      ..remove(slot);
    await prefs.setStringList(_slotsKey, list);
  }

  /// Serialises a project to a pretty JSON string (for export).
  String encode(Project project) =>
      const JsonEncoder.withIndent('  ').convert(project.toJson());

  /// Parses a project from a JSON string (for import).
  Project decode(String raw) {
    final map = (jsonDecode(raw) as Map).cast<String, Object?>();
    return Project.fromJson(map);
  }
}
