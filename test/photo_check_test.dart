import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/files/image_ops.dart';
import 'package:app/core/tools/files/photo_check.dart';

void main() {
  const facts = PhotoFacts(200, 230, 40 * 1024, ImageFormat.jpeg);

  test('passes when everything matches', () {
    final r = checkPhoto(
      const PhotoSpec(width: 200, height: 230, minKb: 20, maxKb: 50, format: ImageFormat.jpeg),
      facts,
    );
    expect(r.length, 4);
    expect(allChecksPass(r), isTrue);
  });

  test('reports each failing rule', () {
    final r = checkPhoto(
      const PhotoSpec(width: 100, height: 230, minKb: 45, maxKb: 30, format: ImageFormat.png),
      facts,
    );
    expect(r.map((e) => e.ok).toList(), [false, false, false, false]);
    expect(allChecksPass(r), isFalse);
    expect(r.first.actual, '200×230 px');
    expect(r.first.required, '100×230 px');
  });

  test('only checks what the form asks for', () {
    final r = checkPhoto(const PhotoSpec(maxKb: 50), facts);
    expect(r.map((e) => e.kind).toList(), [CheckKind.maxSize, CheckKind.format]);
    expect(allChecksPass(r), isTrue);
  });

  test('width only', () {
    expect(allChecksPass(checkPhoto(const PhotoSpec(width: 200), facts)), isTrue);
    expect(allChecksPass(checkPhoto(const PhotoSpec(width: 201), facts)), isFalse);
  });

  test('unknown formats fail the default JPG/PNG check', () {
    const odd = PhotoFacts(10, 10, 1000, ImageFormat.webp);
    expect(allChecksPass(checkPhoto(const PhotoSpec(), odd)), isFalse);
  });
}
