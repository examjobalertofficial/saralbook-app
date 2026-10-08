import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

/// Font files (Noto Sans) so the PDF can show the ₹ sign and Hindi text.
class PdfFontData {
  final ByteData regular;
  final ByteData bold;
  final ByteData devanagari;
  const PdfFontData({required this.regular, required this.bold, required this.devanagari});
}

Future<Uint8List> buildExpensePdf({
  required String title,
  required String subtitle,
  required List<(String, String)> summary,
  required List<String> headers,
  required List<List<String>> rows,
  required PdfFontData fonts,
}) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(fonts.regular),
    bold: pw.Font.ttf(fonts.bold),
    fontFallback: [pw.Font.ttf(fonts.devanagari)],
  );
  final doc = pw.Document(title: title, theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 28,
          runSpacing: 6,
          children: [
            for (final s in summary)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(s.$1, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(s.$2, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellAlignments: {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          columnWidths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FixedColumnWidth(52),
            2: const pw.FixedColumnWidth(95),
            3: const pw.FixedColumnWidth(95),
            4: const pw.FixedColumnWidth(95),
            5: const pw.FlexColumnWidth(),
          },
        ),
      ],
    ),
  );
  return doc.save();
}
