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
  /// Gives the post-list address (may need a short lookup first).
  final Future<String> Function(FeedRepository feeds) resolveUrl;
  final int refreshToken;
  final int maxItems;
  const PostFeed({super.key, required this.resolveUrl, this.refreshToken = 0, this.maxItems = 50});

  @override
  State<PostFeed> createState() => _PostFeedState();
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
    try {
      final url = await widget.resolveUrl(feeds);
      if (!mounted || run != _run) return;
      if (!force && _shown == null) {
        final saved = feeds.peek(url);
        if (saved != null) setState(() => _shown = saved);
      }
      final result = await feeds.load(url, force: force);
      if (!mounted || run != _run) return;
      setState(() {
        _shown = result;
        _error = null;
      });
    } catch (e) {
      if (!mounted || run != _run) return;
      setState(() => _error = e);
    }
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
      if (shown.items.isEmpty) {
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
            PostList(items: shown.items.take(widget.maxItems).toList()),
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
