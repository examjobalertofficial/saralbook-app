import 'dart:math' as math;

import '../personal/logic.dart' show DateRange, ProgressPeriod, dayOf, rangeFor;
import '../tools/calc_math.dart' show daysInMonth;
import 'models.dart';

/// Pure functions behind the expense screens (tested without Flutter/Firebase).

// ============================ Lists & filters ============================

/// Newest day first; within a day the latest entry first.
List<ExpenseTxn> sortTxns(Iterable<ExpenseTxn> txns) {
  final list = List<ExpenseTxn>.of(txns);
  list.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  });
  return list;
}

class TxnFilter {
  final DateRange? range;
  final TxnType? type;
  final String? categoryId;
  final String query;
  const TxnFilter({this.range, this.type, this.categoryId, this.query = ''});

  bool get isEmpty => range == null && type == null && categoryId == null && query.trim().isEmpty;
}

/// [nameOf] turns a category id into text so search can match category names.
List<ExpenseTxn> applyFilter(
  Iterable<ExpenseTxn> txns,
  TxnFilter f, {
  String Function(String categoryId)? nameOf,
}) {
  final q = f.query.trim().toLowerCase();
  return sortTxns([
    for (final t in txns)
      if ((f.range == null || f.range!.contains(t.date)) &&
          (f.type == null || t.type == f.type) &&
          (f.categoryId == null || t.categoryId == f.categoryId) &&
          (q.isEmpty ||
              t.note.toLowerCase().contains(q) ||
              (nameOf != null && nameOf(t.categoryId).toLowerCase().contains(q)) ||
              (t.amountMinor / 100).toStringAsFixed(2).contains(q)))
        t,
  ]);
}

/// Groups an already sorted list by calendar day (order is kept).
List<({DateTime day, List<ExpenseTxn> items})> groupByDay(List<ExpenseTxn> sorted) {
  final out = <({DateTime day, List<ExpenseTxn> items})>[];
  DateTime? current;
  var bucket = <ExpenseTxn>[];
  for (final t in sorted) {
    final d = dayOf(DateTime.fromMillisecondsSinceEpoch(t.date));
    if (current == null || d != current) {
      if (current != null) out.add((day: current, items: bucket));
      current = d;
      bucket = [];
    }
    bucket.add(t);
  }
  if (current != null) out.add((day: current, items: bucket));
  return out;
}

// ============================ Totals & reports ============================

class Summary {
  final int income;
  final int expense;
  const Summary(this.income, this.expense);
  int get savings => income - expense;
}

Summary summarize(Iterable<ExpenseTxn> txns) {
  var income = 0;
  var expense = 0;
  for (final t in txns) {
    if (t.type == TxnType.income) {
      income += t.amountMinor;
    } else {
      expense += t.amountMinor;
    }
  }
  return Summary(income, expense);
}

List<ExpenseTxn> inRange(Iterable<ExpenseTxn> txns, DateRange range) =>
    [for (final t in txns) if (range.contains(t.date)) t];

class CategoryTotal {
  final String categoryId;
  final int totalMinor;
  const CategoryTotal(this.categoryId, this.totalMinor);
}

/// Biggest first.
List<CategoryTotal> categoryTotals(Iterable<ExpenseTxn> txns, TxnType type) {
  final map = <String, int>{};
  for (final t in txns) {
    if (t.type != type) continue;
    map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountMinor;
  }
  final list = [for (final e in map.entries) CategoryTotal(e.key, e.value)];
  list.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  return list;
}

/// One entry for every day of [range] (zeros when nothing happened).
List<({DateTime day, int income, int expense})> dailyTotals(Iterable<ExpenseTxn> txns, DateRange range) {
  final income = <DateTime, int>{};
  final expense = <DateTime, int>{};
  for (final t in txns) {
    if (!range.contains(t.date)) continue;
    final d = dayOf(DateTime.fromMillisecondsSinceEpoch(t.date));
    final target = t.type == TxnType.income ? income : expense;
    target[d] = (target[d] ?? 0) + t.amountMinor;
  }
  return [
    for (var i = 0; i < range.days; i++)
      () {
        final d = DateTime(range.start.year, range.start.month, range.start.day + i);
        return (day: d, income: income[d] ?? 0, expense: expense[d] ?? 0);
      }(),
  ];
}

/// The last [months] calendar months up to and including this one (oldest first).
List<({DateTime month, int income, int expense})> monthlyTotals(
  Iterable<ExpenseTxn> txns,
  DateTime now, {
  int months = 6,
}) {
  final out = <({DateTime month, int income, int expense})>[];
  for (var i = months - 1; i >= 0; i--) {
    final start = DateTime(now.year, now.month - i, 1);
    final end = DateTime(start.year, start.month + 1, 1);
    final s = summarize(inRange(txns, DateRange(start, end)));
    out.add((month: start, income: s.income, expense: s.expense));
  }
  return out;
}

// ============================ Budgets ============================

enum BudgetState { ok, warning, exceeded }

class BudgetStatus {
  final Budget budget;
  final int spentMinor;
  const BudgetStatus(this.budget, this.spentMinor);

  int get remainingMinor => budget.limitMinor - spentMinor;

  /// spent / limit, can be above 1 when exceeded
  double get fraction => spentMinor / budget.limitMinor;

  BudgetState get state {
    if (spentMinor > budget.limitMinor) return BudgetState.exceeded;
    // whole-number maths (no floating point error exactly at the threshold)
    if (spentMinor * 100 >= budget.warnPercent * budget.limitMinor) return BudgetState.warning;
    return BudgetState.ok;
  }
}

DateRange budgetRange(BudgetPeriod p, DateTime now) =>
    rangeFor(p == BudgetPeriod.weekly ? ProgressPeriod.week : ProgressPeriod.month, now);

BudgetStatus budgetStatus(Budget b, Iterable<ExpenseTxn> txns, DateTime now) {
  final range = budgetRange(b.period, now);
  var spent = 0;
  for (final t in txns) {
    if (t.type != TxnType.expense || !range.contains(t.date)) continue;
    if (b.categoryId.isNotEmpty && t.categoryId != b.categoryId) continue;
    spent += t.amountMinor;
  }
  return BudgetStatus(b, spent);
}

// ============================ Repeating transactions ============================

DateTime _occurrence(RecurringRule r, int n) {
  final s = DateTime.fromMillisecondsSinceEpoch(r.startDate);
  switch (r.frequency) {
    case Frequency.daily:
      return DateTime(s.year, s.month, s.day + n, 12);
    case Frequency.weekly:
      return DateTime(s.year, s.month, s.day + 7 * n, 12);
    case Frequency.monthly:
      final m0 = s.month - 1 + n;
      final y = s.year + m0 ~/ 12;
      final m = m0 % 12 + 1;
      return DateTime(y, m, math.min(s.day, daysInMonth(y, m)), 12);
    case Frequency.yearly:
      final y = s.year + n;
      return DateTime(y, s.month, math.min(s.day, daysInMonth(y, s.month)), 12);
  }
}

const int maxCatchUp = 400;

/// Occurrences after [afterMs] (exclusive) up to and including the day of [today].
/// At most the most recent [maxCatchUp] are returned.
List<DateTime> occurrencesUpTo(RecurringRule r, DateTime today, {int afterMs = 0}) {
  final last = dayOf(today);
  final out = <DateTime>[];
  for (var n = 0; n < 40000; n++) {
    final d = _occurrence(r, n);
    if (dayOf(d).isAfter(last)) break;
    if (d.millisecondsSinceEpoch > afterMs) out.add(d);
  }
  return out.length > maxCatchUp ? out.sublist(out.length - maxCatchUp) : out;
}

/// First occurrence strictly after today (for "next on ...").
DateTime nextOccurrence(RecurringRule r, DateTime today) {
  final t = dayOf(today);
  for (var n = 0; n < 40000; n++) {
    final d = _occurrence(r, n);
    if (dayOf(d).isAfter(t)) return d;
  }
  return _occurrence(r, 40000);
}

String _ymd(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// The id is fixed by rule + day, so two phones creating the same occurrence
/// write the same record (no duplicates).
String recurringTxnId(String ruleId, DateTime day) => 'rec_${ruleId}_${_ymd(day)}';

class RecurringPlan {
  final RecurringRule rule;
  final List<ExpenseTxn> txns;
  final int newLastGenerated;
  const RecurringPlan(this.rule, this.txns, this.newLastGenerated);
}

/// What needs to be created today for every active rule.
List<RecurringPlan> planRecurring(Iterable<RecurringRule> rules, DateTime today) {
  final plans = <RecurringPlan>[];
  for (final r in rules) {
    if (!r.active) continue;
    final due = occurrencesUpTo(r, today, afterMs: r.lastGenerated);
    if (due.isEmpty) continue;
    plans.add(RecurringPlan(
      r,
      [
        for (final d in due)
          ExpenseTxn(
            id: recurringTxnId(r.id, d),
            type: r.type,
            amountMinor: r.amountMinor,
            categoryId: r.categoryId,
            note: r.title,
            date: d.millisecondsSinceEpoch,
            origMinor: r.amountMinor,
            recurringId: r.id,
            createdAt: d.millisecondsSinceEpoch,
            updatedAt: d.millisecondsSinceEpoch,
          ),
      ],
      due.last.millisecondsSinceEpoch,
    ));
  }
  return plans;
}

/// Resuming a paused rule skips what was missed while it was paused.
RecurringRule resumeRule(RecurringRule r, DateTime today) {
  final startOfToday = dayOf(today).millisecondsSinceEpoch;
  return r.copyWith(active: true, lastGenerated: math.max(r.lastGenerated, startOfToday - 1));
}

/// Budgets that just became "warning" or "exceeded" because of [added]
/// (so the person is told once, when it happens). [existing] must NOT contain [added].
List<BudgetStatus> budgetAlertsFor({
  required Iterable<Budget> budgets,
  required Iterable<ExpenseTxn> existing,
  required ExpenseTxn added,
  required DateTime now,
}) {
  if (added.type != TxnType.expense) return const [];
  final after = [...existing, added];
  final alerts = <BudgetStatus>[];
  for (final b in budgets) {
    if (b.categoryId.isNotEmpty && b.categoryId != added.categoryId) continue;
    final before = budgetStatus(b, existing, now).state;
    final now2 = budgetStatus(b, after, now);
    if (now2.state.index > before.index) alerts.add(now2);
  }
  return alerts;
}
