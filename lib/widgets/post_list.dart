import 'package:flutter/material.dart';

import '../core/feed/feed_repository.dart';
import '../core/feed/post_kind.dart';
import '../core/l10n/ltext.dart';
import '../utils/navigation.dart';
import 'animations.dart';
import 'favorite_button.dart';
import 'tr.dart';

/// A coloured list of posts: a round icon in the colour of the post's kind
/// (job, admit card, result...), the title, the date and an "Updated" badge
/// for posts that were edited after being published.
class PostList extends StatelessWidget {
  final List<FeedItem> items;
  final bool animate;
  const PostList({super.key, required this.items, this.animate = true});

  static final LText _updated = t('Updated', 'अपडेट');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Builder(builder: (context) {
            final item = items[i];
            final style = postKindStyles[postKindOf(item.title)]!;
            final tile = Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Color.alphaBlend(style.color.withAlpha(dark ? 36 : 22), scheme.surface),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openFeedItem(context, item.title, item.link),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [style.color, Color.alphaBlend(Colors.black.withAlpha(50), style.color)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(style.icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Pill(tr(context, style.label), style.color),
                                  if (item.isUpdated) _Pill(tr(context, _updated), const Color(0xFFD6336C), filled: true),
                                  if (item.dateLabel.isNotEmpty)
                                    Text(item.dateLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        FavoriteButton(title: item.title, urlOf: () => item.link, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
            return animate ? FadeSlideIn(index: i, child: tile) : tile;
          }),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const _Pill(this.text, this.color, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withAlpha(34),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: filled ? Colors.white : color),
      ),
    );
  }
}
