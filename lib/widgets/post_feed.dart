import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/feed/feed_repository.dart';
import '../core/l10n/app_strings.dart';
import '../screens/home/section_header.dart';
import 'post_list.dart';
import 'skeleton.dart';

/// Loads and shows a list of posts. Fast: an already saved copy is drawn at
/// once and refreshed quietly behind it. Handles loading, empty, error,
/// offline and retry by itself.
class PostFeed extends StatefulWidget {
  /// One or more post-list addresses. Posts of all of them are merged,
  /// newest edit first, without doubles.
  final List<String> urls;

  /// Keeps only the posts it accepts (null = all).
  final bool Function(FeedItem item)? filter;
  final int refreshToken;
  final int maxItems;
  const PostFeed({
    super.key,
    required this.urls,
    this.filter,
    this.refreshToken = 0,
    this.maxItems = 60,
  });

  @override
  State<PostFeed> createState() => _PostFeedState();
}

/// Newest edit first, one entry per link.
List<FeedItem> mergePosts(Iterable<List<FeedItem>> lists) {
  final seen = <String>{};
  final all = <FeedItem>[];
  for (final list in lists) {
    for (final item in list) {
      if (seen.add(item.link)) all.add(item);
    }
  }
  DateTime stamp(FeedItem i) => i.modified ?? i.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  all.sort((a, b) => stamp(b).compareTo(stamp(a)));
  return all;
}

class _PostFeedState extends State<PostFeed> {
  FeedResult? _shown;
  Object? _error;
  bool _started = false;
  int _run = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(PostFeed old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final feeds = AppScope.of(context).feeds;
    final run = ++_run;
    if (!force && _shown == null) {
      final saved = [for (final u in widget.urls) feeds.peek(u)].whereType<FeedResult>().toList();
      if (saved.isNotEmpty) {
        setState(() => _shown = FeedResult(mergePosts(saved.map((r) => r.items))));
      }
    }
    final results = <FeedResult>[];
    Object? firstError;
    await Future.wait([
      for (final u in widget.urls)
        feeds.load(u, force: force).then<void>(results.add).catchError((Object e) {
          firstError ??= e;
        }),
    ]);
    if (!mounted || run != _run) return;
    setState(() {
      if (results.isEmpty) {
        _error = firstError ?? const FeedFailure(offline: false);
      } else {
        _shown = FeedResult(
          mergePosts(results.map((r) => r.items)),
          fromSavedCopy: results.any((r) => r.fromSavedCopy),
        );
        _error = null;
      }
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _shown = null;
    });
    _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final shown = _shown;
    Widget body;
    if (shown != null) {
      final items = [
        for (final i in shown.items)
          if (widget.filter == null || widget.filter!(i)) i,
      ];
      if (items.isEmpty) {
        body = SectionMessage(icon: Icons.inbox_outlined, message: s.feedEmpty);
      } else {
        body = Column(
          children: [
            if (shown.fromSavedCopy)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.savedCopy, style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            PostList(items: items.take(widget.maxItems).toList()),
          ],
        );
      }
    } else if (_error != null) {
      final offline = _error is FeedFailure && (_error as FeedFailure).offline;
      body = SectionMessage(
        icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
        message: offline ? s.feedOffline : s.feedError,
        onRetry: _retry,
        retryLabel: s.tryAgain,
      );
    } else {
      body = const SkeletonList();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: body,
    );
  }
}
