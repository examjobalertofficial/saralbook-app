import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/endpoints.dart';
import '../feed/feed_repository.dart';
import '../l10n/ltext.dart';

/// One filter on the Jobs tab. The posts come from our own website
/// (examjobalert.com) through the normal WordPress API: no paid service.
class JobTab {
  final String id;
  final LText title;
  final IconData icon;
  final Color color;

  /// Words that identify the website category (matched against its name/slug).
  /// Empty = all latest posts.
  final List<String> keywords;
  const JobTab(this.id, this.title, this.icon, this.color, this.keywords);
}

final List<JobTab> jobTabs = [
  JobTab('latest', t('Latest Jobs', 'ताज़ा नौकरियां'), Icons.work_rounded, const Color(0xFF3F6FD8), const []),
  JobTab('admit_card', t('Admit Card', 'एडमिट कार्ड'), Icons.badge_rounded, const Color(0xFFE8590C),
      const ['admit card', 'admitcard', 'admit-card', 'hall ticket']),
  JobTab('answer_key', t('Answer Key', 'आंसर की'), Icons.vpn_key_rounded, const Color(0xFF7048E8),
      const ['answer key', 'answerkey', 'answer-key']),
  JobTab('result', t('Result', 'रिज़ल्ट'), Icons.emoji_events_rounded, const Color(0xFF2F9E44), const ['result']),
  JobTab('syllabus', t('Syllabus', 'सिलेबस'), Icons.menu_book_rounded, const Color(0xFF0C8599),
      const ['syllabus']),
];

JobTab? jobTabById(String? id) {
  for (final tab in jobTabs) {
    if (tab.id == id) return tab;
  }
  return null;
}

String _squash(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Picks the website category that belongs to a tab: its name or slug contains
/// one of the [keywords]; the one with most posts wins. Null = none found.
int? pickCategoryId(String body, List<String> keywords) {
  if (keywords.isEmpty) return null;
  final wanted = [for (final k in keywords) _squash(k)];
  Object? json;
  try {
    json = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (json is! List) return null;
  int? best;
  var bestCount = -1;
  for (final row in json) {
    if (row is! Map) continue;
    final id = row['id'];
    if (id is! int) continue;
    final hay = _squash('${row['name'] ?? ''}${row['slug'] ?? ''}');
    if (!wanted.any(hay.contains)) continue;
    final count = row['count'] is int ? row['count'] as int : 0;
    if (count > bestCount) {
      best = id;
      bestCount = count;
    }
  }
  return best;
}

/// Works out the post-list address of a tab. Uses the website category when it
/// exists, otherwise falls back to a search for the keyword, so a tab is never
/// empty just because a category is named differently.
Future<String> jobTabUrl(FeedRepository feeds, JobTab tab, {int perPage = 20}) async {
  const base = '${Endpoints.examJobAlertBase}/wp-json/wp/v2';
  if (tab.keywords.isEmpty) return '$base/posts?per_page=$perPage';
  final search = Uri.encodeQueryComponent(tab.keywords.first);
  final body = await feeds.getText(
    '$base/categories?per_page=50&orderby=count&order=desc&hide_empty=true&_fields=id,name,slug,count&search=$search',
  );
  final id = body == null ? null : pickCategoryId(body, tab.keywords);
  if (id != null) return '$base/posts?per_page=$perPage&categories=$id';
  return '$base/posts?per_page=$perPage&search=$search';
}
