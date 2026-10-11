import 'dart:async';

import 'package:http/http.dart' as http;

import '../../config/websites.dart';

/// Result of pinging one website.
class SiteStatus {
  final String id;
  final String name;
  final bool ok;

  /// HTTP status code, or null when the site did not answer at all.
  final int? code;
  final int ms;

  const SiteStatus({
    required this.id,
    required this.name,
    required this.ok,
    required this.code,
    required this.ms,
  });
}

/// Pings every website (all at once). Anything below HTTP 500 counts as "up".
/// Never throws; a site that does not answer is simply "down".
Future<List<SiteStatus>> checkSites(
  List<Website> sites, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final c = client ?? http.Client();
  try {
    return await Future.wait([
      for (final s in sites) _checkOne(c, s, timeout),
    ]);
  } finally {
    if (client == null) c.close();
  }
}

Future<SiteStatus> _checkOne(http.Client c, Website s, Duration timeout) async {
  final started = DateTime.now();
  int? code;
  try {
    final r = await c.head(Uri.parse(s.url)).timeout(timeout);
    code = r.statusCode;
  } catch (_) {
    code = null;
  }
  final ms = DateTime.now().difference(started).inMilliseconds;
  return SiteStatus(id: s.id, name: s.name, ok: code != null && code < 500, code: code, ms: ms);
}
