import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/scanner/scan_engine.dart';
import 'package:app/core/scanner/scan_page.dart';
import 'package:app/core/scanner/scan_store.dart';
import 'package:flutter_test/flutter_test.dart';

ScanPage _page(int seed, {int filter = 1, int rotation = 0}) => ScanPage(
      src: Uint8List.fromList([seed, seed + 1, seed + 2]),
      preview: Uint8List.fromList([seed, seed + 9]),
      width: 400 + seed,
      height: 600 + seed,
      quad: [0.1, 0.1, 0.9, 0.1, 0.9, 0.9, 0.1, 0.9],
      filter: filter,
      brightness: 12.5,
      contrast: -7,
      rotation: rotation,
    );

void main() {
  late Directory root;
  late ScanStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scanstore_test');
    store = ScanStore(Directory('${root.path}/user1'));
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('folder names are made safe', () {
    expect(ScanStore.safeFolder('a/b..c d'), 'a_b__c_d');
    expect(ScanStore.safeFolder(''), 'user');
    expect(ScanStore.safeFolder('AbC123_-'), 'AbC123_-');
  });

  test('every page gets its own key', () {
    expect(_page(1).key, isNot(_page(1).key));
  });

  test('a saved scan comes back with the same pages, order and edits', () async {
    final a = _page(1, filter: 2, rotation: 1);
    final b = _page(20, filter: 3, rotation: 3);
    await store.save(id: 's1', name: 'Fees', pages: [a, b], mode: 1, quality: 80);

    final back = await store.load('s1');
    expect(back, isNotNull);
    expect(back!.name, 'Fees');
    expect(back.mode, 1);
    expect(back.quality, 80);
    expect(back.pages.map((p) => p.key), [a.key, b.key]);
    expect(back.pages[0].src, a.src);
    expect(back.pages[1].preview, b.preview);
    expect(back.pages[0].filter, 2);
    expect(back.pages[0].rotation, 1);
    expect(back.pages[1].rotation, 3);
    expect(back.pages[0].brightness, 12.5);
    expect(back.pages[0].contrast, -7);
    expect(back.pages[0].quad.length, 8);
    expect(back.pages[0].width, 401);
  });

  test('re-ordering and removing pages is saved; removed pictures are deleted', () async {
    final a = _page(1);
    final b = _page(20);
    final c = _page(40);
    await store.save(id: 's1', name: 'x', pages: [a, b, c], mode: 0, quality: 90);

    await store.save(id: 's1', name: 'x', pages: [c, a], mode: 0, quality: 90);
    final back = await store.load('s1');
    expect(back!.pages.map((p) => p.key), [c.key, a.key]);

    final files = Directory('${store.root.path}/s1').listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
    expect(files.any((n) => n.startsWith(b.key)), isFalse);
    expect(files.contains('meta.json'), isTrue);
  });

  test('the list shows newest first with page count and size', () async {
    await store.save(id: 'old', name: 'Old', pages: [_page(1)], mode: 0, quality: 90);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.save(id: 'new', name: 'New', pages: [_page(5), _page(9)], mode: 0, quality: 90);

    final items = await store.list();
    expect(items.map((e) => e.id), ['new', 'old']);
    expect(items.first.pages, 2);
    expect(items.first.bytes, greaterThan(0));
    expect(items.first.cover, isNotNull);
  });

  test('saving no pages removes the scan; delete and deleteAll work', () async {
    await store.save(id: 's1', name: 'a', pages: [_page(1)], mode: 0, quality: 90);
    await store.save(id: 's2', name: 'b', pages: [_page(2)], mode: 0, quality: 90);
    expect(await store.exists('s1'), isTrue);

    await store.save(id: 's1', name: 'a', pages: [], mode: 0, quality: 90);
    expect(await store.exists('s1'), isFalse);

    await store.delete('s2');
    expect(await store.list(), isEmpty);

    await store.save(id: 's3', name: 'c', pages: [_page(3)], mode: 0, quality: 90);
    await store.deleteAll();
    expect(await store.list(), isEmpty);
    expect(await store.load('s3'), isNull);
  });

  test('damaged data does not crash: bad corners fall back to the full page', () async {
    await store.save(id: 's1', name: 'a', pages: [_page(1)], mode: 0, quality: 90);
    final meta = File('${store.root.path}/s1/meta.json');
    final text = (await meta.readAsString()).replaceFirst(RegExp(r'"quad":\[[^\]]*\]'), '"quad":[1,2]');
    await meta.writeAsString(text);
    final back = await store.load('s1');
    expect(back!.pages.first.quad, fullPageQuad());

    await meta.writeAsString('not json');
    expect(await store.load('s1'), isNull);
    expect(await store.list(), isEmpty);
  });
}
