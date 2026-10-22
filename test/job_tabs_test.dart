import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/feed/feed_repository.dart';
import 'package:app/core/feed/post_kind.dart';
import 'package:app/core/jobs/job_categories.dart';
import 'package:app/core/jobs/job_tabs.dart';
import 'package:app/widgets/post_feed.dart';

FeedItem _post(String title, {String? link, DateTime? modified}) =>
    FeedItem(id: title, title: title, link: link ?? 'https://saralbook.com/${title.hashCode}', modified: modified);

void main() {
  test('six tabs in the order the website owner asked for', () {
    expect(jobTabs.map((e) => e.id), ['latest', 'admit_card', 'answer_key', 'result', 'admission', 'syllabus']);
    for (final tab in jobTabs) {
      expect(tab.title.of('hi'), isNotEmpty);
    }
    expect(jobTabById('result')?.id, 'result');
    expect(jobTabById('nope'), isNull);
    expect(jobTabById(null), isNull);
  });

  test('both websites are read', () {
    expect(jobSourceUrls.any((u) => u.contains('examjobalert.com')), isTrue);
    expect(jobSourceUrls.any((u) => u.contains('saralbook.com')), isTrue);
  });

  test('result: result / mark / merit list', () {
    expect(postKindOf('SSC CGL Result 2026 Declared'), PostKind.result);
    expect(postKindOf('UP Board Marks Released'), PostKind.result);
    expect(postKindOf('Railway Merit List Out'), PostKind.result);
    expect(postKindOf('Supermarket Manager Vacancy'), PostKind.job); // "mark" inside a word is not a mark
  });

  test('admit card: admit card / exam date / exam city / time table / interview letter', () {
    expect(postKindOf('IBPS PO Admit Card Out'), PostKind.admitCard);
    expect(postKindOf('NTA Exam Date Announced'), PostKind.admitCard);
    expect(postKindOf('SSC Exam City Details 2026'), PostKind.admitCard);
    expect(postKindOf('Board Time Table 2026'), PostKind.admitCard);
    expect(postKindOf('UPSC Interview Letter Released'), PostKind.admitCard);
    expect(postKindOf('Interview Letters for Clerks'), PostKind.admitCard);
  });

  test('latest job: online form / recruitment; answer key', () {
    expect(postKindOf('Bihar Police Online Form 2026'), PostKind.job);
    expect(postKindOf('Railway Recruitment 2026'), PostKind.job);
    expect(postKindOf('UP Police Answer Key Released'), PostKind.answerKey);
    expect(postKindOf('Study tips'), PostKind.other);
  });

  test('the first matching rule wins', () {
    expect(postKindOf('SSC Recruitment 2026 Admit Card'), PostKind.admitCard);
    expect(postKindOf('SSC Recruitment Answer Key and Result'), PostKind.answerKey);
    expect(postKindOf('SSC Recruitment Result'), PostKind.result);
  });

  test('each tab keeps only its own posts; Syllabus keeps all', () {
    final posts = [
      _post('Railway Recruitment 2026'),
      _post('IBPS PO Admit Card Out'),
      _post('UP Police Answer Key'),
      _post('NEET Result 2026'),
      _post('Daily current affairs'),
    ];
    List<String> inTab(String id) => [for (final p in posts) if (jobTabById(id)!.accepts(p)) p.title];
    expect(inTab('latest'), ['Railway Recruitment 2026']);
    expect(inTab('admit_card'), ['IBPS PO Admit Card Out']);
    expect(inTab('answer_key'), ['UP Police Answer Key']);
    expect(inTab('result'), ['NEET Result 2026']);
    expect(inTab('syllabus').length, posts.length);
  });

  test('posts of both sites are merged, newest edit first, no doubles', () {
    final a = _post('Old', link: 'https://saralbook.com/a', modified: DateTime(2026, 1, 1));
    final b = _post('New', link: 'https://examjobalert.com/b', modified: DateTime(2026, 6, 1));
    final dup = _post('Old again', link: 'https://saralbook.com/a', modified: DateTime(2026, 1, 1));
    final merged = mergePosts([
      [a],
      [b, dup],
    ]);
    expect(merged.map((e) => e.title), ['New', 'Old']);
  });

  test('a post edited much later than it was published is marked updated', () {
    final d = DateTime(2026, 10, 1, 9);
    expect(FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a', date: d, modified: d.add(const Duration(days: 2))).isUpdated, isTrue);
    expect(FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a', date: d, modified: d.add(const Duration(minutes: 20))).isUpdated, isFalse);
    expect(const FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a').isUpdated, isFalse);
  });

  test('each website has its own five category pages', () {
    expect(jobSites.first.id, 'examjobalert'); // shown first by default
    final exam = jobSites.first, saral = jobSites.last;
    expect(exam.slugs['admit_card'], 'admit-cards');
    expect(saral.slugs['admit_card'], 'admit-card');
    expect(exam.slugs['admission'], 'admission');
    expect(saral.slugs['admission'], 'admission-form');
    expect(jobSiteForUrl('https://examjobalert.com/wp-json/wp/v2/posts?per_page=6')?.id, 'examjobalert');
    expect(jobSiteForUrl('https://www.saralbook.com/x')?.id, 'saralbook');
    expect(jobSiteForUrl('https://example.com/x'), isNull);
  });

  test('category ids are read and turned into a post address', () {
    final ids = JobCategories.parseIds('[{"id":5,"slug":"latest-jobs"},{"id":9,"slug":"results"},{"id":"x","slug":"bad"}]');
    expect(ids, {'latest-jobs': 5, 'results': 9});
    final site = jobSites.first;
    final one = JobCategories.buildUrl(site, 'latest', ids)!;
    expect(one, contains('categories=5'));
    expect(one, contains('orderby=modified'));
    final all = JobCategories.buildUrl(site, 'syllabus', ids)!;
    expect(all, contains('categories=5,9'));
    expect(JobCategories.buildUrl(site, 'admit_card', ids), isNull);
    expect(JobCategories.parseIds('not json'), isEmpty);
  });

  test('newest published first when asked, so a re-edited old post stays low', () {
    final oldEdited = FeedItem(id: '1', title: 'Old', link: 'https://saralbook.com/o', date: DateTime(2025, 1, 1), modified: DateTime(2026, 10, 20));
    final fresh = FeedItem(id: '2', title: 'Fresh', link: 'https://saralbook.com/f', date: DateTime(2026, 10, 1), modified: DateTime(2026, 10, 1));
    expect(mergePosts([[oldEdited, fresh]], byEdit: false).map((e) => e.title), ['Fresh', 'Old']);
    expect(mergePosts([[oldEdited, fresh]]).map((e) => e.title), ['Old', 'Fresh']);
  });
}
