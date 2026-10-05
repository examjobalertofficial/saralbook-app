import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../../config/endpoints.dart';
import '../cache/cache_store.dart';
import '../security/safe_url.dart';

class FeedItem {
  final String id;
  final String title;
  final String link;
  final DateTime? date;
  const FeedItem({
    required this.id,
    required this.title,
    required this.link,
    this.date,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get dateLabel {
    final d = date;
    if (d == null) return '';
    final day = d.day.toString().padLeft(2, '0');
    return '$day ${_months[d.month - 1]} ${d.year}';
  }
}

class FeedResult {
  final List<FeedItem> items;

  /// true when the network failed and an older saved copy is shown.
  final bool fromSavedCopy;
  const FeedResult(this.items, {this.fromSavedCopy = false});
}

class FeedFailure implements Exception {
  final bool offline;
  const FeedFailure({required this.offline});
}

/// Removes HTML tags and decodes the entities WordPress puts in titles.
String decodeHtml(String input) {
  var s = input.replaceAll(RegExp(r'<[^>]*>'), '');
  String fromCode(int code) =>
      (code > 0 && code <= 0x10FFFF) ? String.fromCharCode(code) : '';
  s = s.replaceAllMapped(
    RegExp(r'&#(\d{1,7});'),
    (m) => fromCode(int.parse(m[1]!)),
  );
  s = s.replaceAllMapped(
    RegExp(r'&#[xX]([0-9a-fA-F]{1,6});'),
    (m) => fromCode(int.parse(m[1]!, radix: 16)),
  );
  const named = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&hellip;': '…',
    '&ndash;': '–',
    '&mdash;': '—',
    '&lsquo;': '‘',
    '&rsquo;': '’',
    '&ldquo;': '“',
    '&rdquo;': '”',
  };
  named.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll('&amp;', '&').trim();
}

/// Reads a standard WordPress `wp/v2/posts` response. Bad rows are skipped.
List<FeedItem> parseFeed(String body) {
  final json = jsonDecode(body);
  if (json is! List) throw const FormatException('Feed is not a list');
  final items = <FeedItem>[];
  for (final row in json) {
    if (row is! Map<String, dynamic>) continue;
    final titleRaw = row['title'];
    final title = decodeHtml(
      titleRaw is Map ? '${titleRaw['rendered'] ?? ''}' : '${titleRaw ?? ''}',
    );
    final link = row['link'];
    if (title.isEmpty || link is! String || !SafeUrl.isAllowed(link)) continue;
    final dateRaw = row['date'];
    items.add(FeedItem(
      id: '${row['id'] ?? link}',
      title: title,
      link: link,
      date: dateRaw is String ? DateTime.tryParse(dateRaw) : null,
    ));
  }
  return items;
}

/// Downloads feeds with a safety net:
///  * fresh saved copy (< 30 min) is used without any network call
///  * if the network fails, a saved copy up to 24 h old is shown and marked
///  * anything older is never shown, so users do not see outdated news
class FeedRepository {
  FeedRepository(
    this._cache, {
    http.Client? client,
    Future<bool> Function()? isOnline,
  })  : _client = client ?? http.Client(),
        _isOnline = isOnline ?? _defaultIsOnline;

  static const Duration freshFor = Duration(minutes: 30);
  static const Duration staleLimit = Duration(hours: 24);

  final CacheStore _cache;
  final http.Client _client;
  final Future<bool> Function() _isOnline;

  static Future<bool> _defaultIsOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static String normalizeUrl(String url) {
    final uri = Uri.parse(url);
    final q = Map<String, String>.of(uri.queryParameters);
    q.putIfAbsent('_fields', () => 'id,title,link,date');
    final perPage = int.tryParse(q['per_page'] ?? '') ?? 6;
    q['per_page'] = perPage.clamp(1, 20).toString();
    return uri.replace(queryParameters: q).toString();
  }

  Future<FeedResult> load(String url, {bool force = false}) async {
    if (!SafeUrl.isAllowed(url)) {
      throw const FeedFailure(offline: false);
    }
    final key = 'feed:${normalizeUrl(url)}';

    if (!force) {
      final fresh = _cache.get(key, maxAge: freshFor);
      if (fresh != null) {
        try {
          return FeedResult(parseFeed(fresh));
        } catch (_) {/* fall through to network */}
      }
    }

    try {
      final response = await _client
          .get(Uri.parse(normalizeUrl(url)))
          .timeout(Endpoints.requestTimeout);
      if (response.statusCode != 200) {
        throw const FormatException('Bad status');
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final items = parseFeed(body);
      await _cache.put(key, body);
      return FeedResult(items);
    } catch (_) {
      final stale = _cache.get(key, maxAge: staleLimit);
      if (stale != null) {
        try {
          return FeedResult(parseFeed(stale), fromSavedCopy: true);
        } catch (_) {/* fall through */}
      }
      throw FeedFailure(offline: !await _isOnline());
    }
  }
}
