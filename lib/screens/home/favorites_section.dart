import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/models.dart';
import '../../widgets/tr.dart';
import '../account/account_widgets.dart';
import '../study/favorites_screen.dart';
import 'section_header.dart';

/// Home block: the latest saved favourites (or a sign-in hint).
class FavoritesSection extends StatelessWidget {
  final String title;
  const FavoritesSection({super.key, required this.title});

  static final LText _signInHint = t('Sign in to save favorites and see them here.', 'पसंदीदा सेव करने और यहां देखने के लिए साइन इन करें।');
  static final LText _empty = t('Tap the bookmark icon on any job, article or tool to save it.', 'किसी भी जॉब, लेख या टूल पर बुकमार्क आइकन दबाकर सेव करें।');
  static final LText _all = t('See all', 'सभी देखें');

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title.isEmpty ? tr(context, t('Favorites', 'पसंदीदा')) : title),
          ListenableBuilder(
            listenable: services.personal,
            builder: (context, _) {
              final data = services.personal.current;
              if (data == null) {
                return SectionMessage(
                  icon: Icons.bookmark_border_rounded,
                  message: tr(context, _signInHint),
                  onRetry: services.auth.isAvailable ? () => requireSignIn(context) : null,
                  retryLabel: s.signInGoogle,
                );
              }
              return ListenableBuilder(
                listenable: data.favorites,
                builder: (context, _) {
                  final items = List<Favorite>.of(data.favorites.items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  if (items.isEmpty) {
                    return SectionMessage(icon: Icons.bookmark_border_rounded, message: tr(context, _empty));
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
                        for (var i = 0; i < items.length && i < 5; i++) ...[
                          if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                          ListTile(
                            leading: Icon(kindIcon(items[i].kind), color: scheme.primary),
                            title: Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(tr(context, kindLabel(items[i].kind))),
                            onTap: () => openFavorite(context, items[i]),
                          ),
                        ],
                        if (items.length > 5)
                          TextButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
                            ),
                            child: Text(tr(context, _all)),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
