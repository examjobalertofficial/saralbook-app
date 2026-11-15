import 'dart:convert';

/// When to ask for a Google Play rating: only after the person has really used
/// the app, never at the first start, and not more than twice.
class RatingState {
  final int opens;
  final List<String> days; // distinct days (yyyy-mm-dd) the app was opened, newest last
  final int asked;
  final int lastAskedMs;

  const RatingState({this.opens = 0, this.days = const [], this.asked = 0, this.lastAskedMs = 0});

  static const int minOpens = 8;
  static const int minDays = 4;
  static const int maxAsks = 2;
  static const Duration gap = Duration(days: 45);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// One more app start, today.
  RatingState opened(DateTime now) {
    final key = dayKey(now);
    final d = days.contains(key) ? days : [...days, key];
    return RatingState(
      opens: opens + 1,
      days: d.length > 30 ? d.sublist(d.length - 30) : d,
      asked: asked,
      lastAskedMs: lastAskedMs,
    );
  }

  bool shouldAsk(DateTime now) {
    if (asked >= maxAsks || opens < minOpens || days.length < minDays) return false;
    if (asked == 0) return true;
    return now.millisecondsSinceEpoch - lastAskedMs >= gap.inMilliseconds;
  }

  RatingState wasAsked(DateTime now) =>
      RatingState(opens: opens, days: days, asked: asked + 1, lastAskedMs: now.millisecondsSinceEpoch);

  String encode() => jsonEncode({'opens': opens, 'days': days, 'asked': asked, 'last': lastAskedMs});

  static RatingState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RatingState();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return const RatingState();
      final days = m['days'];
      return RatingState(
        opens: m['opens'] is int ? m['opens'] as int : 0,
        days: days is List ? [for (final d in days) if (d is String) d] : const [],
        asked: m['asked'] is int ? m['asked'] as int : 0,
        lastAskedMs: m['last'] is int ? m['last'] as int : 0,
      );
    } catch (_) {
      return const RatingState();
    }
  }
}
