import 'package:flutter/material.dart';

import '../../core/expense/logic.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart' show DateRange, ProgressPeriod, dayOf, rangeFor;
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'expense_ui.dart';

final LText _title = t('Reports', 'रिपोर्ट');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Reports(data: data));
}

enum _Mode { week, month, custom }

class _Reports extends StatefulWidget {
  final PersonalData data;
  const _Reports({required this.data});

  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  _Mode _mode = _Mode.month;
  int _offset = 0; // 0 = current week/month, -1 = previous ...
  DateRange? _custom;

  static final LText _incomeVsExpense = t('Income vs expense', 'आय बनाम खर्च');
  static final LText _byCategory = t('Spending by category', 'श्रेणी के अनुसार खर्च');
  static final LText _trend = t('Last 6 months', 'पिछले 6 महीने');
  static final LText _noSpend = t('No spending in this period.', 'इस अवधि में कोई खर्च नहीं।');

  DateRange get _range {
    final now = DateTime.now();
    switch (_mode) {
      case _Mode.week:
        final base = rangeFor(ProgressPeriod.week, now);
        final start = DateTime(base.start.year, base.start.month, base.start.day + 7 * _offset);
        return DateRange(start, DateTime(start.year, start.month, start.day + 7));
      case _Mode.month:
        final start = DateTime(now.year, now.month + _offset, 1);
        return DateRange(start, DateTime(start.year, start.month + 1, 1));
      case _Mode.custom:
        return _custom ?? rangeFor(ProgressPeriod.month, now);
    }
  }

  String _rangeText(DateRange r) {
    if (_mode == _Mode.month) return monthLabel(r.start);
    final last = DateTime(r.endExclusive.year, r.endExclusive.month, r.endExclusive.day - 1);
    return '${fmtDate(r.start)} – ${fmtDate(last)}';
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: _range.start, end: DateTime(_range.endExclusive.year, _range.endExclusive.month, _range.endExclusive.day - 1)),
    );
    if (picked == null) return;
    setState(() {
      _mode = _Mode.custom;
      _custom = DateRange(dayOf(picked.start), DateTime(picked.end.year, picked.end.month, picked.end.day + 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.expenses, data.expenseCategories]),
          builder: (context, _) {
            if (!data.expenses.loaded) return const Center(child: CircularProgressIndicator());
            final all = data.expenses.items;
            final range = _range;
            final inPeriod = inRange(all, range);
            final sum = summarize(inPeriod);
            final cats = categoryTotals(inPeriod, TxnType.expense);
            final totalExpense = sum.expense;

            // chart: per day for up to ~2 months, otherwise per month
            List<int> inc, exp;
            List<String> labels;
            if (range.days <= 62) {
              final daily = dailyTotals(inPeriod, range);
              inc = [for (final d in daily) d.income];
              exp = [for (final d in daily) d.expense];
              final many = daily.length > 10;
              labels = [
                for (final d in daily) (!many || d.day.day == 1 || d.day.day % 5 == 0) ? '${d.day.day}' : '',
              ];
            } else {
              final months = <({DateTime month, int income, int expense})>[];
              var cursor = DateTime(range.start.year, range.start.month, 1);
              while (cursor.isBefore(range.endExclusive) && months.length < 36) {
                final next = DateTime(cursor.year, cursor.month + 1, 1);
                final s = summarize(inRange(inPeriod, DateRange(cursor, next)));
                months.add((month: cursor, income: s.income, expense: s.expense));
                cursor = next;
              }
              inc = [for (final m in months) m.income];
              exp = [for (final m in months) m.expense];
              labels = [for (final m in months) '${m.month.month}'];
            }

            final trend = monthlyTotals(all, DateTime.now());
            const monthNames = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SyncProblemBanner(visible: data.expenses.hasError),
                ChipRow<_Mode>(
                  value: _mode,
                  options: [
                    (_Mode.week, t('Weekly', 'साप्ताहिक')),
                    (_Mode.month, t('Monthly', 'मासिक')),
                    (_Mode.custom, t('Custom', 'अपनी रेंज')),
                  ],
                  onChanged: (m) {
                    if (m == _Mode.custom) {
                      _pickCustom();
                    } else {
                      setState(() {
                        _mode = m;
                        _offset = 0;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_mode != _Mode.custom)
                      IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _offset--)),
                    Expanded(
                      child: Text(
                        _rangeText(range),
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_mode != _Mode.custom)
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _offset >= 0 ? null : () => setState(() => _offset++),
                      )
                    else
                      IconButton(icon: const Icon(Icons.edit_calendar_outlined), onPressed: _pickCustom),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: AmountCard(label: tr(context, typeLabel(TxnType.income)), value: formatInr(sum.income), color: incomeColor(context))),
                    const SizedBox(width: 10),
                    Expanded(child: AmountCard(label: tr(context, typeLabel(TxnType.expense)), value: formatInr(sum.expense), color: expenseColor(context))),
                  ],
                ),
                const SizedBox(height: 10),
                AmountCard(
                  label: tr(context, t('Savings', 'बचत')),
                  value: formatInr(sum.savings, showSign: true),
                  color: sum.savings >= 0 ? incomeColor(context) : expenseColor(context),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: tr(context, _incomeVsExpense),
                  child: PairBarChart(income: inc, expense: exp, labels: labels),
                ),
                SectionCard(
                  title: tr(context, _byCategory),
                  child: cats.isEmpty
                      ? Text(tr(context, _noSpend), style: TextStyle(color: scheme.onSurfaceVariant))
                      : Column(
                          children: [
                            DonutChart(
                              values: [for (final c in cats) c.totalMinor.toDouble()],
                              colors: [for (final c in cats) categoryColor(categoryFor(data, c.categoryId))],
                              center: Text(formatInrShort(totalExpense), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 12),
                            for (final c in cats)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    CircleAvatar(radius: 6, backgroundColor: categoryColor(categoryFor(data, c.categoryId))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(categoryName(context, categoryFor(data, c.categoryId)))),
                                    Text('${(c.totalMinor * 100 / totalExpense).round()}%', style: TextStyle(color: scheme.onSurfaceVariant)),
                                    const SizedBox(width: 12),
                                    Text(formatInr(c.totalMinor), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                SectionCard(
                  title: tr(context, _trend),
                  child: PairBarChart(
                    income: [for (final m in trend) m.income],
                    expense: [for (final m in trend) m.expense],
                    labels: [for (final m in trend) monthNames[m.month.month - 1]],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
