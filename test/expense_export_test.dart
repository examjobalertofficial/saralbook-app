import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/expense/export_table.dart';
import 'package:app/core/expense/models.dart';
import 'package:app/core/expense/pdf_report.dart';
import 'package:app/core/expense/xlsx_writer.dart';

ExpenseTxn txn(String id, TxnType type, int minor, DateTime day,
        {String cat = 'food', String note = '', String currency = 'INR', int? orig, double rate = 1}) =>
    ExpenseTxn(
      id: id,
      type: type,
      amountMinor: minor,
      categoryId: cat,
      note: note,
      date: dayNoonMs(day),
      currency: currency,
      origMinor: orig ?? minor,
      rate: rate,
      createdAt: 1,
      updatedAt: 1,
    );

String nameOf(String id) => id[0].toUpperCase() + id.substring(1);

void main() {
  final txns = [
    txn('1', TxnType.expense, 25050, DateTime(2026, 10, 5), note: 'Lunch, "special" thali'),
    txn('2', TxnType.income, 5000000, DateTime(2026, 10, 1), cat: 'salary', note: '=HYPERLINK("http://evil")'),
    txn('3', TxnType.expense, 831200, DateTime(2026, 10, 7), cat: 'travel', currency: 'USD', orig: 10000, rate: 83.12),
  ];

  group('table', () {
    test('rows and totals', () {
      final t = buildExportTable(txns, categoryName: nameOf);
      expect(t.headers.length, 8);
      expect(t.rows.length, 3);
      expect(t.rows[0][0], '2026-10-05');
      expect(t.rows[0][1], 'Expense');
      expect(t.rows[0][3], 250.5);
      expect(t.rows[2][4], 'USD');
      expect(t.rows[2][5], 100.0);
      expect(t.totals[0], ['Total income', 50000.0]);
      expect(t.totals[1], ['Total expense', 8562.5]);
      expect(t.totals[2], ['Savings', 41437.5]);
    });
  });

  group('csv', () {
    final csv = buildCsv(buildExportTable(txns, categoryName: nameOf));

    test('starts with a BOM and a header, uses Windows line ends', () {
      expect(csv.startsWith('\uFEFFDate,Type,Category,Amount (INR)'), isTrue);
      expect(csv.contains('\r\n'), isTrue);
      expect(csv.endsWith('\r\n'), isTrue);
    });

    test('quotes commas and quotes', () {
      expect(csv.contains('"Lunch, ""special"" thali"'), isTrue);
    });

    test('numbers have two decimals', () {
      expect(csv.contains('2026-10-05,Expense,Food,250.50,INR,250.50,1.00,'), isTrue);
    });

    test('text that looks like a formula is defused', () {
      expect(csv.contains("'=HYPERLINK"), isTrue);
      expect(csv.contains(',=HYPERLINK'), isFalse);
      expect(guardFormula('+91 98765'), "'+91 98765");
      expect(guardFormula('@home'), "'@home");
      expect(guardFormula('normal'), 'normal');
      expect(guardFormula(''), '');
    });

    test('totals at the end', () {
      expect(csv.contains('Total income,50000.00'), isTrue);
      expect(csv.contains('Savings,41437.50'), isTrue);
    });

    test('Hindi and the rupee sign survive', () {
      final c = buildCsv(ExportTable(['A'], [
        ['खाना ₹']
      ], const []));
      expect(c.contains('खाना ₹'), isTrue);
      expect(utf8.decode(utf8.encode(c)), c);
    });
  });

  group('xlsx', () {
    final bytes = buildXlsx(exportHeaders, buildExportTable(txns, categoryName: nameOf).rows,
        totals: buildExportTable(txns, categoryName: nameOf).totals);

    test('is a zip with all required parts', () {
      final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name).toSet();
      expect(names, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      ]));
    });

    test('sheet contains headers, numbers and escaped text', () {
      final sheet = utf8.decode(
        ZipDecoder().decodeBytes(bytes).files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml').content,
      );
      expect(sheet.contains('<t xml:space="preserve">Date</t>'), isTrue);
      expect(sheet.contains('<v>250.5</v>'), isTrue);
      expect(sheet.contains('Lunch, &quot;special&quot; thali'), isTrue);
      expect(sheet.contains('<v>41437.5</v>'), isTrue);
    });

    test('helpers', () {
      expect(columnName(0), 'A');
      expect(columnName(25), 'Z');
      expect(columnName(26), 'AA');
      expect(columnName(51), 'AZ');
      expect(columnName(52), 'BA');
      expect(xmlEscape('a & b < c > "d" \'e\''), 'a &amp; b &lt; c &gt; &quot;d&quot; &apos;e&apos;');
      expect(xmlEscape('bad\u0001char'), 'badchar');
    });
  });

  group('pdf', () {
    test('creates a real PDF with fonts for rupee and Hindi', () async {
      ByteData font(String name) {
        final b = File('assets/fonts/$name').readAsBytesSync();
        return ByteData.sublistView(Uint8List.fromList(b));
      }

      final pdf = await buildExpensePdf(
        title: 'Expense report',
        subtitle: '01/10/2026 - 31/10/2026',
        summary: const [('Income', '₹50,000.00'), ('Expense', '₹8,562.50')],
        headers: const ['Date', 'Type', 'Category', 'Amount', 'Original', 'Note'],
        rows: [
          for (var i = 0; i < 80; i++) ['2026-10-05', 'Expense', 'खाना', '₹250.50', '', 'Row $i'],
        ],
        fonts: PdfFontData(
          regular: font('NotoSans-Regular.ttf'),
          bold: font('NotoSans-Bold.ttf'),
          devanagari: font('NotoSansDevanagari-Regular.ttf'),
        ),
      );
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
      expect(pdf.length, greaterThan(5000));
    });
  });
}
