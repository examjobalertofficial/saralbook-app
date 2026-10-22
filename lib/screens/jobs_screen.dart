import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/config/remote_config.dart';
import '../core/jobs/job_categories.dart';
import '../core/jobs/job_tabs.dart';
import '../core/l10n/app_strings.dart';
import '../utils/navigation.dart';
import '../widgets/animations.dart';
import '../widgets/job_alerts_card.dart';
import '../widgets/page_body.dart';
import '../widgets/post_feed.dart';
import '../widgets/tr.dart';
import '../widgets/website_card.dart';
import '../widgets/youtube_card.dart';

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

/// The Jobs tab: filter chips (Latest Jobs, Admit Card, Answer Key, Result,
/// Syllabus) over the posts of our own website, newest edit first.
class JobsScreen extends StatefulWidget {
  /// Tab id to open (from Home shortcuts), e.g. `result`.
  final String? initialTab;
  const JobsScreen({super.key, this.initialTab});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late JobTab _tab = jobTabById(widget.initialTab) ?? jobTabs.first;
  // ExamJobAlert first; the switch at the top changes the website.
  JobSite _site = jobSites.first;
  int _refresh = 0;

  @override
  void didUpdateWidget(JobsScreen old) {
    super.didUpdateWidget(old);
    final wanted = jobTabById(widget.initialTab);
    if (widget.initialTab != old.initialTab && wanted != null) {
      setState(() => _tab = wanted);
    }
  }

  Future<void> _pull() async {
    final config = AppScope.of(context).config;
    await config.refresh(force: true);
    if (mounted) setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = AppScope.of(context).config;
    final sites = config.sitesByIds(const ['examjobalert']);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.jobsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final site in jobSites) ButtonSegment<String>(value: site.id, label: Text(site.name)),
                  ],
                  selected: {_site.id},
                  onSelectionChanged: (v) => setState(() {
                    _site = jobSites.firstWhere((e) => e.id == v.first);
                  }),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: jobTabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final tab = jobTabs[i];
                  final on = tab.id == _tab.id;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: on ? tab.color : tab.color.withAlpha(30),
                      boxShadow: on ? [BoxShadow(color: tab.color.withAlpha(90), blurRadius: 10, offset: const Offset(0, 3))] : null,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => setState(() => _tab = tab),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(tab.icon, size: 18, color: on ? Colors.white : tab.color),
                              const SizedBox(width: 6),
                              Text(
                                tr(context, tab.title),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: on ? Colors.white : tab.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _pull,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    const JobAlertsCard(),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey('${_site.id}_${_tab.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PostFeed(
                            key: ValueKey('jobs_${_site.id}_${_tab.id}'),
                            urls: [_site.postsUrl],
                            scopeTab: _tab.id,
                            refreshToken: _refresh,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const YoutubeCard(),
                    const SizedBox(height: 14),
                    for (var i = 0; i < sites.length; i++)
                      FadeSlideIn(
                        child: WebsiteCard(
                          site: sites[i],
                          index: i,
                          onOpen: () => openWebsite(context, sites[i]),
                        ),
                      ),
                    if (sites.isEmpty) Center(child: Text(s.jobsSubtitle, style: TextStyle(color: scheme.onSurfaceVariant))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
