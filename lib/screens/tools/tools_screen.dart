import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/personal/models.dart' show FavoriteKind;
import '../../core/tools/calc_model.dart';
import '../../utils/navigation.dart';
import '../../widgets/coming_soon_card.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/page_body.dart';
import '../../widgets/website_card.dart';
import '../home/section_header.dart';
import 'tool_catalog.dart';

/// The Tools tab: search + categories of offline tools, plus OnlineCalcy.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _categoryTitle(AppStrings s, ToolCategory c) => switch (c) {
        ToolCategory.examCalc => s.catExamCalc,
        ToolCategory.files => s.catFiles,
        ToolCategory.student => s.catStudent,
        ToolCategory.examJob => s.catExamJob,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final config = AppScope.of(context).config;
    final entries = toolCatalog.where((e) => e.matches(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.toolsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: s.toolsSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: s.clear,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (entries.isEmpty)
              SectionMessage(icon: Icons.search_off_rounded, message: s.noToolsFound)
            else
              for (final cat in ToolCategory.values)
                if (entries.any((e) => e.category == cat)) ...[
                  SectionHeader(_categoryTitle(s, cat)),
                  _ToolGrid(entries: entries.where((e) => e.category == cat).toList()),
                  const SizedBox(height: 14),
                ],
            if (_query.isEmpty) ...[
              SectionHeader(s.onlineToolsTitle),
              ListenableBuilder(
                listenable: config,
                builder: (context, _) {
                  final site = config.config.siteById('onlinecalcy');
                  if (site == null) return const SizedBox.shrink();
                  return WebsiteCard(
                    site: site,
                    index: 0,
                    onOpen: () => openWebsite(context, site),
                  );
                },
              ),
              const SizedBox(height: 14),
              ComingSoonCard(message: s.comingSoonTools),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  final List<ToolEntry> entries;
  const _ToolGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 10.0;
        final cols = (c.maxWidth / 220).floor().clamp(2, 4);
        final width = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final e in entries)
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
                  child: Stack(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(builder: e.builder),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 76),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(e.icon, color: scheme.onPrimaryContainer),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.title.of(lang),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FavoriteButton(
                          title: e.title.of(lang),
                          urlOf: () => 'saralbook://tool/${e.id}',
                          kind: FavoriteKind.tool,
                          size: 18,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
