/// A language the interface can be shown in.
///
/// The [code] is what gets persisted in shared preferences, so it must stay
/// stable; [name] is what the language picker shows, written in the language
/// itself so it is readable no matter which one is active.
enum AppLang {
  ru('ru', 'Русский'),
  en('en', 'English');

  const AppLang(this.code, this.name);

  final String code;
  final String name;

  static AppLang fromCode(String? code) {
    for (final lang in values) {
      if (lang.code == code) return lang;
    }
    return ru;
  }
}
