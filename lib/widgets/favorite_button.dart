import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/l10n/ltext.dart';
import '../core/personal/logic.dart';
import '../core/personal/models.dart';
import '../screens/account/account_widgets.dart';
import 'tr.dart';

/// Bookmark toggle. Asks to sign in first if needed (favourites live in the
/// person's account so they appear on every phone).
class FavoriteButton extends StatelessWidget {
  final String title;

  /// Read at tap/paint time because web pages change their address.
  final String Function() urlOf;
  final FavoriteKind? kind;
  final double size;

  /// Small tap area (for use inside tiles).
  final bool compact;

  const FavoriteButton({
    super.key,
    required this.title,
    required this.urlOf,
    this.kind,
    this.size = 24,
    this.compact = false,
  });

  static final LText _saved = t('Saved to favorites', 'पसंदीदा में सेव हुआ');
  static final LText _removed = t('Removed from favorites', 'पसंदीदा से हटाया गया');
  static final LText _label = t('Favorite', 'पसंदीदा');

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await requireSignIn(context);
    if (!ok || !context.mounted) return;
    final data = AppScope.of(context).personal.current;
    if (data == null) return;
    final url = urlOf();
    final existing = data.favoriteForUrl(url);
    final lang = Localizations.localeOf(context).languageCode;
    if (existing != null) {
      data.favorites.remove(existing.id);
      messenger.showSnackBar(SnackBar(content: Text(_removed.of(lang))));
    } else {
      data.favorites.upsert(
        Favorite.create(kind: kind ?? guessFavoriteKind(url, title), title: title, url: url),
      );
      messenger.showSnackBar(SnackBar(content: Text(_saved.of(lang))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = AppScope.of(context).personal;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final data = hub.current;
        Widget button(bool saved) => IconButton(
              tooltip: tr(context, _label),
              iconSize: size,
              padding: compact ? EdgeInsets.zero : null,
              constraints: compact ? const BoxConstraints.tightFor(width: 32, height: 32) : null,
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              color: saved ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => _toggle(context),
            );
        if (data == null) return button(false);
        return ListenableBuilder(
          listenable: data.favorites,
          builder: (context, _) => button(data.favoriteForUrl(urlOf()) != null),
        );
      },
    );
  }
}
