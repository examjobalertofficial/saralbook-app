import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Holds user preferences (theme + language) and saves them on the phone.
/// Later phases also sync these to the cloud for signed-in users.
class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs, this._themeMode, this._languageCode);

  static const String _kTheme = 'settings.themeMode';
  static const String _kLanguage = 'settings.languageCode';
  static const String defaultLanguage = 'en';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  String _languageCode;

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    final stored = prefs.getString(_kLanguage);
    final supported =
        AppStrings.supportedLocales.any((l) => l.languageCode == stored);
    return SettingsController._(
      prefs,
      theme,
      supported ? stored! : defaultLanguage,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setLanguage(String code) async {
    final supported =
        AppStrings.supportedLocales.any((l) => l.languageCode == code);
    if (!supported || code == _languageCode) return;
    _languageCode = code;
    notifyListeners();
    await _prefs.setString(_kLanguage, code);
  }
}

/// Gives every screen access to the settings: `SettingsScope.of(context)`.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing above this widget');
    return scope!.notifier!;
  }
}
