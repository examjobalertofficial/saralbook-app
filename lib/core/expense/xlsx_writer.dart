import 'dart:typed_data';

import 'package:archive/archive.dart';

// Fixed parts of a minimal Excel (.xlsx) file.
const String _xmlHeader = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

const String _contentTypes = '$_xmlHeader'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const String _rootRels = '$_xmlHeader'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const String _workbook = '$_xmlHeader'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Transactions" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';

const String _workbookRels = '$_xmlHeader'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

// style 0 = normal, 1 = bold (headers), 2 = number with 2 decimals
const String _styles = '$_xmlHeader'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="3">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

/// Escapes text for XML and drops characters XML 1.0 does not allow.
String xmlEscape(String s) {
  final clean = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  return clean
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String columnName(int index) {
  // 0 -> A, 25 -> Z, 26 -> AA
  var n = index;
  var s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

String _cell(int row, int col, Object value, {bool header = false}) {
  final ref = '${columnName(col)}$row';
  if (value is num) {
    return '<c r="$ref" s="2"><v>$value</v></c>';
  }
  final text = '$value';
  return '<c r="$ref" t="inlineStr"${header ? ' s="1"' : ''}><is><t xml:space="preserve">${xmlEscape(text)}</t></is></c>';
}

String buildSheetXml(List<String> headers, List<List<Object>> rows, {List<List<Object>> totals = const []}) {
  final b = StringBuffer(_xmlHeader);
  b.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  b.write('<cols>');
  for (var c = 0; c < headers.length; c++) {
    b.write('<col min="${c + 1}" max="${c + 1}" width="${c == headers.length - 1 ? 40 : 16}" customWidth="1"/>');
  }
  b.write('</cols><sheetData>');
  var r = 1;
  b.write('<row r="$r">');
  for (var c = 0; c < headers.length; c++) {
    b.write(_cell(r, c, headers[c], header: true));
  }
  b.write('</row>');
  for (final row in rows) {
    r++;
    b.write('<row r="$r">');
    for (var c = 0; c < row.length; c++) {
      b.write(_cell(r, c, row[c]));
    }
    b.write('</row>');
  }
  if (totals.isNotEmpty) {
    r++; // empty line before the totals
    for (final row in totals) {
      r++;
      b.write('<row r="$r">');
      for (var c = 0; c < row.length; c++) {
        b.write(_cell(r, c, row[c], header: c == 0));
      }
      b.write('</row>');
    }
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// A real .xlsx file (opens in Excel, Google Sheets, LibreOffice).
Uint8List buildXlsx(List<String> headers, List<List<Object>> rows, {List<List<Object>> totals = const []}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook))
    ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
    ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', buildSheetXml(headers, rows, totals: totals)));
  return ZipEncoder().encodeBytes(archive);
}
