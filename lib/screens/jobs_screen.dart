import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/config/remote_config.dart';
import '../core/l10n/app_strings.dart';
import '../utils/navigation.dart';
import '../widgets/job_alerts_card.dart';
import '../widgets/page_body.dart';
import '../widgets/website_card.dart';
import 'home/feed_section.dart';

/// The post lists of the Exam Job Alert website (latest jobs, admit cards,
/// results...) taken from the Home sections you set up in WordPress, so the
/// Jobs tab follows the website without a new APK.
List<HomeSection> jobFeedSections(List<HomeSection> all) {
  bool isJobSite(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    return host == 'examjobalert.com' || host.endsWith('.examjobalert.com');
  }

  return [
    for (final sec in all)
      if (sec.type == 'feed' && isJobSite(sec.feedUrl)) sec,
  ];
}

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = AppScope.of(context).config;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.jobsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: config,
          builder: (context, _) {
            final feeds = jobFeedSections(config.sections);
            final sites = config.sitesByIds(const ['examjobalert']);
            return RefreshIndicator(
              onRefresh: () => config.refresh(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      s.jobsSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const JobAlertsCard(),
                  const SizedBox(height: 18),
                  for (final sec in feeds)
                    FeedSection(
                      key: ValueKey('jobs_${sec.id}'),
                      section: sec,
                      refreshToken: config.refreshToken,
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
