import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/pdfedit/edit_model.dart';

void main() {
  test('clamp01 keeps values inside the page', () {
    expect(clamp01(-0.5), 0.0);
    expect(clamp01(0.4), 0.4);
    expect(clamp01(3), 1.0);
    expect(clamp01(double.nan), 0.0);
  });

  test('a rectangle can be dragged in any direction and stays on the page', () {
    final a = rectFromCorners(0.2, 0.3, 0.6, 0.5);
    expect((a.x, a.y), (0.2, 0.3));
    expect(a.w, closeTo(0.4, 1e-9));
    expect(a.h, closeTo(0.2, 1e-9));

    final b = rectFromCorners(0.6, 0.5, 0.2, 0.3); // opposite corner first
    expect((b.x, b.y), (0.2, 0.3));
    expect(b.w, closeTo(0.4, 1e-9));

    final c = rectFromCorners(-1, -1, 2, 2);
    expect((c.x, c.y, c.w, c.h), (0.0, 0.0, 1.0, 1.0));
  });

  test('pages can be moved and page numbers start where asked', () {
    final list = ['a', 'b', 'c', 'd'];
    moveInList(list, 0, 2);
    expect(list, ['b', 'c', 'a', 'd']);
    moveInList(list, 3, 0);
    expect(list, ['d', 'b', 'c', 'a']);
    moveInList(list, 9, 0); // out of range: nothing happens
    expect(list, ['d', 'b', 'c', 'a']);
    expect(pageNumberText(0, 1), '1');
    expect(pageNumberText(4, 10), '14');
  });

  test('items and pages get their own ids and keep their sizes', () {
    final t1 = TextItem(text: 'Hello', x: 0.1, y: 0.2);
    final t2 = TextItem(text: 'नमस्ते', x: 0.1, y: 0.2);
    expect(t1.id, isNot(t2.id));
    final page = EditPage(base: Uint8List(3), width: 1240, height: 1754);
    expect(page.aspect, closeTo(1240 / 1754, 1e-9));
    expect(page.hasEdits, isFalse);
    page.items.add(t1);
    expect(page.hasEdits, isTrue);
    final ink = InkItem(points: [0.1, 0.1, 0.2, 0.2], color: 0xFF000000, width: 0.006);
    expect(ink.highlight, isFalse);
    final pic = PictureItem(bytes: Uint8List(1), x: 0.1, y: 0.1, w: 0.3, aspect: 2);
    expect(pic.w, 0.3);
  });
}
