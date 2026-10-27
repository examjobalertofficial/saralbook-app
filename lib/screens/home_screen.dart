import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_services.dart';
import '../core/config/config_controller.dart';
import '../core/config/remote_config.dart';
import '../core/l10n/app_strings.dart';
import '../core/l10n/ltext.dart';
import '../utils/navigation.dart';
import '../core/jobs/job_tabs.dart';
import '../core/router/app_router.dart';
import '../widgets/animations.dart';
import '../widgets/announcement_card.dart';
import '../widgets/brand_logo.dart';
import '../widgets/page_body.dart';
import '../widgets/tr.dart';
import '../widgets/youtube_card.dart';
import 'search_screen.dart';
import 'update_required_screen.dart';
import 'home/customize_screen.dart';
import 'home/expense_section.dart';
import 'home/favorites_section.dart';
import 'home/feed_section.dart';
import 'home/platforms_section.dart';
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
                            child: Row(
                              children: [
                                const BrandLogo(size: 48),
                                const SizedBox(width: 14),
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
                                      Text(
                                        tr(context, t('Jobs, study and tools in one app', 'नौकरी, पढ़ाई और टूल्स एक ही ऐप में')),
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.customizeHome,
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
                    const SliverToBoxAdapter(child: _SearchBar()),
                    const SliverToBoxAdapter(child: _QuickTabs()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _Notices(config: config),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: sections.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          key: ValueKey('in_${sections[i].id}'),
                          index: i,
                          child: _section(context, sections[i], config, lang),
                        ),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverToBoxAdapter(child: YoutubeCard()),
                    ),
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

/// A search box under the banner. Tapping it opens the full search screen.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, t('Search jobs, results, tools…', 'नौकरी, रिज़ल्ट, टूल खोजें…')),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Five coloured shortcuts that open the Jobs tab on the matching filter.
class _QuickTabs extends StatelessWidget {
  const _QuickTabs();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: jobTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final tab = jobTabs[i];
          return FadeSlideIn(
            index: i,
            child: PressScale(
              onTap: () => context.go('${AppRoutes.jobs}?tab=${tab.id}'),
              child: SizedBox(
                width: 74,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [tab.color, Color.alphaBlend(Colors.black.withAlpha(60), tab.color)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [BoxShadow(color: tab.color.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Icon(tab.icon, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(context, tab.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
          if (url != null) {
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
