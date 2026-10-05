import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/cache/cache_store.dart';
import 'package:app/core/feed/feed_repository.dart';

const _url = 'https://examjobalert.com/wp-json/wp/v2/posts?per_page=3';

String _body() => jsonEncode([
      {
        'id': 1,
        'title': {'rendered': 'SSC &amp; Railway &#8211; Result'},
        'link': 'https://examjobalert.com/ssc-result/',
        'date': '2026-10-01T10:00:00',
      },
      {
        'id': 2,
        'title': {'rendered': 'Evil'},
        'link': 'https://evil.example/x',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheStore cache;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 2, 12);
    cache = CacheStore(await SharedPreferences.getInstance(), now: () => now);
  });

  test('cache returns fresh data, hides old data, and can be cleared', () async {
    await cache.put('k', 'hello');
    expect(cache.get('k', maxAge: const Duration(hours: 1)), 'hello');
    now = now.add(const Duration(hours: 2));
    expect(cache.get('k', maxAge: const Duration(hours: 1)), isNull);
    await cache.clear();
    expect(cache.read('k'), isNull);
    expect(cache.entryCount, 0);
  });

  test('cache evicts the oldest entries beyond the limit', () async {
    for (var i = 0; i < CacheStore.maxEntries + 5; i++) {
      await cache.put('k$i', 'v');
    }
    expect(cache.entryCount, CacheStore.maxEntries);
    expect(cache.read('k0'), isNull);
    expect(cache.read('k${CacheStore.maxEntries + 4}'), isNotNull);
  });

  test('decodeHtml handles tags and entities', () {
    expect(decodeHtml('A &amp; B &#8211; <b>C</b>'), 'A & B – C');
  });

  test('parseFeed decodes titles and drops unsafe links', () {
    final items = parseFeed(_body());
    expect(items.length, 1);
    expect(items.first.title, 'SSC & Railway – Result');
    expect(items.first.dateLabel, '01 Oct 2026');
  });

  test('network success is returned and saved', () async {
    final repo = FeedRepository(
      cache,
      client: MockClient((_) async => http.Response(_body(), 200)),
      isOnline: () async => true,
    );
    final r = await repo.load(_url);
    expect(r.items.length, 1);
    expect(r.fromSavedCopy, isFalse);
  });

  test('offline with a recent saved copy shows it, marked as saved', () async {
    final ok = FeedRepository(
      cache,
      client: MockClient((_) async => http.Response(_body(), 200)),
      isOnline: () async => true,
    );
    await ok.load(_url);
    now = now.add(const Duration(hours: 5)); // older than fresh, newer than 24h

    final offline = FeedRepository(
      cache,
      client: MockClient((_) async => throw http.ClientException('down')),
      isOnline: () async => false,
    );
    final r = await offline.load(_url);
    expect(r.fromSavedCopy, isTrue);
    expect(r.items.length, 1);
  });

  test('saved copy older than 24 hours is never shown', () async {
    final ok = FeedRepository(
      cache,
      client: MockClient((_) async => http.Response(_body(), 200)),
      isOnline: () async => true,
    );
    await ok.load(_url);
    now = now.add(const Duration(hours: 30));

    final offline = FeedRepository(
      cache,
      client: MockClient((_) async => throw http.ClientException('down')),
      isOnline: () async => false,
    );
    expect(
      () => offline.load(_url),
      throwsA(isA<FeedFailure>().having((f) => f.offline, 'offline', true)),
    );
  });

  test('server error with no saved copy is a non-offline failure', () async {
    final repo = FeedRepository(
      cache,
      client: MockClient((_) async => http.Response('oops', 500)),
      isOnline: () async => true,
    );
    expect(
      () => repo.load(_url),
      throwsA(isA<FeedFailure>().having((f) => f.offline, 'offline', false)),
    );
  });

  test('feed addresses outside the allowed domains are refused', () {
    final repo = FeedRepository(cache, isOnline: () async => true);
    expect(
      () => repo.load('https://evil.example/feed'),
      throwsA(isA<FeedFailure>()),
    );
  });
}
