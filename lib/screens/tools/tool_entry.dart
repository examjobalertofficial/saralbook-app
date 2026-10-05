import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/tools/calc_model.dart';

/// One tile in the Tools tab.
class ToolEntry {
  final String id;
  final LText title;
  final LText description;
  final IconData icon;
  final ToolCategory category;
  final List<String> keywords;
  final WidgetBuilder builder;

  const ToolEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.builder,
    this.keywords = const [],
  });

  /// Matches the search text against titles (both languages) and keywords.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.of('en').toLowerCase().contains(q) ||
        title.of('hi').toLowerCase().contains(q) ||
        description.of('en').toLowerCase().contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}
