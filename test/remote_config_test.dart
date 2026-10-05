import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/remote_config.dart';

void main() {
  test('defaults contain all five websites and the built-in sections', () {
    final c = AppRemoteConfig.defaults();
    expect(c.sites.length, 5);
    expect(c.sections.first.type, 'platforms');
    expect(c.maintenance.enabled, isFalse);
  });

  test('invalid JSON returns null instead of throwing', () {
    expect(AppRemoteConfig.tryParse('not json'), isNull);
    expect(AppRemoteConfig.tryParse('[1,2]'), isNull);
  });

  test('empty object keeps defaults', () {
    final c = AppRemoteConfig.tryParse('{}')!;
    expect(c.sites.length, 5);
    expect(c.sections.length, AppRemoteConfig.defaultSections.length);
  });

  test('a service can be switched off with a message', () {
    final c = AppRemoteConfig.tryParse(jsonEncode({
      'services': {
        'saralbookstore': {'enabled': false, 'message': 'Store is being upgraded'},
      },
    }))!;
    final store = c.siteById('saralbookstore')!;
    expect(store.enabled, isFalse);
    expect(store.unavailableMessage, 'Store is being upgraded');
    expect(c.siteById('examjobalert')!.enabled, isTrue);
  });

  test('service URL override is accepted only for allowed domains', () {
    final good = AppRemoteConfig.tryParse(jsonEncode({
      'services': {'saralbooktest': {'url': 'https://exam.saralbook.com/'}},
    }))!;
    expect(good.siteById('saralbooktest')!.url, 'https://exam.saralbook.com/');

    final bad = AppRemoteConfig.tryParse(jsonEncode({
      'services': {'saralbooktest': {'url': 'https://evil.example/'}},
    }))!;
    expect(bad.siteById('saralbooktest')!.url, 'https://test.saralbook.com/');
  });

  test('sections: valid kept, unsafe/unknown/duplicate dropped', () {
    final c = AppRemoteConfig.tryParse(jsonEncode({
      'sections': [
        {'id': 'jobs', 'type': 'feed', 'title': 'Jobs',
         'feedUrl': 'https://examjobalert.com/wp-json/wp/v2/posts?categories=3'},
        {'id': 'bad', 'type': 'feed', 'feedUrl': 'https://evil.example/feed'},
        {'id': 'future', 'type': 'hologram'},
        {'id': 'jobs', 'type': 'platforms'},
        {'id': 'off', 'type': 'recent', 'enabled': false},
        {'id': 'Bad Id!', 'type': 'recent'},
        {'id': 'recent', 'type': 'recent'},
      ],
    }))!;
    expect(c.sections.map((s) => s.id).toList(), ['jobs', 'recent']);
  });

  test('announcement links must be safe; max three kept', () {
    final c = AppRemoteConfig.tryParse(jsonEncode({
      'announcements': [
        {'title': 'A', 'url': 'https://saralbook.com/a'},
        {'title': 'B', 'url': 'https://evil.example/b'},
        {'title': 'C'}, {'title': 'D'},
      ],
    }))!;
    expect(c.announcements.length, 3);
    expect(c.announcements[0].url, 'https://saralbook.com/a');
    expect(c.announcements[1].url, isNull);
  });

  test('Hindi title is used only for Hindi', () {
    const s = HomeSection(id: 'x', type: 'feed', title: 'Jobs', titleHi: 'नौकरियां');
    expect(s.titleFor('en'), 'Jobs');
    expect(s.titleFor('hi'), 'नौकरियां');
  });
}
