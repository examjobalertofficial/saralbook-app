import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../expense/pdf_report.dart' show PdfFontData;
import 'resume_model.dart';

PdfColor _color(int rgb) => PdfColor.fromInt(0xFF000000 | (rgb & 0xFFFFFF));

/// The theme colour mixed with white (0 = white, 1 = full colour).
PdfColor _tint(PdfColor c, double amount) => PdfColor(
      1 - (1 - c.red) * amount,
      1 - (1 - c.green) * amount,
      1 - (1 - c.blue) * amount,
    );

pw.TextStyle _st({double size = 10, bool bold = false, PdfColor? color}) =>
    pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color);

/// Builds the finished A4 resume as PDF bytes (5 looks). Works offline.
Future<Uint8List> buildResumePdf(ResumeData d, PdfFontData fonts) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(fonts.regular),
    bold: pw.Font.ttf(fonts.bold),
    fontFallback: [pw.Font.ttf(fonts.devanagari)],
  );
  final name = d.fullName.trim().isEmpty ? 'Resume' : d.fullName.trim();
  final doc = pw.Document(title: 'Resume - $name', author: name, theme: theme);
  final c = _color(d.colorValue);
  final photo = d.photo == null ? null : pw.MemoryImage(d.photo!);
  switch (d.templateId) {
    case 'modern':
      _modern(doc, d, c, photo);
    case 'sidebar':
      _sidebar(doc, d, c, photo);
    case 'strip':
      _strip(doc, d, c, photo);
    case 'border':
      _border(doc, d, c, photo);
    default:
      _classic(doc, d, c, photo);
  }
  return doc.save();
}

PdfPageFormat _format({double top = 32, double side = 36, double bottom = 32}) =>
    PdfPageFormat.a4.applyMargin(left: side, top: top, right: side, bottom: bottom);

// ---------------------------------------------------------------- pieces

pw.Widget _photo(pw.MemoryImage? photo, double size) {
  if (photo == null) return pw.SizedBox(width: 0, height: 0);
  return pw.ClipOval(
    child: pw.Container(width: size, height: size, child: pw.Image(photo, fit: pw.BoxFit.cover)),
  );
}

String _contactLine(ResumeData d) =>
    [d.phone.trim(), d.email.trim(), d.address.trim()].where((e) => e.isNotEmpty).join('   |   ');

List<String> _contactItems(ResumeData d) => [d.phone.trim(), d.email.trim(), d.address.trim()].where((e) => e.isNotEmpty).toList();

pw.Widget _objective(ResumeData d, {PdfColor? color}) =>
    pw.Text(d.objective.trim(), style: _st(color: color), textAlign: pw.TextAlign.justify);

pw.Widget _eduTable(ResumeData d, PdfColor c, {bool filledHeader = true}) {
  final rows = d.filledEducation;
  return pw.TableHelper.fromTextArray(
    headers: const ['Qualification', 'Board / University', 'Year', 'Marks / %'],
    data: [for (final e in rows) [e.degree, e.board, e.year, e.score]],
    headerStyle: _st(bold: true, color: filledHeader ? PdfColors.white : c),
    headerDecoration: pw.BoxDecoration(color: filledHeader ? c : _tint(c, 0.12)),
    cellStyle: _st(),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(2.2),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(1.3),
    },
  );
}

pw.Widget _experienceBlock(ExperienceEntry e, PdfColor c) {
  final title = [e.role.trim(), e.company.trim()].where((x) => x.isNotEmpty).join(' - ');
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Text(title, style: _st(bold: true))),
            if (e.period.trim().isNotEmpty) pw.Text(e.period.trim(), style: _st(size: 9, color: PdfColors.grey700)),
          ],
        ),
        if (e.details.trim().isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(e.details.trim(), style: _st())),
      ],
    ),
  );
}

pw.Widget _skillChips(ResumeData d, PdfColor c, {bool onDark = false}) => pw.Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final s in d.filledSkills)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: onDark ? null : _tint(c, 0.1),
              border: pw.Border.all(color: onDark ? PdfColors.white : c, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Text(s, style: _st(size: 9, color: onDark ? PdfColors.white : PdfColors.black)),
          ),
      ],
    );

pw.Widget _personalTable(ResumeData d, {PdfColor? color}) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final r in d.personalRows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 92, child: pw.Text(r.$1, style: _st(bold: true, color: color))),
                pw.Text(':  ', style: _st(color: color)),
                pw.Expanded(child: pw.Text(r.$2, style: _st(color: color))),
              ],
            ),
          ),
      ],
    );

pw.Widget _declaration(ResumeData d) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('I hereby declare that the details furnished above are true to the best of my knowledge.', style: _st()),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Date: ${d.declarationDate.trim()}', style: _st()),
                pw.SizedBox(height: 3),
                pw.Text('Place: ${d.declarationPlace.trim()}', style: _st()),
              ],
            ),
            pw.Text('(${d.fullName.trim()})', style: _st(bold: true)),
          ],
        ),
      ],
    );

/// Builds the body sections in order. [head] draws a section heading.
List<pw.Widget> _body(
  ResumeData d,
  PdfColor c,
  pw.Widget Function(String title) head, {
  bool includePersonal = true,
  bool includeSkills = true,
  bool filledEduHeader = true,
}) {
  final out = <pw.Widget>[];
  void gap() => out.add(pw.SizedBox(height: 10));
  if (d.objective.trim().isNotEmpty) {
    out..add(head('Career Objective'))..add(_objective(d));
    gap();
  }
  if (d.filledEducation.isNotEmpty) {
    out..add(head('Education'))..add(_eduTable(d, c, filledHeader: filledEduHeader));
    gap();
  }
  if (d.filledExperience.isNotEmpty) {
    out.add(head('Experience'));
    for (final e in d.filledExperience) {
      out.add(_experienceBlock(e, c));
    }
    gap();
  }
  if (includeSkills && d.filledSkills.isNotEmpty) {
    out..add(head('Skills'))..add(_skillChips(d, c));
    gap();
  }
  if (includePersonal && d.personalRows.isNotEmpty) {
    out..add(head('Personal Details'))..add(_personalTable(d));
    gap();
  }
  if (d.showDeclaration) {
    out..add(head('Declaration'))..add(_declaration(d));
  }
  return out;
}

pw.Widget _nameBlock(ResumeData d, PdfColor color, {double size = 24, pw.CrossAxisAlignment align = pw.CrossAxisAlignment.start}) => pw.Column(
      crossAxisAlignment: align,
      children: [
        pw.Text(d.fullName.trim(), style: _st(size: size, bold: true, color: color)),
        if (d.headline.trim().isNotEmpty) pw.Text(d.headline.trim(), style: _st(size: 12, color: color)),
      ],
    );

// ---------------------------------------------------------------- 1 classic

void _classic(pw.Document doc, ResumeData d, PdfColor c, pw.MemoryImage? photo) {
  pw.Widget head(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(t.toUpperCase(), style: _st(size: 11, bold: true, color: c)),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, color: c),
        ]),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: _format(),
    build: (_) => [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(d.fullName.trim().toUpperCase(), style: _st(size: 24, bold: true, color: c), textAlign: pw.TextAlign.center),
              if (d.headline.trim().isNotEmpty) pw.Text(d.headline.trim(), style: _st(size: 12), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text(_contactLine(d), style: _st(size: 9.5), textAlign: pw.TextAlign.center),
            ]),
          ),
          if (photo != null) _photo(photo, 70),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 2, color: c),
      pw.SizedBox(height: 12),
      ..._body(d, c, head, filledEduHeader: false),
    ],
  ));
}

// ---------------------------------------------------------------- 2 modern

void _modern(pw.Document doc, ResumeData d, PdfColor c, pw.MemoryImage? photo) {
  pw.Widget head(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(t.toUpperCase(), style: _st(size: 11, bold: true, color: c)),
          pw.SizedBox(height: 2),
          pw.Container(height: 2, width: 36, color: c),
        ]),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: _format(),
    build: (_) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: _tint(c, 0.12), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (photo != null) ...[_photo(photo, 84), pw.SizedBox(width: 16)],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _nameBlock(d, c, size: 24),
                  pw.SizedBox(height: 6),
                  for (final line in _contactItems(d)) pw.Text(line, style: _st(size: 9.5)),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      ..._body(d, c, head, filledEduHeader: true),
    ],
  ));
}

// ---------------------------------------------------------------- 3 sidebar

void _sidebar(pw.Document doc, ResumeData d, PdfColor c, pw.MemoryImage? photo) {
  const sideW = 170.0;
  final format = PdfPageFormat.a4.applyMargin(left: 0, top: 28, right: 0, bottom: 28);
  pw.Widget sideHead(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(t.toUpperCase(), style: _st(size: 10.5, bold: true, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, width: 30, color: PdfColors.white),
        ]),
      );
  pw.Widget mainHead(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(t.toUpperCase(), style: _st(size: 11, bold: true, color: c)),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, color: c),
        ]),
      );
  final white = _st(size: 9.5, color: PdfColors.white);
  final side = pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (photo != null) pw.Center(child: _photo(photo, 100)),
        if (_contactItems(d).isNotEmpty) ...[
          sideHead('Contact'),
          for (final l in _contactItems(d)) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(l, style: white)),
        ],
        if (d.filledSkills.isNotEmpty) ...[
          sideHead('Skills'),
          _skillChips(d, c, onDark: true),
        ],
        if (d.personalRows.isNotEmpty) ...[
          sideHead('Personal'),
          _personalTable(d, color: PdfColors.white),
        ],
      ],
    ),
  );
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: format,
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(children: [
          pw.Positioned(left: 0, top: 0, bottom: 0, child: pw.Container(width: sideW, color: c)),
        ]),
      ),
    ),
    build: (_) => [
      pw.Partitions(children: [
        pw.Partition(width: sideW, child: pw.Column(children: [side])),
        pw.Partition(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(20, 0, 28, 10),
                child: _nameBlock(d, c, size: 24),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(20, 0, 28, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _body(d, c, mainHead, includePersonal: false, includeSkills: false),
                ),
              ),
            ],
          ),
        ),
      ]),
    ],
  ));
}

// ---------------------------------------------------------------- 4 strip

void _strip(pw.Document doc, ResumeData d, PdfColor c, pw.MemoryImage? photo) {
  pw.Widget head(String t) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 5),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: _tint(c, 0.15),
        child: pw.Text(t.toUpperCase(), style: _st(size: 10.5, bold: true, color: c)),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: _format(),
    build: (_) => [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: c,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _nameBlock(d, PdfColors.white, size: 24),
                  pw.SizedBox(height: 5),
                  pw.Text(_contactLine(d), style: _st(size: 9.5, color: PdfColors.white)),
                ],
              ),
            ),
            if (photo != null) _photo(photo, 70),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      ..._body(d, c, head),
    ],
  ));
}

// ---------------------------------------------------------------- 5 border

void _border(pw.Document doc, ResumeData d, PdfColor c, pw.MemoryImage? photo) {
  pw.Widget head(String t) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 5),
        padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
        decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: c, width: 4))),
        child: pw.Text(t, style: _st(size: 12, bold: true, color: c)),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: _format(),
    build: (_) => [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _nameBlock(d, c, size: 26),
                pw.SizedBox(height: 5),
                for (final l in _contactItems(d)) pw.Text(l, style: _st(size: 9.5)),
              ],
            ),
          ),
          if (photo != null) _photo(photo, 80),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(height: 1, color: PdfColors.grey400),
      pw.SizedBox(height: 12),
      ..._body(d, c, head, filledEduHeader: false),
    ],
  ));
}
