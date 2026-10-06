import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/config/remote_config.dart';
import '../../core/feed/feed_repository.dart';
import '../../core/l10n/app_strings.dart';
import '../../utils/navigation.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/skeleton.dart';
import 'section_header.dart';

/// A list of the latest posts from a website (jobs, results, articles...).
/// Handles loading, success, empty, error, offline and retry by itself.
class FeedSection extends StatefulWidget {
  final HomeSection section;
  final int refreshToken;
  const FeedSection({super.key, required this.section, required this.refreshToken});

  @override
  State<FeedSection> createState() => _FeedSectionState();
}

class _FeedSectionState extends State<FeedSection> {
  Future<FeedResult>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).feeds.load(widget.section.feedUrl);
  }

  @override
  void didUpdateWidget(FeedSection old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken ||
        old.section.feedUrl != widget.section.feedUrl) {
      _future = AppScope.of(context)
          .feeds
          .load(widget.section.feedUrl, force: true);
    }
  }

  void _retry() {
    setState(() {
      _future = AppScope.of(context)
          .feeds
          .load(widget.section.feedUrl, force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(widget.section.titleFor(lang)),
          FutureBuilder<FeedResult>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SkeletonList();
              }
              if (snap.hasError) {
                final offline = snap.error is FeedFailure &&
                    (snap.error as FeedFailure).offline;
                return SectionMessage(
                  icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                  message: offline ? s.feedOffline : s.feedError,
                  onRetry: _retry,
                  retryLabel: s.tryAgain,
                );
              }
              final result = snap.data!;
              if (result.items.isEmpty) {
                return SectionMessage(
                  icon: Icons.inbox_outlined,
                  message: s.feedEmpty,
                );
              }
              return _FeedCard(result: result, savedCopyLabel: s.savedCopy);
            },
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedResult result;
  final String savedCopyLabel;
  const _FeedCard({required this.result, required this.savedCopyLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          if (result.fromSavedCopy)
            Container(
              width: double.infinity,
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      savedCopyLabel,
                      style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < result.items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            ListTile(
              title: Text(
                result.items[i].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: result.items[i].dateLabel.isEmpty
                  ? null
                  : Text(result.items[i].dateLabel),
              trailing: FavoriteButton(
                title: result.items[i].title,
                urlOf: () => result.items[i].link,
                size: 22,
              ),
              onTap: () => openFeedItem(
                context,
                result.items[i].title,
                result.items[i].link,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
