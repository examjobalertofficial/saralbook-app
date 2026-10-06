import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../utils/navigation.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../tools/tool_catalog.dart';
import 'personal_ui.dart';

final LText _title = t('Favorites', 'पसंदीदा');

LText kindLabel(FavoriteKind k) => switch (k) {
      FavoriteKind.job => t('Jobs', 'नौकरियां'),
      FavoriteKind.article => t('Articles', 'लेख'),
      FavoriteKind.result => t('Results', 'रिज़ल्ट'),
      FavoriteKind.admitCard => t('Admit cards', 'एडमिट कार्ड'),
      FavoriteKind.mockTest => t('Mock tests', 'मॉक टेस्ट'),
      FavoriteKind.tool => t('Tools', 'टूल्स'),
      FavoriteKind.product => t('Store', 'स्टोर'),
      FavoriteKind.page => t('Pages', 'पेज'),
    };

IconData kindIcon(FavoriteKind k) => switch (k) {
      FavoriteKind.job => Icons.work_outline_rounded,
      FavoriteKind.article => Icons.article_outlined,
      FavoriteKind.result => Icons.emoji_events_outlined,
      FavoriteKind.admitCard => Icons.badge_outlined,
      FavoriteKind.mockTest => Icons.quiz_outlined,
      FavoriteKind.tool => Icons.handyman_outlined,
      FavoriteKind.product => Icons.shopping_bag_outlined,
      FavoriteKind.page => Icons.bookmark_outline_rounded,
    };

/// Opens a saved item: a tool opens natively, anything else in the in-app browser.
void openFavorite(BuildContext context, Favorite f) {
  const toolPrefix = 'saralbook://tool/';
  if (f.url.startsWith(toolPrefix)) {
    final id = f.url.substring(toolPrefix.length);
    final matches = toolCatalog.where((e) => e.id == id);
    if (matches.isNotEmpty) {
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: matches.first.builder));
    }
    return;
  }
  openFeedItem(context, f.title, f.url);
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Favorites(data: data));
}

class _Favorites extends StatefulWidget {
  final PersonalData data;
  const _Favorites({required this.data});

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> {
  FavoriteKind? _kind;

  static final LText _empty = t(
    'Nothing saved yet. Tap the bookmark icon on a job, article, test or tool to save it here.',
    'अभी कुछ सेव नहीं है। किसी जॉब, लेख, टेस्ट या टूल पर बुकमार्क आइकन दबाकर यहां सेव करें।',
  );
  static final LText _all = t('All', 'सभी');
  static final LText _removed = t('Removed from favorites', 'पसंदीदा से हटाया गया');

  @override
  Widget build(BuildContext context) {
    final controller = widget.data.favorites;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!controller.loaded) return const Center(child: CircularProgressIndicator());
            final items = List<Favorite>.of(controller.items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final kinds = [for (final k in FavoriteKind.values) if (items.any((f) => f.kind == k)) k];
            final kind = (_kind != null && kinds.contains(_kind)) ? _kind : null;
            final shown = kind == null ? items : items.where((f) => f.kind == kind).toList();
            if (items.isEmpty) {
              return Column(children: [
                SyncProblemBanner(visible: controller.hasError),
                Expanded(child: EmptyState(icon: Icons.bookmark_border_rounded, message: _empty)),
              ]);
            }
            return Column(
              children: [
                SyncProblemBanner(visible: controller.hasError),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tr(context, _all)),
                          selected: kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                      ),
                      for (final k in kinds)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tr(context, kindLabel(k))),
                            selected: kind == k,
                            onSelected: (_) => setState(() => _kind = k),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final f = shown[i];
                      return Dismissible(
                        key: ValueKey(f.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                        ),
                        onDismissed: (_) {
                          controller.remove(f.id);
                          showUndo(context, _removed, () => controller.upsert(f));
                        },
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          color: scheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          child: ListTile(
                            onTap: () => openFavorite(context, f),
                            leading: Icon(kindIcon(f.kind), color: scheme.primary),
                            title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(tr(context, kindLabel(f.kind))),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
