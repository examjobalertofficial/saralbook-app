import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// The preferences that follow a signed-in person to any phone.
class PrefsSnapshot {
  final ThemeMode themeMode;
  final String language;
  final List<String> hiddenSections;
  final List<String> sectionOrder;

  const PrefsSnapshot({
    required this.themeMode,
    required this.language,
    required this.hiddenSections,
    required this.sectionOrder,
  });

  Map<String, Object?> toMap() => {
        'themeMode': themeMode.name,
        'language': language,
        'homeHidden': hiddenSections,
        'homeOrder': sectionOrder,
      };

  /// Returns null if [value] is missing or damaged (never throws).
  static PrefsSnapshot? fromMap(Object? value) {
    if (value is! Map) return null;
    final theme = ThemeMode.values.where((m) => m.name == value['themeMode']);
    final lang = value['language'];
    final supported =
        AppStrings.supportedLocales.any((l) => l.languageCode == lang);
    List<String> strings(Object? v) => v is List
        ? [for (final e in v) if (e is String && e.length <= 60) e].take(40).toList()
        : const <String>[];
    if (theme.isEmpty || !supported) return null;
    return PrefsSnapshot(
      themeMode: theme.first,
      language: lang as String,
      hiddenSections: strings(value['homeHidden']),
      sectionOrder: strings(value['homeOrder']),
    );
  }
}
