import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_services.dart';
import '../core/feed/feed_repository.dart';
import '../core/jobs/job_categories.dart';
import '../core/jobs/job_tabs.dart';
import '../core/l10n/ltext.dart';
import '../core/router/app_router.dart';
import '../widgets/page_body.dart';
import '../widgets/post_list.dart';
import '../widgets/tr.dart';
import 'tools/tool_catalog.dart';
import 'tools/tool_style.dart';

class _S {
  static final hint = t('Search jobs, results, tools…', 'नौकरी, रिज़ल्ट, टूल खोजें…');
  static final tipStart = t(
    'Type a word, for example "SSC", "admit card", "PDF" or "calculator".',
    'कोई शब्द लिखें, जैसे "SSC", "admit card", "PDF" या "calculator"।',
  );
  static final shortcuts = t('Jobs shortcuts', 'नौकरी शॉर्टकट');
  static final toolsTitle = t('Tools', 'टूल्स');
  static final postsTitle = t('Jobs and updates', 'नौकरी और अपडेट');
  static final searching = t('Searching…', 'खोज रहे हैं…');
  static final nothing = t('Nothing found. Try another word.', 'कुछ नहीं मिला। दूसरा शब्द आज़माएं।');
  static final needNet = t(
    'Jobs and updates need the internet. Tools are searched on your phone.',
    'नौकरी और अपडेट के लिए इंटरनेट चाहिए। टूल्स आपके फ़ोन पर खोजे जाते हैं।',
  );
  static final clear = t('Clear', 'साफ़ करें');
}

/// Search the whole app: tools and Jobs shortcuts on the phone, and posts of
/// our two websites (only in the job categories) through the websites' own
/// search. Free, no other service.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SiteHits {
  final JobSite site;
  final List<FeedItem> items;
  const _SiteHits(this.site, this.items);
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  List<_SiteHits> _hits = const [];
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    final q = value.trim();
    setState(() {
      _query = q;
      _hits = const [];
      _failed = false;
    });
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() => _loading = false);
      _seq++;
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _searchPosts(q));
  }

  Future<void> _searchPosts(String q) async {
    final seq = ++_seq;
    final feeds = AppScope.of(context).feeds;
    final cats = JobCategories(feeds);
    final hits = <_SiteHits>[];
    var failures = 0;
    await Future.wait([
      for (final site in jobSites)
        () async {
          try {
            final base = '${site.base}/wp-json/wp/v2/posts?per_page=12&search=${Uri.encodeQueryComponent(q)}';
            final url = await cats.scoped(base, 'all');
            if (url == null) throw const FeedFailure(offline: false);
            final items = await feeds.fetchOnce(url);
            if (items.isNotEmpty) hits.add(_SiteHits(site, items));
          } catch (_) {
            failures++;
          }
        }(),
    ]);
    if (!mounted || seq != _seq) return;
    // keep ExamJobAlert first, then SaralBook
    hits.sort((a, b) => jobSites.indexOf(a.site).compareTo(jobSites.indexOf(b.site)));
    setState(() {
      _hits = hits;
      _failed = failures == jobSites.length;
      _loading = false;
    });
  }

  List<ToolEntry> get _toolHits => _query.length < 2
      ? const []
      : [
          for (final e in toolCatalog)
            if (e.matches(_query)) e,
        ].take(8).toList();

  List<JobTab> get _tabHits {
    if (_query.length < 2) return const [];
    final q = _query.toLowerCase();
    return [
      for (final tab in jobTabs)
        if (tab.title.of('en').toLowerCase().contains(q) || tab.title.of('hi').contains(_query)) tab,
    ];
  }

  void _openTab(JobTab tab) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('${AppRoutes.jobs}?tab=${tab.id}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tools = _toolHits;
    final tabs = _tabHits;
    final nothing = _query.length >= 2 && !_loading && tools.isEmpty && tabs.isEmpty && _hits.isEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          decoration: InputDecoration(
            hintText: tr(context, _S.hint),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: tr(context, _S.clear),
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _changed('');
              },
            ),
        ],
      ),
      body: PageBody(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_query.length < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.search_rounded, size: 52, color: scheme.outline),
                    const SizedBox(height: 10),
                    Text(tr(context, _S.tipStart), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            if (tabs.isNotEmpty) ...[
              _heading(context, _S.shortcuts),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tab in tabs)
                    ActionChip(
                      avatar: Icon(tab.icon, size: 18, color: tab.color),
                      label: Text(tr(context, tab.title)),
                      onPressed: () => _openTab(tab),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (tools.isNotEmpty) ...[
              _heading(context, _S.toolsTitle),
              for (final tool in tools) _toolTile(context, tool),
              const SizedBox(height: 12),
            ],
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 10),
                    Text(tr(context, _S.searching)),
                  ],
                ),
              ),
            for (final hit in _hits) ...[
              _heading(context, t(hit.site.name, hit.site.name)),
              PostList(items: hit.items, animate: false),
              const SizedBox(height: 8),
            ],
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, _S.needNet), style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            if (nothing && !_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(tr(context, _S.nothing), style: TextStyle(color: scheme.onSurfaceVariant))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, LText text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(tr(context, text), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _toolTile(BuildContext context, ToolEntry tool) {
    final accent = toolAccent(tool.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: accent.withAlpha(36),
        child: Icon(tool.icon, color: accent),
      ),
      title: Text(tr(context, tool.title), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(tr(context, tool.description), maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: tool.builder),
      ),
    );
  }
}
