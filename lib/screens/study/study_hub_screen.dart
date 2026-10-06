import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/ltext.dart';
import '../../utils/navigation.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../../widgets/website_card.dart';
import '../account/account_widgets.dart';
import '../home/section_header.dart';
import 'countdown_screen.dart';
import 'favorites_screen.dart';
import 'notes_screens.dart';
import 'planner_screen.dart';
import 'progress_screen.dart';
import 'todo_screen.dart';

/// The Study tab: personal study tools on top, SaralBook study websites below.
class StudyHubScreen extends StatelessWidget {
  const StudyHubScreen({super.key});

  static final List<(LText, IconData, Widget Function())> _tools = [
    (t('Notes', 'नोट्स'), Icons.sticky_note_2_outlined, () => const NotesScreen()),
    (t('To-Do', 'टू-डू'), Icons.checklist_rounded, () => const TodoScreen()),
    (t('Study Planner', 'स्टडी प्लानर'), Icons.event_note_outlined, () => const PlannerScreen()),
    (t('Progress', 'प्रगति'), Icons.insights_outlined, () => const ProgressScreen()),
    (t('Exam Countdown', 'परीक्षा काउंटडाउन'), Icons.hourglass_bottom_rounded, () => const CountdownScreen()),
    (t('Favorites', 'पसंदीदा'), Icons.bookmark_border_rounded, () => const FavoritesScreen()),
  ];

  static final LText _myTools = t('My study tools', 'मेरे स्टडी टूल्स');
  static final LText _resources = t('Study resources', 'अध्ययन सामग्री');

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final config = AppScope.of(context).config;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.studyTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(s.studySubtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SignInPromptCard(),
            SectionHeader(tr(context, _myTools)),
            LayoutBuilder(
              builder: (context, c) {
                const spacing = 10.0;
                final cols = (c.maxWidth / 200).floor().clamp(2, 4);
                final width = (c.maxWidth - spacing * (cols - 1)) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final tool in _tools)
                      SizedBox(
                        width: width,
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(builder: (_) => tool.$3()),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                    child: Icon(tool.$2, color: scheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    tr(context, tool.$1),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            SectionHeader(tr(context, _resources)),
            ListenableBuilder(
              listenable: config,
              builder: (context, _) {
                final sites = config.sitesByIds(const ['saralbook', 'saralbooktest', 'saralbookstore']);
                return Column(
                  children: [
                    for (var i = 0; i < sites.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: WebsiteCard(site: sites[i], index: i, onOpen: () => openWebsite(context, sites[i])),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
