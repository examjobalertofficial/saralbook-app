import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../widgets/page_body.dart';

/// Lets the user show/hide and drag-reorder Home sections.
class HomeCustomizeScreen extends StatelessWidget {
  const HomeCustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final services = AppScope.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    String nameOf(String id, String type, String title) {
      if (title.isNotEmpty) return title;
      if (type == 'platforms') return s.platformsTitle;
      if (type == 'recent') return s.recentTitle;
      return id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.customizeHome, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => services.layout.reset(),
            child: Text(s.resetDefault),
          ),
        ],
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([services.layout, services.config]),
          builder: (context, _) {
            final list = services.layout.ordered(services.config.sections);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(s.customizeHint),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: list.length,
                    onReorder: (oldIndex, newIndex) {
                      final ids = [for (final e in list) e.id];
                      if (newIndex > oldIndex) newIndex -= 1;
                      ids.insert(newIndex, ids.removeAt(oldIndex));
                      services.layout.setOrder(ids);
                    },
                    itemBuilder: (context, i) {
                      final sec = list[i];
                      return SwitchListTile(
                        key: ValueKey(sec.id),
                        title: Text(nameOf(sec.id, sec.type, sec.titleFor(lang))),
                        value: !services.layout.isHidden(sec.id),
                        onChanged: (v) => services.layout.setHidden(sec.id, !v),
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
