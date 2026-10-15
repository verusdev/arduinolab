import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lang.dart';
import 'strings.dart';

/// Owns the interface language and remembers the choice between runs.
///
/// The catalogue itself ([S]) is a plain global so that data files and painters
/// — which have no `BuildContext` — can read it too. This controller is what
/// makes widgets *react* to a change: it flips [S] and notifies, and the app
/// rebuilds its whole tree so every label is re-read.
class LocaleController extends ChangeNotifier {
  static const String _key = 'arduino_lab:lang';

  AppLang _lang = AppLang.ru;

  AppLang get lang => _lang;

  /// Applies the remembered language, if one was stored. Safe to call when
  /// storage is unavailable (tests, first run): the default stays in place.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = AppLang.fromCode(prefs.getString(_key));
      if (!prefs.containsKey(_key) || stored == _lang) return;
      _lang = stored;
      S.set(_lang);
      notifyListeners();
    } catch (_) {
      // No storage (headless tests): keep whatever language is already set.
    }
  }

  Future<void> set(AppLang lang) async {
    if (lang == _lang) return;
    _lang = lang;
    S.set(_lang);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang.code);
    } catch (_) {
      // Nothing to persist to; the choice still holds for this session.
    }
  }
}
