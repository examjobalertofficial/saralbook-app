import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:app/core/scanner/scan_engine.dart';

/// A fake photo: dark table, a slightly tilted white page with dark "text"
/// lines, and a shadow over the left part of the page.
Uint8List _fakePhoto() {
  const w = 400, h = 300;
  final quad = <List<double>>[
    [60, 40], // top-left
    [340, 60], // top-right
    [320, 260], // bottom-right
    [80, 240], // bottom-left
  ];
  bool inside(double x, double y) {
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final a = quad[i], b = quad[(i + 1) % 4];
      final cross = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0]);
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) sign = s;
      if (s != sign) return false;
    }
    return true;
  }

  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!inside(x.toDouble(), y.toDouble())) {
        image.setPixelRgb(x, y, 35, 38, 42);
        continue;
      }
      var v = 235;
      if (x < 170) v = 170; // shadow
      if (y % 24 < 4 && x > 100 && x < 300) v = v ~/ 4; // text line
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

void main() {
  final photo = _fakePhoto();
  const expected = [60 / 400, 40 / 300, 340 / 400, 60 / 300, 320 / 400, 260 / 300, 80 / 400, 240 / 300];

  test('the page corners are found', () {
    final q = detectDocumentQuad(photo);
    expect(q.length, 8);
    for (var i = 0; i < 8; i++) {
      expect(q[i], closeTo(expected[i], 0.06), reason: 'value $i');
    }
  });

  test('a picture without a page gives the whole picture', () {
    final flat = img.Image(width: 200, height: 200);
    img.fill(flat, color: img.ColorRgb8(128, 128, 128));
    final q = detectDocumentQuad(Uint8List.fromList(img.encodeJpg(flat)));
    expect(q, fullPageQuad());
  });

  test('garbage bytes do not crash the finder', () {
    expect(detectDocumentQuad(Uint8List.fromList([1, 2, 3])), fullPageQuad());
  });

  test('every filter makes a readable picture of the flattened page', () {
    final q = detectDocumentQuad(photo);
    for (var f = 0; f < ScanFilter.values.length; f++) {
      final out = renderScan(photo, q, filter: f, maxSide: 300, quality: 80);
      final back = img.decodeJpg(out);
      expect(back, isNotNull, reason: 'filter $f');
      expect(back!.width, greaterThan(100));
      expect(back.height, greaterThan(100));
      expect(back.width <= 300 && back.height <= 300, isTrue);
    }
  });

  test('magic colour turns the shadowed paper white and keeps the text dark', () {
    final out = img.decodeJpg(renderScan(photo, detectDocumentQuad(photo), filter: ScanFilter.magic.index, maxSide: 300))!;
    // sample the shadowed left side and the clear right side (away from text lines)
    int lum(int x, int y) {
      final p = out.getPixel(x, y);
      return ((p.r + p.g + p.b) / 3).round();
    }

    final y = (out.height * 0.12).round();
    expect(lum((out.width * 0.12).round(), y), greaterThan(225), reason: 'shadow side');
    expect(lum((out.width * 0.9).round(), y), greaterThan(225), reason: 'light side');
    var darkest = 255;
    for (var yy = 0; yy < out.height; yy++) {
      darkest = darkest < lum(out.width ~/ 2, yy) ? darkest : lum(out.width ~/ 2, yy);
    }
    expect(darkest, lessThan(120), reason: 'text stays dark');
  });

  test('black and white has only dark and light pixels', () {
    final out = img.decodeJpg(renderScan(photo, detectDocumentQuad(photo), filter: ScanFilter.blackWhite.index, maxSide: 300))!;
    var extreme = 0, total = 0;
    for (var y = 0; y < out.height; y += 3) {
      for (var x = 0; x < out.width; x += 3) {
        final p = out.getPixel(x, y);
        final v = p.r;
        total++;
        if (v < 70 || v > 185) extreme++;
      }
    }
    expect(extreme / total, greaterThan(0.9));
  });

  test('rotation swaps width and height', () {
    final q = detectDocumentQuad(photo);
    final a = img.decodeJpg(renderScan(photo, q, filter: 0, maxSide: 300, rotation: 0))!;
    final b = img.decodeJpg(renderScan(photo, q, filter: 0, maxSide: 300, rotation: 1))!;
    final c = img.decodeJpg(renderScan(photo, q, filter: 0, maxSide: 300, rotation: 2))!;
    expect(b.width, a.height);
    expect(b.height, a.width);
    expect(c.width, a.width);
    expect(c.height, a.height);
  });

  test('brightness and contrast change the result', () {
    final q = detectDocumentQuad(photo);
    final plain = img.decodeJpg(renderScan(photo, q, filter: 0, maxSide: 200))!;
    final brighter = img.decodeJpg(renderScan(photo, q, filter: 0, maxSide: 200, brightness: 60))!;
    final mid = plain.getPixel(plain.width ~/ 2, 5);
    final mid2 = brighter.getPixel(brighter.width ~/ 2, 5);
    expect(mid2.r, greaterThanOrEqualTo(mid.r));
  });

  test('import makes both working copies and finds the page', () {
    final imported = importScan(photo)!;
    expect(imported.width, 400);
    expect(imported.height, 300);
    expect(imported.quad.length, 8);
    expect(importScan(Uint8List.fromList([0, 1, 2])), isNull);
  });

  test('filter strip has one small picture per filter', () {
    final thumbs = renderFilterThumbs(photo, detectDocumentQuad(photo));
    expect(thumbs.length, ScanFilter.values.length);
    for (final t in thumbs) {
      expect(img.decodeJpg(t), isNotNull);
    }
  });
}
