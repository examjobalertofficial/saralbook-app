import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../utils/navigation.dart';
import '../../widgets/coming_soon_card.dart';
import '../../widgets/page_body.dart';
import '../../widgets/website_card.dart';

/// A tab that lists some of the SaralBook websites plus a note about the
/// native features that arrive in later updates. Used by Study, Jobs, Tools.
class PlatformTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> siteIds;
  final String comingSoon;

  /// Optional widget shown above the "coming soon" note (e.g. sign-in prompt).
  final Widget? extra;

  const PlatformTab({
    super.key,
    required this.title,
    required this.subtitle,
    required this.siteIds,
    required this.comingSoon,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = AppScope.of(context).config;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: config,
          builder: (context, _) {
            final sites = config.sitesByIds(siteIds);
            return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            for (var i = 0; i < sites.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: WebsiteCard(
                  site: sites[i],
                  index: i,
                  onOpen: () => openWebsite(context, sites[i]),
                ),
              ),
            if (extra != null) extra!,
            ComingSoonCard(message: comingSoon),
          ],
            );
          },
        ),
      ),
    );
  }
}
