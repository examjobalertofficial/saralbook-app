import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:app/core/tools/files/image_ops.dart';

/// A noisy picture, so JPEG size really depends on quality and dimensions.
img.Image _noisy(int w, int h, {int seed = 1}) {
  final rnd = math.Random(seed);
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p
      ..r = rnd.nextInt(256)
      ..g = rnd.nextInt(256)
      ..b = rnd.nextInt(256);
  }
  return image;
}

void main() {
  test('detectFormat recognises JPEG and PNG', () {
    final image = _noisy(8, 8);
    expect(detectFormat(encodeJpeg(image, 80)), ImageFormat.jpeg);
    expect(detectFormat(encodePngBytes(image)), ImageFormat.png);
    expect(detectFormat(Uint8List.fromList([1, 2, 3, 4])), ImageFormat.unknown);
  });

  test('readImageSize reads dimensions without full decode', () {
    final s = readImageSize(encodeJpeg(_noisy(64, 32), 80))!;
    expect((s.width, s.height), (64, 32));
    expect(readImageSize(Uint8List.fromList([0, 1, 2])), isNull);
  });

  test('decodeOriented returns null for junk and flattens transparency on white', () {
    expect(decodeOriented(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9])), isNull);

    final clear = img.Image(width: 4, height: 4, numChannels: 4); // fully transparent
    final decoded = decodeOriented(encodePngBytes(clear))!;
    final px = decoded.getPixel(1, 1);
    expect((px.r, px.g, px.b), (255, 255, 255));
  });

  test('resize exact and keep ratio', () {
    final image = _noisy(200, 100);
    final a = resizeExact(image, 50, 80);
    expect((a.width, a.height), (50, 80));
    final b = resizeKeepRatio(image, width: 100);
    expect((b.width, b.height), (100, 50));
    final c = resizeKeepRatio(image, height: 25);
    expect((c.width, c.height), (50, 25));
    expect(identical(resizeKeepRatio(image), image), isTrue);
  });

  test('crop is clamped to the picture', () {
    final image = _noisy(100, 80);
    final c = cropRect(image, 90, 70, 50, 50);
    expect((c.width, c.height), (10, 10));
    final d = cropRect(image, -5, -5, 20, 20);
    expect((d.width, d.height), (20, 20));
  });

  test('compressToTarget: meets the target by lowering quality', () {
    final image = _noisy(300, 300);
    final big = encodeJpeg(image, 95).length;
    final target = (big * 0.5).round();
    final r = compressToTarget(image, target);
    expect(r.metTarget, isTrue);
    expect(r.bytes.length, lessThanOrEqualTo(target));
    expect(r.quality, lessThan(95));
    expect(r.width, 300);
  });

  test('compressToTarget: shrinks the picture when quality alone is not enough', () {
    final image = _noisy(300, 300);
    final tiny = (encodeJpeg(image, 30).length * 0.4).round();
    final r = compressToTarget(image, tiny);
    expect(r.width, lessThan(300));
    if (r.metTarget) expect(r.bytes.length, lessThanOrEqualTo(tiny));
  });

  test('compressToTarget: already small enough is returned at best quality', () {
    final image = _noisy(40, 40);
    final r = compressToTarget(image, 10 * 1024 * 1024);
    expect(r.metTarget, isTrue);
    expect(r.quality, 95);
  });

  test('compressToTarget: impossible target reports metTarget=false, never loops forever', () {
    final r = compressToTarget(_noisy(200, 200), 50);
    expect(r.metTarget, isFalse);
    expect(r.bytes, isNotEmpty);
  });

  test('prepareForUploadAsync: crop, exact size and size limit together', () async {
    final src = encodeJpeg(_noisy(400, 300), 90);
    final r = (await prepareForUploadAsync(
      src,
      maxBytes: 20 * 1024,
      crop: (x: 50, y: 0, w: 300, h: 300),
      width: 100,
      height: 100,
      exactSize: true,
    ))!;
    expect((r.width, r.height), (100, 100));
    expect(r.bytes.length, lessThanOrEqualTo(20 * 1024));
    final back = img.decodeJpg(r.bytes)!;
    expect((back.width, back.height), (100, 100));
  });

  test('sheet layout for common passport sizes', () {
    // 35x45 mm @300 dpi = 413x531 px on a 4x6 inch sheet (1200x1800 px)
    final l = sheetLayout(sheetW: 1200, sheetH: 1800, photoW: 413, photoH: 531);
    expect((l.cols, l.rows, l.capacity), (2, 3, 6));
    final a4 = sheetLayout(sheetW: 2480, sheetH: 3508, photoW: 413, photoH: 531);
    expect(a4.capacity, greaterThanOrEqualTo(25));
    expect(sheetLayout(sheetW: 100, sheetH: 100, photoW: 413, photoH: 531).capacity, 0);
  });

  test('buildPhotoSheet places the requested copies (up to capacity)', () {
    final photo = _noisy(413, 531);
    final r = buildPhotoSheet(photo, sheetW: 1200, sheetH: 1800, copies: 4);
    expect(r.placed, 4);
    final sheet = img.decodeJpg(r.bytes)!;
    expect((sheet.width, sheet.height), (1200, 1800));
    expect(buildPhotoSheet(photo, sheetW: 1200, sheetH: 1800, copies: 50).placed, 6);
    expect(buildPhotoSheet(photo, sheetW: 100, sheetH: 100, copies: 3).placed, 0);
  });

  test('fitOnPage keeps the picture inside the margin on a white page', () {
    final page = fitOnPage(_noisy(1000, 500), 600, 800, margin: 30);
    expect((page.width, page.height), (600, 800));
    final corner = page.getPixel(5, 5);
    expect((corner.r, corner.g, corner.b), (255, 255, 255));
  });

  test('encodeBgraPixels converts BGRA to a decodable picture', () {
    // one red pixel in BGRA order: B=0,G=0,R=255,A=255
    final pixels = Uint8List.fromList([0, 0, 255, 255]);
    final png = encodeBgraPixels(pixels, 1, 1, png: true);
    final back = img.decodePng(png)!;
    final p = back.getPixel(0, 0);
    expect((p.r, p.g, p.b), (255, 0, 0));
  });
}
