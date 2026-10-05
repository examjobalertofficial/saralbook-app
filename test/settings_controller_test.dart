import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: system theme, English', () async {
    final s = await SettingsController.load();
    expect(s.themeMode, ThemeMode.system);
    expect(s.languageCode, 'en');
  });

  test('theme and language are saved and restored', () async {
    final s = await SettingsController.load();
    await s.setThemeMode(ThemeMode.dark);
    await s.setLanguage('hi');

    final reloaded = await SettingsController.load();
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.languageCode, 'hi');
  });

  test('unsupported language is ignored', () async {
    final s = await SettingsController.load();
    await s.setLanguage('xx');
    expect(s.languageCode, 'en');
  });

  test('corrupt stored values fall back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': 'purple',
      'settings.languageCode': 'zz',
    });
    final s = await SettingsController.load();
    expect(s.themeMode, ThemeMode.system);
    expect(s.languageCode, 'en');
  });
}
