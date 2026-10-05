import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/l10n/app_strings.dart';

void main() {
  test('every English string has a Hindi translation and vice versa', () {
    final en = AppStrings.valuesFor('en').keys.toSet();
    final hi = AppStrings.valuesFor('hi').keys.toSet();
    expect(hi, en);
  });

  test('no translation is empty', () {
    for (final code in ['en', 'hi']) {
      for (final e in AppStrings.valuesFor(code).entries) {
        expect(e.value.trim(), isNotEmpty, reason: '$code/${e.key}');
      }
    }
  });

  test('Hindi differs from English where expected', () {
    expect(AppStrings(const Locale('en')).navHome, 'Home');
    expect(AppStrings(const Locale('hi')).navHome, 'होम');
  });

  test('unknown language falls back to English', () {
    expect(AppStrings(const Locale('fr')).navHome, 'Home');
  });
}
