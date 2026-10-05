import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/config/config_controller.dart';
import '../core/config/remote_config.dart';
import '../core/l10n/app_strings.dart';
import '../utils/navigation.dart';
import '../widgets/brand_logo.dart';
import '../widgets/page_body.dart';
import 'home/customize_screen.dart';
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
                        padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                        child: Row(
                          children: [
                            const BrandLogo(size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.appName,
                                style: text.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: s.customizeHome,
                              icon: const Icon(Icons.tune_rounded),
                              onPressed: () =>
                                  Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const HomeCustomizeScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        itemBuilder: (context, i) {
                          final sec = sections[i];
                          switch (sec.type) {
                            case 'platforms':
                              return PlatformsSection(
                                key: ValueKey(sec.id),
                                sites: config.sites,
                                title: sec.titleFor(lang),
                              );
                            case 'feed':
                              return FeedSection(
                                key: ValueKey(sec.id),
                                section: sec,
                                refreshToken: config.refreshToken,
                              );
                            case 'recent':
                              return RecentSection(
                                key: ValueKey(sec.id),
                                title: sec.titleFor(lang),
                              );
                            default:
                              return const SizedBox.shrink();
                          }
                        },
                      ),
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
    for (final n in notes) {
      children.add(_Banner(
        icon: Icons.campaign_rounded,
        title: n.title,
        message: n.message,
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        onTap: n.url == null
            ? null
            : () => openFeedItem(
                  context,
                  n.title.isEmpty ? n.message : n.title,
                  n.url!,
                ),
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
