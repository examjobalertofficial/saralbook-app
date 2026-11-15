import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/shortcuts.dart';
import '../../core/l10n/ltext.dart';
import '../../core/router/app_router.dart';
import '../../widgets/animations.dart';
import '../../widgets/tr.dart';
import '../groups/groups_home_screen.dart';
import '../tools/tool_catalog.dart';

class _Shortcut {
  final String id;
  final LText label;
  final IconData icon;
  final Color color;

  /// A Jobs tab id (opens that tab), or null for a tool or the groups screen.
  final String? jobTab;
  final String? toolId;
  final bool groups;
  const _Shortcut(this.id, this.label, this.icon, this.color, {this.jobTab, this.toolId, this.groups = false});
}

/// Names are kept short: each one stays on a single line.
final Map<String, _Shortcut> _all = {
  for (final s in <_Shortcut>[
    _Shortcut('latest', t('Latest Jobs', 'ताज़ा जॉब्स'), Icons.work_rounded, const Color(0xFF3F6FD8), jobTab: 'latest'),
    _Shortcut('admit_card', t('Admit Card', 'एडमिट कार्ड'), Icons.badge_rounded, const Color(0xFFE8590C), jobTab: 'admit_card'),
    _Shortcut('answer_key', t('Answer Key', 'आंसर की'), Icons.vpn_key_rounded, const Color(0xFF7048E8), jobTab: 'answer_key'),
    _Shortcut('result', t('Result', 'रिज़ल्ट'), Icons.emoji_events_rounded, const Color(0xFF2F9E44), jobTab: 'result'),
    _Shortcut('admission', t('Admission', 'एडमिशन'), Icons.school_rounded, const Color(0xFFD6336C), jobTab: 'admission'),
    _Shortcut('syllabus', t('Syllabus', 'सिलेबस'), Icons.menu_book_rounded, const Color(0xFF0C8599), jobTab: 'syllabus'),
    _Shortcut('group_expense', t('Group Expense', 'ग्रुप खर्च'), Icons.groups_2_rounded, const Color(0xFF0CA678), groups: true),
    _Shortcut('resume_maker', t('Resume Maker', 'रिज़्यूमे'), Icons.description_rounded, const Color(0xFF1971C2), toolId: 'resume_maker'),
    _Shortcut('doc_scanner', t('Doc Scanner', 'डॉक स्कैनर'), Icons.document_scanner_rounded, const Color(0xFF5F3DC4), toolId: 'doc_scanner'),
    _Shortcut('photo_resize', t('Photo Resize', 'फ़ोटो रीसाइज़'), Icons.photo_size_select_large_rounded, const Color(0xFFC2255C), toolId: 'photo_resize'),
    _Shortcut('pdf_compress', t('Compress PDF', 'PDF कंप्रेस'), Icons.compress_rounded, const Color(0xFFE03131), toolId: 'pdf_compress'),
    _Shortcut('images_to_pdf', t('Image to PDF', 'इमेज से PDF'), Icons.picture_as_pdf_rounded, const Color(0xFF2B8A3E), toolId: 'images_to_pdf'),
  ])
    s.id: s,
};

/// The shortcut buttons under the Home header: four in a row, as many rows as
/// needed. Buttons the website switched off are left out and the rest move up.
class ShortcutsSection extends StatelessWidget {
  final Set<String> hidden;
  const ShortcutsSection({super.key, required this.hidden});

  void _open(BuildContext context, _Shortcut s) {
    if (s.jobTab != null) {
      context.go('${AppRoutes.jobs}?tab=${s.jobTab}');
    } else if (s.groups) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const GroupsHomeScreen()),
      );
    } else if (s.toolId != null) {
      for (final e in toolCatalog) {
        if (e.id == s.toolId) {
          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: e.builder));
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final id in kShortcutIds)
        if (!hidden.contains(id) && _all[id] != null) _all[id]!,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final rows = <List<_Shortcut>>[
      for (var i = 0; i < items.length; i += 4) items.sublist(i, i + 4 > items.length ? items.length : i + 4),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (var c = 0; c < 4; c++)
                    Expanded(
                      child: c < rows[r].length
                          ? FadeSlideIn(
                              index: r * 4 + c,
                              child: _Tile(item: rows[r][c], onTap: () => _open(context, rows[r][c])),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final _Shortcut item;
  final VoidCallback onTap;
  const _Tile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [item.color, Color.alphaBlend(Colors.black.withAlpha(60), item.color)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: item.color.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          // One line always: the text shrinks a little instead of wrapping.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(context, item.label),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
