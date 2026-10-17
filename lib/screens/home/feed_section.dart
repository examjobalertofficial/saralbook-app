import 'package:flutter/material.dart';

import '../../core/config/remote_config.dart';
import '../../widgets/post_feed.dart';
import '../tools/tool_style.dart';
import 'section_header.dart';

/// A list of the latest posts from a website (jobs, results, articles...),
/// newest *edit* first. Shown on Home from the configuration.
class FeedSection extends StatelessWidget {
  final HomeSection section;
  final int refreshToken;
  const FeedSection({super.key, required this.section, required this.refreshToken});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(section.titleFor(lang), accent: toolAccent(section.id)),
          PostFeed(
            key: ValueKey('${section.id}|${section.feedUrl}'),
            urls: [section.feedUrl],
            refreshToken: refreshToken,
          ),
        ],
      ),
    );
  }
}
