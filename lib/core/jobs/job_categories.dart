import 'dart:convert';

import '../../config/endpoints.dart';
import '../feed/feed_repository.dart';

/// One of our two websites and the WordPress categories the app lists from it.
/// Only posts that are in one of these categories are shown, so a post you move
/// to "Uncategorised" (or any other category) disappears from the app.
class JobSite {
  final String id;
  final String name;
  final String base;

  /// Jobs-tab id -> category slug on this website.
  final Map<String, String> slugs;
  const JobSite(this.id, this.name, this.base, this.slugs);

  List<String> get allSlugs => slugs.values.toList();

  bool ownsUrl(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    final mine = Uri.parse(base).host;
    return host == mine || host.endsWith('.$mine');
  }

  /// The post list address the Jobs tab starts from (the app adds the category).
  String get postsUrl => '$base/wp-json/wp/v2/posts?per_page=100';
}

const List<JobSite> jobSites = [
  JobSite('examjobalert', 'ExamJobAlert', Endpoints.examJobAlertBase, {
    'latest': 'latest-jobs',
    'admit_card': 'admit-cards',
    'answer_key': 'answer-key',
    'result': 'results',
    'admission': 'admission',
  }),
  JobSite('saralbook', 'SaralBook', Endpoints.saralBookBase, {
    'latest': 'latest-jobs',
    'admit_card': 'admit-card',
    'answer_key': 'answer-key',
    'result': 'results',
    'admission': 'admission-form',
  }),
];

JobSite? jobSiteForUrl(String url) {
  for (final s in jobSites) {
    if (s.ownsUrl(url)) return s;
  }
  return null;
}

/// Turns "Admit Card on ExamJobAlert" into a WordPress address that returns
/// only the posts of that category, most recently edited first (a post you edit today rises to the top).
///
/// [tabId] `syllabus` or `all` means every one of the five categories.
class JobCategories {
  JobCategories(this._feeds);
  final FeedRepository _feeds;

  static String categoriesUrl(JobSite site) =>
      '${site.base}/wp-json/wp/v2/categories?per_page=100&_fields=id,slug&slug=${site.allSlugs.join(',')}';

  /// slug -> id from the categories answer. Bad rows are skipped.
  static Map<String, int> parseIds(String body) {
    final out = <String, int>{};
    try {
      final json = jsonDecode(body);
      if (json is! List) return out;
      for (final row in json) {
        if (row is! Map) continue;
        final id = row['id'];
        final slug = row['slug'];
        if (id is int && slug is String) out[slug] = id;
      }
    } catch (_) {/* empty */}
    return out;
  }

  /// The slugs a tab shows. Unknown tab ids show all five categories.
  static List<String> slugsFor(JobSite site, String tabId) {
    final one = site.slugs[tabId];
    return one != null ? [one] : site.allSlugs;
  }

  /// null when none of the tab's categories is known yet.
  static String? buildUrl(JobSite site, String tabId, Map<String, int> ids, {int perPage = 100, String? search}) {
    final wanted = <int>{
      for (final slug in slugsFor(site, tabId))
        if (ids[slug] != null) ids[slug]!,
    };
    if (wanted.isEmpty) return null;
    final list = wanted.toList()..sort();
    final searching = search != null && search.trim().isNotEmpty;
    final url = '${site.base}/wp-json/wp/v2/posts?per_page=${perPage.clamp(1, 100)}'
        '&orderby=${searching ? 'relevance' : 'modified'}&order=desc&categories=${list.join(',')}';
    return searching ? '$url&search=${Uri.encodeQueryComponent(search.trim())}' : url;
  }

  static bool _needsScope(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && !uri.queryParameters.containsKey('categories');
  }

  static String? _search(String url) => Uri.tryParse(url)?.queryParameters['search'];

  static int _perPage(String url) {
    final n = int.tryParse(Uri.tryParse(url)?.queryParameters['per_page'] ?? '');
    return n ?? 20;
  }

  /// Saved category ids (no network), for drawing the list at once.
  String? peekScoped(String url, String tabId) {
    final site = jobSiteForUrl(url);
    if (site == null || !_needsScope(url)) return url;
    final saved = _feeds.peekText(categoriesUrl(site));
    if (saved == null) return null;
    return buildUrl(site, tabId, parseIds(saved), perPage: _perPage(url), search: _search(url));
  }

  /// Same, but downloads the category ids when they are not saved yet.
  /// Addresses of other websites, or ones that already name a category, are
  /// returned unchanged. null = categories could not be found.
  Future<String?> scoped(String url, String tabId, {bool force = false}) async {
    final site = jobSiteForUrl(url);
    if (site == null || !_needsScope(url)) return url;
    final body = await _feeds.getText(
      categoriesUrl(site),
      maxAge: force ? Duration.zero : const Duration(days: 1),
    );
    if (body == null) return null;
    return buildUrl(site, tabId, parseIds(body), perPage: _perPage(url), search: _search(url));
  }
}
