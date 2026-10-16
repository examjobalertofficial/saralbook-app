import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/feed/feed_repository.dart';
import 'package:app/core/feed/post_kind.dart';
import 'package:app/core/jobs/job_tabs.dart';

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

  test('picks the busiest category whose name or slug matches', () {
    const body = '[{"id":5,"name":"Admit Card 2026","slug":"admit-card-2026","count":3},'
        '{"id":7,"name":"Admit Cards","slug":"admit-card","count":120},'
        '{"id":9,"name":"Results","slug":"results","count":50}]';
    expect(pickCategoryId(body, jobTabById('admit_card')!.keywords), 7);
    expect(pickCategoryId(body, jobTabById('result')!.keywords), 9);
    expect(pickCategoryId(body, jobTabById('syllabus')!.keywords), isNull);
    expect(pickCategoryId('not json', const ['result']), isNull);
    expect(pickCategoryId('{"a":1}', const ['result']), isNull);
    expect(pickCategoryId(body, const []), isNull);
  });

  test('post kind is worked out from the title', () {
    expect(postKindOf('SSC CGL Admit Card 2026 Out'), PostKind.admitCard);
    expect(postKindOf('UP Police Answer Key Released'), PostKind.answerKey);
    expect(postKindOf('RRB NTPC Result Declared'), PostKind.result);
    expect(postKindOf('IBPS PO Syllabus and Exam Pattern'), PostKind.syllabus);
    expect(postKindOf('Railway Recruitment 2026: 5000 Vacancies'), PostKind.job);
    expect(postKindOf('Study tips for the week'), PostKind.other);
    for (final k in PostKind.values) {
      expect(postKindStyles[k], isNotNull);
    }
  });

  test('a post edited much later than it was published is marked updated', () {
    final d = DateTime(2026, 10, 1, 9);
    expect(FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a', date: d, modified: d.add(const Duration(days: 2))).isUpdated, isTrue);
    expect(FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a', date: d, modified: d.add(const Duration(minutes: 20))).isUpdated, isFalse);
    expect(const FeedItem(id: '1', title: 'x', link: 'https://saralbook.com/a').isUpdated, isFalse);
  });
}
