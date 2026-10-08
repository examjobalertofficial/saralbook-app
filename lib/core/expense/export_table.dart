import 'models.dart';
import 'money.dart';

/// Rows ready to be written as CSV / Excel / PDF.
class ExportTable {
  final List<String> headers;

  /// Cells are String or num.
  final List<List<Object>> rows;

  /// Totals shown after the rows (label, amount in rupees).
  final List<List<Object>> totals;
  const ExportTable(this.headers, this.rows, this.totals);
}

String _isoDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const List<String> exportHeaders = [
  'Date',
  'Type',
  'Category',
  'Amount (INR)',
  'Currency',
  'Original amount',
  'Rate (INR per unit)',
  'Note',
];

/// [txns] should already be filtered and sorted. [categoryName] turns an id into text.
ExportTable buildExportTable(List<ExpenseTxn> txns, {required String Function(String id) categoryName}) {
  var income = 0;
  var expense = 0;
  final rows = <List<Object>>[];
  for (final t in txns) {
    if (t.type == TxnType.income) {
      income += t.amountMinor;
    } else {
      expense += t.amountMinor;
    }
    rows.add([
      _isoDate(t.date),
      t.type == TxnType.income ? 'Income' : 'Expense',
      categoryName(t.categoryId),
      t.amountMinor / 100,
      t.currency,
      t.origMinor / 100,
      t.rate,
      t.note,
    ]);
  }
  return ExportTable(
    exportHeaders,
    rows,
    [
      ['Total income', income / 100],
      ['Total expense', expense / 100],
      ['Savings', (income - expense) / 100],
    ],
  );
}

/// Text that starts with = + - @ could run as a formula when opened in a
/// spreadsheet. A leading apostrophe makes it plain text.
String guardFormula(String s) {
  if (s.isEmpty) return s;
  const risky = ['=', '+', '-', '@', '\t', '\r'];
  return risky.contains(s[0]) ? "'$s" : s;
}

String _csvCell(Object v) {
  final text = v is num ? (v is int ? '$v' : v.toStringAsFixed(2)) : guardFormula('$v');
  if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// UTF-8 CSV (with a BOM so Excel shows Hindi and ₹ correctly).
String buildCsv(ExportTable table) {
  final lines = <String>[
    table.headers.map(_csvCell).join(','),
    for (final r in table.rows) r.map(_csvCell).join(','),
    '',
    for (final t in table.totals) t.map(_csvCell).join(','),
  ];
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

/// Rows for the PDF (everything as text, rupees formatted).
List<List<String>> pdfRows(List<ExpenseTxn> txns, {required String Function(String id) categoryName}) => [
      for (final t in txns)
        [
          _isoDate(t.date),
          t.type == TxnType.income ? 'Income' : 'Expense',
          categoryName(t.categoryId),
          formatInr(t.amountMinor),
          t.isForeign ? formatForeign(t.origMinor, t.currency) : '',
          t.note,
        ],
    ];
