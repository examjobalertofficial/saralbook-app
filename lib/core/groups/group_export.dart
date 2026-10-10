import '../expense/export_table.dart';
import '../expense/money.dart';
import 'group_models.dart';

String _isoDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _people(Map<String, int> m, String Function(String uid) nameOf) {
  final ids = m.keys.toList()..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
  return ids.map((id) => '${nameOf(id)} ${minorToPlain(m[id]!)}').join('; ');
}

const List<String> groupExportHeaders = [
  'Date',
  'Title',
  'Category',
  'Total (INR)',
  'Currency',
  'Original amount',
  'Paid by',
  'Owed by',
  'Split type',
  'Note',
];

/// Everything the group spent, newest first, for CSV (and the PDF).
ExportTable buildGroupTable(
  List<GroupExpense> expenses, {
  required String Function(String uid) nameOf,
  required String Function(String categoryId) categoryName,
}) {
  var total = 0;
  final rows = <List<Object>>[];
  for (final e in expenses) {
    total += e.amountMinor;
    rows.add([
      _isoDate(e.date),
      e.title,
      categoryName(e.categoryId),
      e.amountMinor / 100,
      e.currency,
      e.origMinor / 100,
      _people(e.paidBy, nameOf),
      _people(e.splits, nameOf),
      e.splitType.name,
      e.note,
    ]);
  }
  return ExportTable(groupExportHeaders, rows, [
    ['Total spent', total / 100],
    ['Bills', expenses.length],
  ]);
}

List<List<String>> groupPdfRows(
  List<GroupExpense> expenses, {
  required String Function(String uid) nameOf,
  required String Function(String categoryId) categoryName,
}) =>
    [
      for (final e in expenses)
        [
          _isoDate(e.date),
          e.title,
          categoryName(e.categoryId),
          formatInr(e.amountMinor),
          _people(e.paidBy, nameOf),
          _people(e.splits, nameOf),
        ],
    ];
