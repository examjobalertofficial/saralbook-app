import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Image maths used by the offline tools. Everything here is pure Dart (no
/// Flutter, no network). The `*Async` versions run on a background isolate so
/// the app stays smooth with big photos.

/// Photos above this many pixels are refused to avoid running out of memory.
const int maxImagePixels = 40 * 1000 * 1000;

enum ImageFormat { jpeg, png, webp, unknown }

ImageFormat detectFormat(Uint8List b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return ImageFormat.jpeg;
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return ImageFormat.png;
  }
  if (b.length > 12 &&
      b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return ImageFormat.webp;
  }
  return ImageFormat.unknown;
}

class ImageSize {
  final int width;
  final int height;
  const ImageSize(this.width, this.height);
}

/// Reads width/height without decoding the whole picture. Null if unreadable.
ImageSize? readImageSize(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return ImageSize(info.width, info.height);
  } catch (_) {
    return null;
  }
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException();
}

/// Decodes, fixes phone-camera rotation and flattens transparency onto white.
/// Returns null if the bytes are not a readable image.
img.Image? decodeOriented(Uint8List bytes) {
  final size = readImageSize(bytes);
  if (size == null) return null;
  if (size.width * size.height > maxImagePixels) {
    throw const ImageTooLargeException();
  }
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  image = img.bakeOrientation(image);
  if (image.hasAlpha) {
    final base = img.Image(width: image.width, height: image.height);
    img.fill(base, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(base, image);
    image = base;
  }
  return image;
}

Uint8List encodeJpeg(img.Image image, int quality) => img.encodeJpg(
      image,
      quality: quality.clamp(1, 100),
      chroma: img.JpegChroma.yuv420, // smaller files, same visible quality
    );

Uint8List encodePngBytes(img.Image image) => img.encodePng(image, level: 9);

img.Image resizeExact(img.Image image, int width, int height) => img.copyResize(
      image,
      width: width,
      height: height,
      maintainAspect: false,
      interpolation: img.Interpolation.average,
    );

/// Resize to [width] and/or [height]; if only one is given the other follows
/// the aspect ratio.
img.Image resizeKeepRatio(img.Image image, {int? width, int? height}) {
  if (width == null && height == null) return image;
  final w = width ?? (height! * image.width / image.height).round();
  final h = height ?? (width! * image.height / image.width).round();
  return resizeExact(image, math.max(1, w), math.max(1, h));
}

img.Image cropRect(img.Image image, int x, int y, int w, int h) {
  final cx = x.clamp(0, image.width - 1);
  final cy = y.clamp(0, image.height - 1);
  final cw = w.clamp(1, image.width - cx);
  final ch = h.clamp(1, image.height - cy);
  return img.copyCrop(image, x: cx, y: cy, width: cw, height: ch);
}

class CompressResult {
  final Uint8List bytes;
  final int quality;
  final int width;
  final int height;

  /// false when even the smallest allowed result is above the target.
  final bool metTarget;
  const CompressResult(this.bytes, this.quality, this.width, this.height, this.metTarget);
}

/// Smallest-loss JPEG that is at most [maxBytes]: first lowers quality, then
/// (if still too big) shrinks the picture a little at a time.
CompressResult compressToTarget(
  img.Image image,
  int maxBytes, {
  int minQuality = 30,
  int maxQuality = 95,
  double minScale = 0.35,
}) {
  var current = image;
  var scale = 1.0;
  Uint8List? best;
  while (true) {
    // 1. does the best quality already fit?
    final top = encodeJpeg(current, maxQuality);
    if (top.length <= maxBytes) {
      return CompressResult(top, maxQuality, current.width, current.height, true);
    }
    // 2. binary search between minQuality and maxQuality
    var lo = minQuality;
    var hi = maxQuality;
    var fitQ = minQuality;
    final smallest = encodeJpeg(current, minQuality);
    best = smallest;
    if (smallest.length <= maxBytes) {
      var fit = smallest;
      while (lo < hi - 1) {
        final mid = (lo + hi) ~/ 2;
        final data = encodeJpeg(current, mid);
        if (data.length <= maxBytes) {
          fit = data;
          fitQ = mid;
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return CompressResult(fit, fitQ, current.width, current.height, true);
    }
    // 3. still too big: shrink and try again
    scale *= 0.85;
    if (scale < minScale) {
      return CompressResult(best, minQuality, current.width, current.height, false);
    }
    current = resizeExact(
      image,
      math.max(1, (image.width * scale).round()),
      math.max(1, (image.height * scale).round()),
    );
  }
}

// ---------------- passport / print sheets ----------------

class SheetLayout {
  final int cols;
  final int rows;
  const SheetLayout(this.cols, this.rows);
  int get capacity => cols * rows;
}

SheetLayout sheetLayout({
  required int sheetW,
  required int sheetH,
  required int photoW,
  required int photoH,
  int gap = 20,
  int margin = 30,
}) {
  final cols = math.max(0, (sheetW - 2 * margin + gap) ~/ (photoW + gap));
  final rows = math.max(0, (sheetH - 2 * margin + gap) ~/ (photoH + gap));
  return SheetLayout(cols, rows);
}

/// Places [copies] of [photo] on a white sheet (as many as fit).
/// Returns the JPEG bytes and how many copies were placed.
({Uint8List bytes, int placed}) buildPhotoSheet(
  img.Image photo, {
  required int sheetW,
  required int sheetH,
  required int copies,
  int gap = 20,
  int margin = 30,
}) {
  final layout = sheetLayout(
    sheetW: sheetW,
    sheetH: sheetH,
    photoW: photo.width,
    photoH: photo.height,
    gap: gap,
    margin: margin,
  );
  final count = math.min(copies, layout.capacity);
  final sheet = img.Image(width: sheetW, height: sheetH);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  if (count <= 0) return (bytes: encodeJpeg(sheet, 92), placed: 0);

  final usedCols = math.min(layout.cols, count);
  final usedRows = (count / layout.cols).ceil();
  final gridW = usedCols * photo.width + (usedCols - 1) * gap;
  final gridH = usedRows * photo.height + (usedRows - 1) * gap;
  final startX = (sheetW - gridW) ~/ 2;
  final startY = math.max(margin, (sheetH - gridH) ~/ 2);
  for (var i = 0; i < count; i++) {
    final c = i % layout.cols;
    final r = i ~/ layout.cols;
    img.compositeImage(
      sheet,
      photo,
      dstX: startX + c * (photo.width + gap),
      dstY: startY + r * (photo.height + gap),
    );
  }
  return (bytes: encodeJpeg(sheet, 92), placed: count);
}

/// A picture centred on a white page of [pageW] x [pageH] pixels, scaled to fit
/// inside [margin].
img.Image fitOnPage(img.Image image, int pageW, int pageH, {int margin = 36}) {
  final maxW = pageW - 2 * margin;
  final maxH = pageH - 2 * margin;
  final scale = math.min(maxW / image.width, maxH / image.height);
  final w = math.max(1, (image.width * scale).round());
  final h = math.max(1, (image.height * scale).round());
  final scaled = resizeExact(image, w, h);
  final page = img.Image(width: pageW, height: pageH);
  img.fill(page, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(page, scaled, dstX: (pageW - w) ~/ 2, dstY: (pageH - h) ~/ 2);
  return page;
}

/// BGRA pixels (as produced by the PDF renderer) -> JPEG or PNG bytes.
Uint8List encodeBgraPixels(Uint8List pixels, int width, int height,
    {required bool png, int quality = 85}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return png
      ? img.encodePng(image)
      : img.encodeJpg(image, quality: quality, chroma: img.JpegChroma.yuv420);
}

// ---------------- background-isolate wrappers ----------------

Future<T> inBackground<T>(T Function() work) => Isolate.run(work);

/// Decode -> optional crop -> optional resize -> compress to a size limit.
/// Crop values are in pixels of the (rotation-corrected) original.
Future<CompressResult?> prepareForUploadAsync(
  Uint8List bytes, {
  required int maxBytes,
  ({int x, int y, int w, int h})? crop,
  int? width,
  int? height,
  bool exactSize = false,
}) =>
    inBackground(() {
      var image = decodeOriented(bytes);
      if (image == null) return null;
      if (crop != null) image = cropRect(image, crop.x, crop.y, crop.w, crop.h);
      if (exactSize && width != null && height != null) {
        image = resizeExact(image, width, height);
      } else {
        image = resizeKeepRatio(image, width: width, height: height);
      }
      return compressToTarget(image, maxBytes);
    });

// ---------------- working copy for previews / cropping ----------------

/// A rotation-corrected JPEG copy (long side <= [maxSide]) that is safe to show
/// on screen and to crop. Camera orientation tags are already applied.
class WorkingImage {
  final Uint8List bytes;
  final int width;
  final int height;
  const WorkingImage(this.bytes, this.width, this.height);
}

Future<WorkingImage?> prepareWorkingImageAsync(Uint8List bytes, {int maxSide = 4096}) =>
    inBackground(() {
      var image = decodeOriented(bytes);
      if (image == null) return null;
      final longest = math.max(image.width, image.height);
      if (longest > maxSide) {
        image = resizeKeepRatio(
          image,
          width: image.width >= image.height ? maxSide : null,
          height: image.height > image.width ? maxSide : null,
        );
      }
      return WorkingImage(encodeJpeg(image, 95), image.width, image.height);
    });

/// Plain re-encode used by "compress with quality" / "resize".
Future<Uint8List?> reencodeAsync(
  Uint8List bytes, {
  int? width,
  int? height,
  required bool png,
  int quality = 90,
}) =>
    inBackground(() {
      var image = decodeOriented(bytes);
      if (image == null) return null;
      image = resizeKeepRatio(image, width: width, height: height);
      return png ? encodePngBytes(image) : encodeJpeg(image, quality);
    });

/// Crop a rectangle (in pixels of the working copy) and encode it.
Future<Uint8List?> cropAsync(
  Uint8List bytes, {
  required int x,
  required int y,
  required int w,
  required int h,
  required bool png,
  int quality = 92,
}) =>
    inBackground(() {
      final image = decodeOriented(bytes);
      if (image == null) return null;
      final c = cropRect(image, x, y, w, h);
      return png ? encodePngBytes(c) : encodeJpeg(c, quality);
    });

/// Photo (cropped + resized to exact pixels) plus a print sheet with copies.
Future<({Uint8List sheet, int placed, Uint8List photo})?> buildPassportAsync(
  Uint8List workingBytes, {
  required int x,
  required int y,
  required int w,
  required int h,
  required int photoW,
  required int photoH,
  required int sheetW,
  required int sheetH,
  required int copies,
}) =>
    inBackground(() {
      final image = decodeOriented(workingBytes);
      if (image == null) return null;
      final photo = resizeExact(cropRect(image, x, y, w, h), photoW, photoH);
      final sheet = buildPhotoSheet(photo, sheetW: sheetW, sheetH: sheetH, copies: copies);
      return (sheet: sheet.bytes, placed: sheet.placed, photo: encodeJpeg(photo, 92));
    });
