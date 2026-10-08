import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/expense/export_table.dart';
import '../../core/expense/logic.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/expense/pdf_report.dart';
import '../../core/expense/xlsx_writer.dart';
import '../../core/files/file_helpers.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart' show DateRange, ProgressPeriod, dayOf, rangeFor;
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import '../tools/files/file_ui.dart' show JobResult, OutputPanel, Tx;
import 'expense_ui.dart';

final LText _title = t('Export', 'एक्सपोर्ट');

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Export(data: data));
}

enum _Period { thisMonth, last30, thisYear, all, custom }

enum _Format { csv, xlsx, pdf }

class _Export extends StatefulWidget {
  final PersonalData data;
  const _Export({required this.data});

  @override
  State<_Export> createState() => _ExportState();
}

class _ExportState extends State<_Export> {
  _Period _period = _Period.thisMonth;
  DateRange? _custom;
  TxnType? _type;
  String? _categoryId;
  _Format _format = _Format.csv;
  bool _busy = false;
  JobResult? _result;
  String? _error;

  static final LText _noData = t('There are no transactions with these filters.', 'इन फ़िल्टर से कोई लेन-देन नहीं है।');
  static final LText _fail = t('Could not create the file. Please try again.', 'फ़ाइल नहीं बन सकी। कृपया फिर कोशिश करें।');

  DateRange? get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return rangeFor(ProgressPeriod.month, now);
      case _Period.last30:
        final d = dayOf(now);
        return DateRange(DateTime(d.year, d.month, d.day - 29), DateTime(d.year, d.month, d.day + 1));
      case _Period.thisYear:
        return DateRange(DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case _Period.all:
        return null;
      case _Period.custom:
        return _custom;
    }
  }

  List<ExpenseTxn> _filtered() => applyFilter(
        widget.data.expenses.items,
        TxnFilter(range: _range, type: _type, categoryId: _categoryId),
      );

  /// Built-in categories in English (clean in every spreadsheet / PDF);
  /// custom categories keep the name the person typed.
  String _catName(String id) => categoryFor(widget.data, id).name.of('en');

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 8),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _period = _Period.custom;
      _custom = DateRange(dayOf(picked.start), DateTime(picked.end.year, picked.end.month, picked.end.day + 1));
      _result = null;
    });
  }

  String _rangeText() {
    final r = _range;
    if (r == null) return 'All time';
    final last = DateTime(r.endExclusive.year, r.endExclusive.month, r.endExclusive.day - 1);
    return '${fmtDate(r.start)} - ${fmtDate(last)}';
  }

  Future<ByteData> _font(String name) => rootBundle.load('assets/fonts/$name');

  Future<void> _export() async {
    final txns = _filtered();
    if (txns.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await cleanOldOutputs();
      final table = buildExportTable(txns, categoryName: _catName);
      final stamp = DateTime.now();
      final base = 'expenses_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
      OutputFile out;
      switch (_format) {
        case _Format.csv:
          out = await writeOutput('$base.csv', Uint8List.fromList(utf8.encode(buildCsv(table))));
        case _Format.xlsx:
          out = await writeOutput('$base.xlsx', buildXlsx(table.headers, table.rows, totals: table.totals));
        case _Format.pdf:
          final s = summarize(txns);
          final bytes = await buildExpensePdf(
            title: 'SaralBook - Expense report',
            subtitle: _rangeText(),
            summary: [
              ('Income', formatInr(s.income)),
              ('Expense', formatInr(s.expense)),
              ('Savings', formatInr(s.savings, showSign: true)),
              ('Transactions', '${txns.length}'),
            ],
            headers: const ['Date', 'Type', 'Category', 'Amount', 'Original', 'Note'],
            rows: pdfRows(txns, categoryName: _catName),
            fonts: PdfFontData(
              regular: await _font('NotoSans-Regular.ttf'),
              bold: await _font('NotoSans-Bold.ttf'),
              devanagari: await _font('NotoSansDevanagari-Regular.ttf'),
            ),
          );
          out = await writeOutput('$base.pdf', bytes);
      }
      if (!mounted) return;
      setState(() => _result = JobResult([out], info: [(t('Transactions', 'लेन-देन'), '${txns.length}'), (Tx.fileSize, formatBytes(out.size))]));
    } catch (_) {
      if (mounted) setState(() => _error = tr(context, _fail));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.expenses, data.expenseCategories]),
          builder: (context, _) {
            if (!data.expenses.loaded) return const Center(child: CircularProgressIndicator());
            final count = _filtered().length;
            final scheme = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(tr(context, t('Period', 'अवधि')), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                ChipRow<_Period>(
                  value: _period,
                  options: [
                    (_Period.thisMonth, t('This month', 'यह महीना')),
                    (_Period.last30, t('Last 30 days', 'पिछले 30 दिन')),
                    (_Period.thisYear, t('This year', 'यह साल')),
                    (_Period.all, t('All time', 'पूरा समय')),
                    (_Period.custom, t('Custom', 'अपनी रेंज')),
                  ],
                  onChanged: (v) {
                    if (v == _Period.custom) {
                      _pickCustom();
                    } else {
                      setState(() {
                        _period = v;
                        _result = null;
                      });
                    }
                  },
                ),
                if (_period == _Period.custom && _custom != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(_rangeText())),
                const SizedBox(height: 14),
                Text(tr(context, t('Type', 'प्रकार')), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                ChipRow<TxnType?>(
                  value: _type,
                  options: [(null, t('All', 'सभी')), (TxnType.expense, typeLabel(TxnType.expense)), (TxnType.income, typeLabel(TxnType.income))],
                  onChanged: (v) => setState(() {
                    _type = v;
                    _categoryId = null;
                    _result = null;
                  }),
                ),
                const SizedBox(height: 14),
                Text(tr(context, t('Category', 'श्रेणी')), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                CategoryChips(
                  data: data,
                  type: _type,
                  selected: _categoryId,
                  allowAll: true,
                  onChanged: (id) => setState(() {
                    _categoryId = id;
                    _result = null;
                  }),
                ),
                const SizedBox(height: 14),
                Text(tr(context, t('File type', 'फ़ाइल प्रकार')), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                ChipRow<_Format>(
                  value: _format,
                  options: [
                    (_Format.csv, t('CSV', 'CSV')),
                    (_Format.xlsx, t('Excel', 'Excel')),
                    (_Format.pdf, t('PDF', 'PDF')),
                  ],
                  onChanged: (v) => setState(() {
                    _format = v;
                    _result = null;
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  count == 0 ? tr(context, _noData) : '$count ${tr(context, t('transactions will be exported', 'लेन-देन एक्सपोर्ट होंगे'))}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_busy || count == 0) ? null : _export,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(tr(context, t('Create file', 'फ़ाइल बनाएं'))),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                if (_result != null) OutputPanel(result: _result!),
              ],
            );
          },
        ),
      ),
    );
  }
}
