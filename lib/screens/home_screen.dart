import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_services.dart';
import '../core/config/config_controller.dart';
import '../core/config/remote_config.dart';
import '../core/l10n/app_strings.dart';
import '../core/l10n/ltext.dart';
import '../utils/navigation.dart';
import '../widgets/animations.dart';
import '../widgets/announcement_card.dart';
import '../widgets/brand_logo.dart';
import '../widgets/page_body.dart';
import '../widgets/rating_trigger.dart';
import '../widgets/tr.dart';
import '../widgets/youtube_card.dart';
import 'search_screen.dart';
import 'update_required_screen.dart';
import 'home/customize_screen.dart';
import 'home/expense_section.dart';
import 'home/favorites_section.dart';
import 'home/feed_section.dart';
import 'home/platforms_section.dart';
import 'home/shortcuts_section.dart';
import 'home/recent_section.dart';

/// Home is driven by the configuration (remote or built-in): the list of
/// sections, their order and content come from there, not from this file.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: ListenableBuilder(
            listenable: Listenable.merge([services.config, services.layout]),
            builder: (context, _) {
              final config = services.config;
              final sections = services.layout.visible(config.sections);
              return RefreshIndicator(
                onRefresh: () => config.refresh(force: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: FadeSlideIn(
                          child: GradientBanner(
                            colors: const [Color(0xFF1E5AA8), Color(0xFF7048E8), Color(0xFFD6336C)],
                            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                            child: Row(
                              children: [
                                const BrandLogo(size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.appName,
                                        style: text.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      // Always one line: the text shrinks a little on narrow phones.
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          tr(context, t('Jobs, study and tools in one app', 'नौकरी, पढ़ाई और टूल्स एक ही ऐप में')),
                                          maxLines: 1,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr(context, t('Search', 'खोजें')),
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.customizeHome,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const HomeCustomizeScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: ShortcutsSection(hidden: config.hiddenShortcuts)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _Notices(config: config),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      // All sections are built together (not lazily), so a pull-to-refresh
                      // reaches every list, also the ones far below the screen.
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            for (var i = 0; i < sections.length; i++)
                              FadeSlideIn(
                                key: ValueKey('in_${sections[i].id}'),
                                index: i,
                                child: _section(context, sections[i], config, lang),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverToBoxAdapter(child: YoutubeCard()),
                    ),
                    const SliverToBoxAdapter(child: RatingTrigger()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, HomeSection sec, ConfigController config, String lang) {
    switch (sec.type) {
      case 'platforms':
        return PlatformsSection(key: ValueKey(sec.id), sites: config.sites, title: sec.titleFor(lang));
      case 'feed':
        return FeedSection(key: ValueKey(sec.id), section: sec, refreshToken: config.refreshToken);
      case 'expense':
        return ExpenseSection(key: ValueKey(sec.id), title: sec.titleFor(lang));
      case 'favorites':
        return FavoritesSection(key: ValueKey(sec.id), title: sec.titleFor(lang));
      case 'recent':
        return RecentSection(key: ValueKey(sec.id), title: sec.titleFor(lang));
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Maintenance banner (non-blocking) and announcements from the website.
class _Notices extends StatelessWidget {
  final ConfigController config;
  const _Notices({required this.config});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final Maintenance m = config.maintenance;
    final List<Announcement> notes = config.announcements;
    final children = <Widget>[];

    if (m.enabled && !m.blocking) {
      children.add(_Banner(
        icon: Icons.construction_rounded,
        title: s.maintenanceTitle,
        message: m.message.isEmpty ? s.maintenanceMessage : m.message,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ));
    }
    if (config.updateAvailable) {
      children.add(_Banner(
        icon: Icons.system_update_rounded,
        title: tr(context, t('Update available', 'नया अपडेट उपलब्ध')),
        message: config.update.message.isEmpty
            ? tr(context, t('A newer version of SaralBook is ready. Tap to update.',
                'सरलबुक का नया वर्ज़न तैयार है। अपडेट करने के लिए टैप करें।'))
            : config.update.message,
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        onTap: () => openUpdatePage(config.update.target),
      ));
    }
    if (notes.isNotEmpty) {
      children.add(AnnouncementCard(
        items: notes,
        onOpen: (n) {
          final url = n.url;
          if (url != null && url.startsWith('https://play.google.com/')) {
            // Our own Google Play page: open the Play Store app directly.
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).then<void>((_) {}, onError: (Object _) {});
          } else if (url != null) {
            openFeedItem(context, n.title.isEmpty ? n.message : n.title, url);
          }
        },
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: children),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _Banner({
    required this.icon,
    required this.title,
    required this.message,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (message.isNotEmpty)
                        Text(message, style: TextStyle(color: foreground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
