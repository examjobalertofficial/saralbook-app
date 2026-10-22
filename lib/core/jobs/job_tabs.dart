import 'package:flutter/material.dart';

import '../../config/endpoints.dart';
import '../feed/feed_repository.dart';
import '../feed/post_kind.dart';
import '../l10n/ltext.dart';

/// One filter on the Jobs tab. Posts are sorted into tabs by the words in
/// their title (see [postKindOf]), so it works the same for every website and
/// needs no category setup. No paid or third-party service is used.
class JobTab {
  final String id;
  final LText title;
  final IconData icon;
  final Color color;

  /// Which kind of post belongs here. null = every post.
  final PostKind? kind;
  const JobTab(this.id, this.title, this.icon, this.color, this.kind);

  bool accepts(FeedItem item) => kind == null || postKindOf(item.title) == kind;
}

final List<JobTab> jobTabs = [
  JobTab('latest', t('Latest Jobs', 'ताज़ा नौकरियां'), Icons.work_rounded, const Color(0xFF3F6FD8), PostKind.job),
  JobTab('admit_card', t('Admit Card', 'एडमिट कार्ड'), Icons.badge_rounded, const Color(0xFFE8590C), PostKind.admitCard),
  JobTab('answer_key', t('Answer Key', 'आंसर की'), Icons.vpn_key_rounded, const Color(0xFF7048E8), PostKind.answerKey),
  JobTab('result', t('Result', 'रिज़ल्ट'), Icons.emoji_events_rounded, const Color(0xFF2F9E44), PostKind.result),
  JobTab('admission', t('Admission', 'एडमिशन'), Icons.school_rounded, const Color(0xFFD6336C), null),
  // Syllabus shows every post of the five categories.
  JobTab('syllabus', t('Syllabus', 'सिलेबस'), Icons.menu_book_rounded, const Color(0xFF0C8599), null),
];

JobTab? jobTabById(String? id) {
  for (final tab in jobTabs) {
    if (tab.id == id) return tab;
  }
  return null;
}

/// Plain post lists of both websites (kept for reference; the Jobs tab now asks
/// for one category at a time, see job_categories.dart).
const List<String> jobSourceUrls = [
  '${Endpoints.examJobAlertBase}/wp-json/wp/v2/posts?per_page=100',
  '${Endpoints.saralBookBase}/wp-json/wp/v2/posts?per_page=100',
];
