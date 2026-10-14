import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/remote_config.dart';
import 'package:app/screens/jobs_screen.dart';

void main() {
  const jobs = HomeSection(
    id: 'latest_jobs',
    type: 'feed',
    title: 'Latest Jobs',
    feedUrl: 'https://examjobalert.com/wp-json/wp/v2/posts?per_page=6',
  );
  const admit = HomeSection(
    id: 'admit',
    type: 'feed',
    title: 'Admit Cards',
    feedUrl: 'https://examjobalert.com/wp-json/wp/v2/posts?categories=12',
  );
  const other = HomeSection(
    id: 'saralbook_updates',
    type: 'feed',
    title: 'From SaralBook',
    feedUrl: 'https://saralbook.com/wp-json/wp/v2/posts?per_page=6',
  );
  const platforms = HomeSection(id: 'platforms', type: 'platforms');

  test('the Jobs tab takes only the Exam Job Alert post lists, in the order set in WordPress', () {
    final out = jobFeedSections([platforms, jobs, other, admit]);
    expect(out.map((e) => e.id).toList(), ['latest_jobs', 'admit']);
  });

  test('nothing for the Jobs tab when no job list is set up', () {
    expect(jobFeedSections([platforms, other]), isEmpty);
    expect(jobFeedSections(const []), isEmpty);
  });

  test('look-alike addresses are not accepted', () {
    const fake = HomeSection(
      id: 'fake',
      type: 'feed',
      feedUrl: 'https://examjobalert.com.evil.com/wp-json/wp/v2/posts',
    );
    const bad = HomeSection(id: 'bad', type: 'feed', feedUrl: 'not a url');
    expect(jobFeedSections([fake, bad]), isEmpty);
  });
}
