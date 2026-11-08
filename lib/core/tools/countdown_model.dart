import 'dart:convert';

/// One saved exam / last date.
class CountdownItem {
  final String id;
  final String title;
  final DateTime date; // date only (time is ignored)

  const CountdownItem({required this.id, required this.title, required this.date});

  /// Whole days from [today] until the date (negative = already passed).
  int daysLeft(DateTime today) {
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(date.year, date.month, date.day);
    return DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      };

  static CountdownItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final date = raw['date'];
    if (id is! String || title is! String || date is! String) return null;
    final d = DateTime.tryParse(date);
    if (d == null || title.trim().isEmpty) return null;
    return CountdownItem(id: id, title: title, date: DateTime(d.year, d.month, d.day));
  }
}

const int kMaxCountdowns = 50;

String encodeCountdowns(List<CountdownItem> items) =>
    jsonEncode([for (final i in items) i.toMap()]);

List<CountdownItem> decodeCountdowns(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return [];
    final out = <CountdownItem>[];
    for (final e in data) {
      final i = CountdownItem.fromMap(e);
      if (i != null) out.add(i);
      if (out.length >= kMaxCountdowns) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

/// Upcoming first (nearest date on top), finished ones last.
List<CountdownItem> sortCountdowns(List<CountdownItem> items, DateTime today) {
  final up = items.where((i) => i.daysLeft(today) >= 0).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final past = items.where((i) => i.daysLeft(today) < 0).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return [...up, ...past];
}
