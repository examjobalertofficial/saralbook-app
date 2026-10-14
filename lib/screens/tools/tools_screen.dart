import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/config/config_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/personal/models.dart' show FavoriteKind;
import '../../core/tools/calc_model.dart';
import '../../utils/navigation.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/page_body.dart';
import '../../widgets/website_card.dart';
import '../home/section_header.dart';
import 'tool_catalog.dart';
import 'tool_style.dart';

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
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) => _page(context, s, config),
    );
  }

  Widget _page(BuildContext context, AppStrings s, ConfigController config) {
    final entries = toolCatalog.where((e) => config.toolOn(e.id) && e.matches(_query)).toList();

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 10.0;
        final cols = (c.maxWidth / 170).floor().clamp(2, 5);
        final width = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final e in entries)
              SizedBox(
                width: width,
                child: _ToolCard(
                  entry: e,
                  lang: lang,
                  accent: toolAccent(e.id),
                  surface: scheme.surfaceContainerLow,
                  dark: dark,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One tool: a coloured icon on top, the full name under it (it never breaks
/// a word in the middle), and the bookmark in the corner.
class _ToolCard extends StatelessWidget {
  final ToolEntry entry;
  final String lang;
  final Color accent;
  final Color surface;
  final bool dark;
  const _ToolCard({
    required this.entry,
    required this.lang,
    required this.accent,
    required this.surface,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = toolCardTint(accent, surface, dark: dark);
    final deep = Color.lerp(accent, Colors.black, 0.28) ?? accent;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: tint,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withAlpha(dark ? 90 : 70)),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: entry.builder),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent, deep],
                        ),
                        boxShadow: [
                          BoxShadow(color: accent.withAlpha(70), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Icon(entry.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.title.of(lang),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: FavoriteButton(
              title: entry.title.of(lang),
              urlOf: () => 'saralbook://tool/${entry.id}',
              kind: FavoriteKind.tool,
              size: 18,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}
