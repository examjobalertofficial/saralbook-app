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

/// Works out what a post is from its title. The first rule that matches wins,
/// so a title like "SSC Recruitment 2026 Admit Card" is an Admit Card.
///
///  * Answer Key : answer key
///  * Admit Card : admit card, exam date, exam city (details), time table, interview letter, hall ticket
///  * Result     : result, mark(s), merit list
///  * Latest Job : online form, recruitment (also vacancy)
PostKind postKindOf(String title) {
  final s = title.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);
  if (has(['answer key', 'answerkey', 'response sheet'])) return PostKind.answerKey;
  if (has([
    'admit card', 'admitcard', 'hall ticket', 'call letter', 'exam date', 'exam city',
    'time table', 'timetable', 'interview letter', 'e-admit',
  ])) {
    return PostKind.admitCard;
  }
  if (has(['result', 'merit list', 'cut off', 'cutoff', 'scorecard', 'score card']) ||
      RegExp(r'\bmarks?\b').hasMatch(s)) {
    return PostKind.result;
  }
  if (has(['online form', 'recruitment', 'vacancy', 'vacancies', 'bharti'])) return PostKind.job;
  if (has(['syllabus', 'exam pattern'])) return PostKind.syllabus;
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
