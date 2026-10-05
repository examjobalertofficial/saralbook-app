import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../utils/navigation.dart';
import 'section_header.dart';

class RecentSection extends StatelessWidget {
  final String title;
  const RecentSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final recents = AppScope.of(context).recents;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title.isEmpty ? s.recentTitle : title),
          ListenableBuilder(
            listenable: recents,
            builder: (context, _) {
              final items = recents.items.take(5).toList();
              if (items.isEmpty) {
                return SectionMessage(
                  icon: Icons.history_rounded,
                  message: s.recentEmpty,
                );
              }
              return Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: scheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(
                          items[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => openFeedItem(context, items[i].title, items[i].url),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
