import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/pdfsan/pdf_scan.dart';

PdfScanReport _scan(String text) => scanPdfBytes(Uint8List.fromList(latin1.encode(text)));

void main() {
  test('a plain PDF has nothing hidden', () {
    final r = _scan('%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF');
    expect(r.risk, PdfRisk.low);
    expect(r.shown, isEmpty);
    expect(r.info, isEmpty);
  });

  test('scripts, attached files and start-up actions are found and rated high', () {
    final r = _scan('<< /OpenAction 5 0 R /AA << /O 6 0 R >> >> << /S /JavaScript /JS (app.alert(1)) >> '
        '<< /Type /EmbeddedFile /Subtype /text#2Fplain >> << /S /Launch /F (a.exe) >>');
    expect(r.has(PdfFinding.javascript), isTrue);
    expect(r.count(PdfFinding.javascript), 2); // /JavaScript and /JS
    expect(r.count(PdfFinding.autoActions), 2); // /OpenAction and /AA
    expect(r.has(PdfFinding.embeddedFile), isTrue);
    expect(r.has(PdfFinding.launch), isTrue);
    expect(r.risk, PdfRisk.high);
    expect(PdfScanReport.isHigh(r.shown.first), isTrue);
  });

  test('names that only look similar are not counted', () {
    final r = _scan('/AAPL /EmbeddedFiles /JSON /Sounds /Moviestar /URIs /Launcher');
    expect(r.counts.isEmpty, isTrue);
    expect(r.risk, PdfRisk.low);
  });

  test('links, comments and forms are medium', () {
    final r = _scan('<< /S /URI /URI (http://example.com) >> << /Subtype /Highlight >> << /Subtype/Text >> /AcroForm 3 0 R');
    expect(r.count(PdfFinding.links), 1); // only the "/URI (...)" part counts, not "/S /URI"
    expect(r.count(PdfFinding.comments), 2);
    expect(r.has(PdfFinding.forms), isTrue);
    expect(r.risk, PdfRisk.medium);
  });

  test('a normal link annotation and a widget are not comments', () {
    final r = _scan('<< /Subtype /Link >> << /Subtype /Widget >> << /Subtype /Popup >>');
    expect(r.has(PdfFinding.comments), isFalse);
  });

  test('document details are read from the Info object', () {
    final r = _scan('1 0 obj\n<< /Author (Rahul Kumar) /Producer (Microsoft Word) /Title () >>\nendobj\n'
        'trailer\n<< /Info 1 0 R /Root 2 0 R >>\n');
    expect(r.info['Author'], 'Rahul Kumar');
    expect(r.info['Producer'], 'Microsoft Word');
    expect(r.info.containsKey('Title'), isFalse); // empty values are ignored
    expect(r.count(PdfFinding.metadata), 2);
    expect(r.risk, PdfRisk.medium);
  });

  test('titles of bookmarks are not mistaken for document details', () {
    final r = _scan('5 0 obj\n<< /Title (Chapter 1) /Parent 4 0 R >>\nendobj\ntrailer\n<< /Root 1 0 R >>');
    expect(r.info, isEmpty);
  });

  test('hex and UTF-16 strings are decoded', () {
    expect(decodePdfString('<FEFF00480069>'), 'Hi');
    expect(decodePdfString('<48656C6C6F>'), 'Hello');
    expect(decodePdfString(r'(A\(B\)\101\\)'), 'A(B)A\\');
    expect(decodePdfString('(line\\nbreak)'), 'line break');
    expect(decodePdfString('(${'x' * 100})').length, 81); // 80 letters and an ellipsis
  });

  test('encryption, packed parts and XMP are reported as notes', () {
    final r = _scan('/Encrypt 9 0 R /Type /ObjStm <x:xmpmeta xmlns:x="adobe:ns:meta/">');
    expect(r.has(PdfFinding.encrypted), isTrue);
    expect(r.has(PdfFinding.compressedParts), isTrue);
    expect(r.has(PdfFinding.xmp), isTrue);
    expect(r.shown, [PdfFinding.xmp]); // notes are not listed as hidden data
    expect(r.risk, PdfRisk.medium);
  });
}
