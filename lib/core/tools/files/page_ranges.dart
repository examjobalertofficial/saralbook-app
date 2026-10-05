/// Parses page selections like `1-3, 5, 8-` into groups of 1-based page numbers.
/// Each comma/semicolon separated item is one group (used to split a PDF into
/// several files). Returns null when the text is not valid for [pageCount].
///
/// Accepted items: `5`, `2-4`, `7-` (to the end), `-3` (from the start), `all`.
List<List<int>>? parsePageGroups(String input, int pageCount) {
  if (pageCount < 1) return null;
  final items = input
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();
  if (items.isEmpty || items.length > 500) return null;

  final groups = <List<int>>[];
  for (final item in items) {
    int from;
    int to;
    if (item == 'all') {
      from = 1;
      to = pageCount;
    } else if (item.contains('-')) {
      final parts = item.split('-');
      if (parts.length != 2) return null;
      final a = parts[0].trim();
      final b = parts[1].trim();
      if (a.isEmpty && b.isEmpty) return null;
      from = a.isEmpty ? 1 : (int.tryParse(a) ?? -1);
      to = b.isEmpty ? pageCount : (int.tryParse(b) ?? -1);
    } else {
      final n = int.tryParse(item);
      if (n == null) return null;
      from = n;
      to = n;
    }
    if (from < 1 || to > pageCount || from > to) return null;
    groups.add([for (var p = from; p <= to; p++) p]);
  }
  return groups;
}

/// All selected pages in order (duplicates allowed), or null if invalid.
List<int>? parsePageList(String input, int pageCount) {
  final groups = parsePageGroups(input, pageCount);
  if (groups == null) return null;
  return [for (final g in groups) ...g];
}
