import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart' show PdfDocument, PdfPage, pdfrxFlutterInitialize;

import '../tools/files/pdf_ops.dart';

/// Standard clean: the pages are copied into a brand-new PDF. The document's own
/// details (author, software, XMP), start-up actions and attached files are not
/// carried over, and the text stays selectable. Links and comments that sit
/// on a page may stay; the check that follows shows exactly what is left.
Future<Uint8List> cleanStandard(String path, {Progress? onProgress}) async {
  await pdfrxFlutterInitialize();
  final doc = await PdfDocument.openFile(path);
  PdfDocument? out;
  try {
    out = await PdfDocument.createNew(sourceName: 'clean.pdf');
    out.pages = List<PdfPage>.of(doc.pages);
    onProgress?.call(1, 1);
    return await out.encodePdf();
  } finally {
    doc.dispose();
    out?.dispose();
  }
}

/// Maximum safe: every page becomes a picture and a new PDF is made from the
/// pictures. Nothing but the look of the page is kept (no scripts, files,
/// links, forms, comments, hidden text or details). Text is no longer selectable.
Future<Uint8List> cleanFlatten(
  String path, {
  required int dpi,
  required int quality,
  Progress? onProgress,
}) async {
  final summary = await pdfSummary(path);
  final pages = <int>[for (var i = 1; i <= summary.pages; i++) i];
  final jpegs = await pdfToImages(
    path,
    pages,
    dpi: dpi,
    png: false,
    quality: 92,
    onProgress: (done, total) => onProgress?.call(done, total * 2),
  );
  return imagesToPdf(
    jpegs,
    mode: PdfPageMode.fitImage,
    dpi: dpi,
    quality: quality,
    onProgress: (done, total) => onProgress?.call(total + done, total * 2),
  );
}
