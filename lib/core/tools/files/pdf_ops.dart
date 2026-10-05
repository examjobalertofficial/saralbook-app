import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'image_ops.dart';

/// PDF operations built on pdfrx (PDFium), all offline.
/// These need the native PDF engine, so they are checked on a real phone,
/// not in unit tests.

typedef Progress = void Function(int done, int total);

class PdfTooLargeException implements Exception {
  final int pages;
  const PdfTooLargeException(this.pages);
}

/// Pages above this are refused for compress/convert (memory safety).
const int maxRasterPages = 200;

Future<PdfDocument> _open(String path) async {
  await pdfrxFlutterInitialize();
  return PdfDocument.openFile(path);
}

class PdfSummary {
  final int pages;
  final double widthMm;
  final double heightMm;
  const PdfSummary(this.pages, this.widthMm, this.heightMm);
}

Future<PdfSummary> pdfSummary(String path) async {
  final doc = await _open(path);
  try {
    final first = doc.pages.first;
    return PdfSummary(
      doc.pages.length,
      first.width / 72 * 25.4,
      first.height / 72 * 25.4,
    );
  } finally {
    doc.dispose();
  }
}

/// Real merge: pages are copied as they are (text and links are kept).
Future<Uint8List> mergePdfs(List<String> paths, {Progress? onProgress}) async {
  await pdfrxFlutterInitialize();
  final sources = <PdfDocument>[];
  PdfDocument? out;
  try {
    out = await PdfDocument.createNew(sourceName: 'merged.pdf');
    final pages = <PdfPage>[];
    for (var i = 0; i < paths.length; i++) {
      final d = await PdfDocument.openFile(paths[i]);
      sources.add(d);
      pages.addAll(d.pages);
      onProgress?.call(i + 1, paths.length);
    }
    out.pages = pages;
    return await out.encodePdf();
  } finally {
    for (final d in sources) {
      d.dispose();
    }
    out?.dispose();
  }
}

/// One new PDF per group of 1-based page numbers.
Future<List<Uint8List>> splitPdf(String path, List<List<int>> groups, {Progress? onProgress}) async {
  final doc = await _open(path);
  final results = <Uint8List>[];
  try {
    for (var i = 0; i < groups.length; i++) {
      final out = await PdfDocument.createNew(sourceName: 'part_${i + 1}.pdf');
      try {
        out.pages = [for (final n in groups[i]) doc.pages[n - 1]];
        results.add(await out.encodePdf());
      } finally {
        out.dispose();
      }
      onProgress?.call(i + 1, groups.length);
    }
  } finally {
    doc.dispose();
  }
  return results;
}

/// Renders page [page] to pixels (longest side limited to [maxSide]).
Future<({Uint8List pixels, int width, int height})?> _renderPage(
  PdfPage page,
  int dpi, {
  int maxSide = 4000,
}) async {
  final scale = math.min(dpi / 72, maxSide / math.max(page.width, page.height));
  final image = await page.render(
    fullWidth: page.width * scale,
    fullHeight: page.height * scale,
  );
  if (image == null) return null;
  try {
    // copy: the engine buffer is released with the image
    return (pixels: Uint8List.fromList(image.pixels), width: image.width, height: image.height);
  } finally {
    image.dispose();
  }
}

/// Smaller file by turning each page into a JPEG picture.
/// Text can no longer be selected afterwards; the app warns about this.
Future<Uint8List> compressPdf(String path,
    {required int dpi, required int quality, Progress? onProgress}) async {
  final doc = await _open(path);
  final parts = <PdfDocument>[];
  PdfDocument? out;
  try {
    final total = doc.pages.length;
    if (total > maxRasterPages) throw PdfTooLargeException(total);
    for (var i = 0; i < total; i++) {
      final page = doc.pages[i];
      final r = await _renderPage(page, dpi);
      if (r == null) continue;
      final jpeg = await inBackground(
        () => encodeBgraPixels(r.pixels, r.width, r.height, png: false, quality: quality),
      );
      parts.add(await PdfDocument.createFromJpegData(
        jpeg,
        width: page.width,
        height: page.height,
        sourceName: 'page_${i + 1}.jpg',
      ));
      onProgress?.call(i + 1, total);
    }
    out = await PdfDocument.createNew(sourceName: 'compressed.pdf');
    out.pages = [for (final d in parts) d.pages.first];
    return await out.encodePdf();
  } finally {
    for (final d in parts) {
      d.dispose();
    }
    out?.dispose();
    doc.dispose();
  }
}

/// Each selected page as a JPG/PNG picture.
Future<List<Uint8List>> pdfToImages(
  String path,
  List<int> pages, {
  required int dpi,
  required bool png,
  int quality = 88,
  Progress? onProgress,
}) async {
  final doc = await _open(path);
  final results = <Uint8List>[];
  try {
    if (pages.length > maxRasterPages) throw PdfTooLargeException(pages.length);
    for (var i = 0; i < pages.length; i++) {
      final r = await _renderPage(doc.pages[pages[i] - 1], dpi);
      if (r == null) continue;
      results.add(await inBackground(
        () => encodeBgraPixels(r.pixels, r.width, r.height, png: png, quality: quality),
      ));
      onProgress?.call(i + 1, pages.length);
    }
  } finally {
    doc.dispose();
  }
  return results;
}

enum PdfPageMode { a4, fitImage }

class _PreparedPage {
  final Uint8List jpeg;
  final double widthPt;
  final double heightPt;
  const _PreparedPage(this.jpeg, this.widthPt, this.heightPt);
}

/// Pictures -> one PDF (one picture per page).
/// [dpi] controls sharpness/size; [quality] is the JPEG quality.
Future<Uint8List> imagesToPdf(
  List<Uint8List> images, {
  required PdfPageMode mode,
  required int dpi,
  required int quality,
  Progress? onProgress,
}) async {
  await pdfrxFlutterInitialize();
  final parts = <PdfDocument>[];
  PdfDocument? out;
  try {
    for (var i = 0; i < images.length; i++) {
      final bytes = images[i];
      final page = await inBackground(() {
        final decoded = decodeOriented(bytes);
        if (decoded == null) return null;
        if (mode == PdfPageMode.a4) {
          final landscape = decoded.width > decoded.height;
          final w = ((landscape ? 11.69 : 8.27) * dpi).round();
          final h = ((landscape ? 8.27 : 11.69) * dpi).round();
          final canvas = fitOnPage(decoded, w, h, margin: (dpi * 0.25).round());
          return _PreparedPage(
            encodeJpeg(canvas, quality),
            landscape ? 841.89 : 595.28,
            landscape ? 595.28 : 841.89,
          );
        }
        final maxSide = (dpi * 12).round(); // up to ~A3 at this dpi
        final longest = math.max(decoded.width, decoded.height);
        final scaled = longest > maxSide
            ? resizeKeepRatio(
                decoded,
                width: decoded.width >= decoded.height ? maxSide : null,
                height: decoded.height > decoded.width ? maxSide : null,
              )
            : decoded;
        return _PreparedPage(
          encodeJpeg(scaled, quality),
          scaled.width * 72 / dpi,
          scaled.height * 72 / dpi,
        );
      });
      if (page == null) throw const FormatException('Unreadable image');
      parts.add(await PdfDocument.createFromJpegData(
        page.jpeg,
        width: page.widthPt,
        height: page.heightPt,
        sourceName: 'image_${i + 1}.jpg',
      ));
      onProgress?.call(i + 1, images.length);
    }
    out = await PdfDocument.createNew(sourceName: 'images.pdf');
    out.pages = [for (final d in parts) d.pages.first];
    return await out.encodePdf();
  } finally {
    for (final d in parts) {
      d.dispose();
    }
    out?.dispose();
  }
}

/// A one-page PDF whose page is exactly [jpeg] ([widthPt] x [heightPt] points).
Future<Uint8List> jpegToSinglePagePdf(Uint8List jpeg, double widthPt, double heightPt) async {
  await pdfrxFlutterInitialize();
  final doc = await PdfDocument.createFromJpegData(
    jpeg,
    width: widthPt,
    height: heightPt,
    sourceName: 'sheet.jpg',
  );
  try {
    return await doc.encodePdf();
  } finally {
    doc.dispose();
  }
}
