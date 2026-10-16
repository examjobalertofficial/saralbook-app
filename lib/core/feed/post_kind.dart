import 'package:flutter/material.dart';

import '../l10n/ltext.dart';

/// What a post is about. Worked out from its title, so no extra website data
/// is needed. Each kind has its own colour (colours only: the app stays small).
enum PostKind { job, admitCard, answerKey, result, syllabus, other }

class PostKindStyle {
  final LText label;
  final IconData icon;
  final Color color;
  const PostKindStyle(this.label, this.icon, this.color);
}

PostKind postKindOf(String title) {
  final s = title.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);
  if (has(['admit card', 'hall ticket', 'call letter', 'e-admit', 'city intimation'])) return PostKind.admitCard;
  if (has(['answer key', 'answerkey', 'response sheet', 'objection'])) return PostKind.answerKey;
  if (has(['result', 'merit list', 'cut off', 'cutoff', 'scorecard', 'score card'])) return PostKind.result;
  if (has(['syllabus', 'exam pattern', 'exam date', 'time table', 'timetable'])) return PostKind.syllabus;
  if (has(['recruitment', 'vacancy', 'vacancies', 'apply', 'notification', 'bharti', 'online form', 'jobs'])) {
    return PostKind.job;
  }
  return PostKind.other;
}

final Map<PostKind, PostKindStyle> postKindStyles = {
  PostKind.job: PostKindStyle(t('Job', 'नौकरी'), Icons.work_rounded, const Color(0xFF3F6FD8)),
  PostKind.admitCard: PostKindStyle(t('Admit Card', 'एडमिट कार्ड'), Icons.badge_rounded, const Color(0xFFE8590C)),
  PostKind.answerKey: PostKindStyle(t('Answer Key', 'आंसर की'), Icons.vpn_key_rounded, const Color(0xFF7048E8)),
  PostKind.result: PostKindStyle(t('Result', 'रिज़ल्ट'), Icons.emoji_events_rounded, const Color(0xFF2F9E44)),
  PostKind.syllabus: PostKindStyle(t('Syllabus', 'सिलेबस'), Icons.menu_book_rounded, const Color(0xFF0C8599)),
  PostKind.other: PostKindStyle(t('Update', 'अपडेट'), Icons.article_rounded, const Color(0xFFD6336C)),
};
