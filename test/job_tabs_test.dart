import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/feed/feed_repository.dart';
import 'package:app/core/feed/post_kind.dart';
import 'package:app/core/jobs/job_tabs.dart';
import 'package:app/widgets/post_feed.dart';

FeedItem _post(String title, {String? link, DateTime? modified}) =>
    FeedItem(id: title, title: title, link: link ?? 'https://saralbook.com/${title.hashCode}', modified: modified);

void main() {
  test('five tabs in the order the website owner asked for', () {
    expect(jobTabs.map((e) => e.id), ['latest', 'admit_card', 'answer_key', 'result', 'syllabus']);
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
}
