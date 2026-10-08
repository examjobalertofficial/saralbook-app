import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/expense/logic.dart';
import 'package:app/core/expense/models.dart';
import 'package:app/core/expense/money.dart';
import 'package:app/core/personal/logic.dart' show DateRange, ProgressPeriod, rangeFor;

ExpenseTxn txn(
  String id,
  TxnType type,
  int minor,
  DateTime day, {
  String cat = 'food',
  String note = '',
}) =>
    ExpenseTxn(
      id: id,
      type: type,
      amountMinor: minor,
      categoryId: cat,
      note: note,
      date: dayNoonMs(day),
      origMinor: minor,
      createdAt: dayNoonMs(day),
      updatedAt: dayNoonMs(day),
    );

RecurringRule rule(Frequency f, DateTime start, {int last = 0, bool active = true, String id = 'r1'}) => RecurringRule(
      id: id,
      title: 'Rent',
      type: TxnType.expense,
      amountMinor: 1000000,
      categoryId: 'bills',
      frequency: f,
      startDate: dayNoonMs(start),
      active: active,
      lastGenerated: last,
      createdAt: 1,
    );

void main() {
  budgetAlertTests();
  group('money', () {
    test('parseMinor accepts normal amounts', () {
      expect(parseMinor('250'), 25000);
      expect(parseMinor('250.5'), 25050);
      expect(parseMinor('1,250.75'), 125075);
      expect(parseMinor(' 0.01 '), 1);
      expect(parseMinor('100.'), isNull);
    });

    test('parseMinor rejects bad input', () {
      for (final bad in ['', 'abc', '-5', '0', '0.00', '1.234', '12e3', '1,2,3x', '9999999999999']) {
        expect(parseMinor(bad), isNull, reason: bad);
      }
    });

    test('no floating point surprises when adding', () {
      expect(parseMinor('0.1')! + parseMinor('0.2')!, parseMinor('0.3'));
    });

    test('formatInr uses Indian grouping', () {
      expect(formatInr(0), '₹0.00');
      expect(formatInr(99999), '₹999.99');
      expect(formatInr(123456789), '₹12,34,567.89');
      expect(formatInr(-50000), '-₹500.00');
      expect(formatInr(25000, showSign: true), '+₹250.00');
      expect(formatInrShort(123456789), '₹12,34,568');
      expect(formatInrShort(-5049), '-₹50');
    });

    test('formatForeign / minorToPlain', () {
      expect(formatForeign(12500050, 'USD'), 'USD 125,000.50');
      expect(minorToPlain(123450), '1234.50');
      expect(minorToPlain(5), '0.05');
    });
  });

  group('filter, sort, group', () {
    final a = txn('a', TxnType.expense, 10000, DateTime(2026, 10, 5), cat: 'food', note: 'Lunch with team');
    final b = txn('b', TxnType.income, 5000000, DateTime(2026, 10, 1), cat: 'salary', note: 'October salary');
    final c = txn('c', TxnType.expense, 25050, DateTime(2026, 10, 5), cat: 'travel', note: 'Bus');
    final d = txn('d', TxnType.expense, 9900, DateTime(2026, 9, 20), cat: 'food', note: 'Snacks');
    final all = [a, b, c, d];

    test('sorted newest first', () {
      expect(sortTxns(all).map((e) => e.id).first, anyOf('a', 'c'));
      expect(sortTxns(all).map((e) => e.id).last, 'd');
    });

    test('filters by type, category, range and text', () {
      expect(applyFilter(all, const TxnFilter(type: TxnType.income)).map((e) => e.id), ['b']);
      expect(applyFilter(all, const TxnFilter(categoryId: 'food')).map((e) => e.id).toSet(), {'a', 'd'});
      final oct = DateRange(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      expect(applyFilter(all, TxnFilter(range: oct)).length, 3);
      expect(applyFilter(all, const TxnFilter(query: 'salary')).map((e) => e.id), ['b']);
      expect(applyFilter(all, const TxnFilter(query: '250.50')).map((e) => e.id), ['c']);
      expect(applyFilter(all, const TxnFilter(query: 'TRAVEL'), nameOf: (id) => id).map((e) => e.id), ['c']);
      expect(applyFilter(all, const TxnFilter(query: 'zzz')), isEmpty);
      expect(const TxnFilter().isEmpty, isTrue);
    });

    test('grouped by day', () {
      final groups = groupByDay(sortTxns(all));
      expect(groups.map((g) => g.day), [DateTime(2026, 10, 5), DateTime(2026, 10, 1), DateTime(2026, 9, 20)]);
      expect(groups.first.items.length, 2);
      expect(groupByDay([]), isEmpty);
    });
  });

  group('summaries and reports', () {
    final now = DateTime(2026, 10, 7, 12); // Wednesday
    final txns = [
      txn('1', TxnType.income, 5000000, DateTime(2026, 10, 1), cat: 'salary'),
      txn('2', TxnType.expense, 120000, DateTime(2026, 10, 5), cat: 'food'),
      txn('3', TxnType.expense, 80000, DateTime(2026, 10, 7), cat: 'food'),
      txn('4', TxnType.expense, 300000, DateTime(2026, 10, 7), cat: 'travel'),
      txn('5', TxnType.expense, 700000, DateTime(2026, 9, 30), cat: 'bills'),
      txn('6', TxnType.income, 200000, DateTime(2026, 9, 15), cat: 'gift'),
    ];

    test('summary and savings', () {
      final s = summarize(inRange(txns, rangeFor(ProgressPeriod.month, now)));
      expect((s.income, s.expense, s.savings), (5000000, 500000, 4500000));
      final w = summarize(inRange(txns, rangeFor(ProgressPeriod.week, now)));
      expect((w.income, w.expense), (0, 500000));
    });

    test('category breakdown, biggest first, per type', () {
      final r = categoryTotals(txns, TxnType.expense);
      expect(r.map((e) => '${e.categoryId}:${e.totalMinor}').toList(), ['bills:700000', 'travel:300000', 'food:200000']);
      expect(categoryTotals(txns, TxnType.income).first.categoryId, 'salary');
    });

    test('daily totals include empty days', () {
      final d = dailyTotals(txns, rangeFor(ProgressPeriod.week, now));
      expect(d.length, 7); // Mon 5 .. Sun 11
      expect(d[0].expense, 120000); // 5th
      expect(d[2].expense, 380000); // 7th
      expect(d[1].expense, 0);
    });

    test('monthly trend: oldest first, spans year boundary', () {
      final m = monthlyTotals(txns, now, months: 3);
      expect(m.map((e) => e.month.month).toList(), [8, 9, 10]);
      expect(m[1].expense, 700000);
      expect(m[1].income, 200000);
      expect(m[2].income, 5000000);
      final jan = monthlyTotals(txns, DateTime(2027, 1, 15), months: 3);
      expect(jan.map((e) => '${e.month.year}-${e.month.month}').toList(), ['2026-11', '2026-12', '2027-1']);
    });
  });

  group('budgets', () {
    final now = DateTime(2026, 10, 7, 12);
    final txns = [
      txn('1', TxnType.expense, 40000, DateTime(2026, 10, 5), cat: 'food'),
      txn('2', TxnType.expense, 60000, DateTime(2026, 10, 7), cat: 'travel'),
      txn('3', TxnType.expense, 100000, DateTime(2026, 10, 1), cat: 'food'),
      txn('4', TxnType.income, 999999, DateTime(2026, 10, 2), cat: 'salary'),
      txn('5', TxnType.expense, 500000, DateTime(2026, 9, 29), cat: 'food'),
    ];

    test('monthly overall counts only this month expenses', () {
      final b = Budget(id: 'b', period: BudgetPeriod.monthly, limitMinor: 500000, createdAt: 1);
      final s = budgetStatus(b, txns, now);
      expect(s.spentMinor, 200000);
      expect(s.remainingMinor, 300000);
      expect(s.state, BudgetState.ok);
    });

    test('weekly budget uses Monday to Sunday', () {
      final b = Budget(id: 'b', period: BudgetPeriod.weekly, limitMinor: 100000, createdAt: 1);
      final s = budgetStatus(b, txns, now);
      expect(s.spentMinor, 100000); // 5th and 7th only
      expect(s.state, BudgetState.warning); // exactly at the limit is a warning, not exceeded
    });

    test('category budget', () {
      final b = Budget(id: 'b', period: BudgetPeriod.monthly, categoryId: 'food', limitMinor: 120000, createdAt: 1);
      final s = budgetStatus(b, txns, now);
      expect(s.spentMinor, 140000);
      expect(s.state, BudgetState.exceeded);
      expect(s.remainingMinor, -20000);
      expect(s.fraction, closeTo(1.1667, 0.001));
    });

    test('warning threshold', () {
      Budget b(int warn) =>
          Budget(id: 'b', period: BudgetPeriod.monthly, limitMinor: 250000, warnPercent: warn, createdAt: 1);
      expect(budgetStatus(b(80), txns, now).state, BudgetState.warning); // 200000/250000 = 80%
      expect(budgetStatus(b(90), txns, now).state, BudgetState.ok);
    });
  });

  group('repeating transactions', () {
    test('monthly keeps the day, clamps short months', () {
      final r = rule(Frequency.monthly, DateTime(2026, 1, 31));
      final days = occurrencesUpTo(r, DateTime(2026, 5, 31)).map((d) => '${d.month}-${d.day}').toList();
      expect(days, ['1-31', '2-28', '3-31', '4-30', '5-31']);
    });

    test('yearly on 29 Feb moves to 28 Feb in normal years', () {
      final r = rule(Frequency.yearly, DateTime(2024, 2, 29));
      final days = occurrencesUpTo(r, DateTime(2026, 12, 31)).map((d) => '${d.year}-${d.month}-${d.day}').toList();
      expect(days, ['2024-2-29', '2025-2-28', '2026-2-28']);
    });

    test('weekly and daily', () {
      expect(occurrencesUpTo(rule(Frequency.weekly, DateTime(2026, 10, 1)), DateTime(2026, 10, 22)).length, 4);
      expect(occurrencesUpTo(rule(Frequency.daily, DateTime(2026, 10, 1)), DateTime(2026, 10, 7)).length, 7);
    });

    test('nothing before the start date', () {
      expect(occurrencesUpTo(rule(Frequency.monthly, DateTime(2026, 12, 1)), DateTime(2026, 10, 7)), isEmpty);
    });

    test('catch-up is capped', () {
      final r = rule(Frequency.daily, DateTime(2020, 1, 1));
      expect(occurrencesUpTo(r, DateTime(2026, 10, 7)).length, maxCatchUp);
    });

    test('next occurrence', () {
      final r = rule(Frequency.monthly, DateTime(2026, 1, 15));
      expect(nextOccurrence(r, DateTime(2026, 10, 7)), DateTime(2026, 10, 15, 12));
      expect(nextOccurrence(r, DateTime(2026, 10, 15)), DateTime(2026, 11, 15, 12));
    });

    test('plan creates one transaction per due day with fixed ids', () {
      final r = rule(Frequency.monthly, DateTime(2026, 8, 5));
      final plans = planRecurring([r], DateTime(2026, 10, 7));
      expect(plans.length, 1);
      final p = plans.single;
      expect(p.txns.map((t) => t.id), ['rec_r1_20260805', 'rec_r1_20260905', 'rec_r1_20261005']);
      expect(p.txns.every((t) => t.recurringId == 'r1' && t.amountMinor == 1000000 && t.note == 'Rent'), isTrue);
      expect(p.newLastGenerated, p.txns.last.date);
    });

    test('running again creates nothing new (no duplicates)', () {
      final r = rule(Frequency.monthly, DateTime(2026, 8, 5));
      final first = planRecurring([r], DateTime(2026, 10, 7)).single;
      final after = r.copyWith(lastGenerated: first.newLastGenerated);
      expect(planRecurring([after], DateTime(2026, 10, 7)), isEmpty);
      // next month only the new occurrence
      final next = planRecurring([after], DateTime(2026, 11, 6)).single;
      expect(next.txns.map((t) => t.id), ['rec_r1_20261105']);
    });

    test('deleting a generated transaction does not bring it back', () {
      final r = rule(Frequency.monthly, DateTime(2026, 8, 5));
      final first = planRecurring([r], DateTime(2026, 10, 7)).single;
      final after = r.copyWith(lastGenerated: first.newLastGenerated);
      // pretend the person deleted the Sept transaction; the rule remembers it was generated
      expect(planRecurring([after], DateTime(2026, 10, 8)), isEmpty);
    });

    test('paused rules create nothing; resuming skips the missed period', () {
      final r = rule(Frequency.monthly, DateTime(2026, 1, 5), active: false);
      expect(planRecurring([r], DateTime(2026, 10, 7)), isEmpty);
      final resumed = resumeRule(r, DateTime(2026, 10, 7));
      expect(resumed.active, isTrue);
      expect(planRecurring([resumed], DateTime(2026, 10, 7)), isEmpty); // nothing from the paused months
      final nov = planRecurring([resumed], DateTime(2026, 11, 6)).single;
      expect(nov.txns.map((t) => t.id), ['rec_r1_20261105']);
    });

    test('generated ids are the same on every phone', () {
      expect(recurringTxnId('abc', DateTime(2026, 3, 9)), 'rec_abc_20260309');
    });
  });

  group('model validation', () {
    test('transaction round trip and damaged data', () {
      final t = ExpenseTxn.create(
        type: TxnType.expense,
        amountMinor: 12345,
        categoryId: 'food',
        note: 'Tea',
        date: DateTime(2026, 10, 7, 23, 59),
      );
      final back = ExpenseTxn.fromMap({...t.toMap(), 'id': t.id})!;
      expect(back.amountMinor, 12345);
      expect(DateTime.fromMillisecondsSinceEpoch(back.date).day, 7);
      expect(DateTime.fromMillisecondsSinceEpoch(back.date).hour, 12);
      expect(ExpenseTxn.fromMap({'id': 'x', 'type': 'expense', 'amountMinor': 0}), isNull);
      expect(ExpenseTxn.fromMap({'id': 'x', 'type': 'oops', 'amountMinor': 5}), isNull);
      expect(ExpenseTxn.fromMap({'type': 'expense', 'amountMinor': 5}), isNull);
      expect(ExpenseTxn.fromMap({'id': 'x', 'type': 'expense', 'amountMinor': 5, 'rate': -3})!.rate, 1.0);
      expect(ExpenseTxn.fromMap({'id': 'x', 'type': 'expense', 'amountMinor': 5, 'currency': 'usd'})!.currency, 'USD');
    });

    test('budget, rule and category validation', () {
      expect(Budget.fromMap({'id': 'b', 'period': 'yearly', 'limitMinor': 5}), isNull);
      expect(Budget.fromMap({'id': 'b', 'period': 'weekly', 'limitMinor': 0}), isNull);
      expect(Budget.fromMap({'id': 'b', 'period': 'weekly', 'limitMinor': 5, 'warnPercent': 5})!.warnPercent, 50);
      expect(RecurringRule.fromMap({'id': 'r', 'title': ' ', 'type': 'expense', 'amountMinor': 5, 'frequency': 'daily'}), isNull);
      expect(CustomCategory.fromMap({'id': 'c', 'name': '  '}), isNull);
      expect(CustomCategory.fromMap({'id': 'c', 'name': 'Pets', 'kind': 'zzz'})!.kind, CategoryKind.expense);
    });

    test('category lookup falls back to "other"; kinds fit the right type', () {
      const custom = <CustomCategory>[];
      expect(categoryById('food', custom).id, 'food');
      expect(categoryById('deleted_one', custom).id, 'other');
      final c = CustomCategory.create(name: 'Pets', kind: CategoryKind.both);
      expect(categoryById(c.id, [c]).name.of('en'), 'Pets');
      expect(allCategories([c]).length, defaultCategories.length + 1);
      expect(defaultCategories.firstWhere((x) => x.id == 'salary').fits(TxnType.income), isTrue);
      expect(defaultCategories.firstWhere((x) => x.id == 'salary').fits(TxnType.expense), isFalse);
      expect(c.toInfo().fits(TxnType.expense) && c.toInfo().fits(TxnType.income), isTrue);
    });

    test('every default category has Hindi and English names', () {
      for (final c in defaultCategories) {
        expect(c.name.of('en'), isNotEmpty);
        expect(c.name.of('hi'), isNotEmpty);
      }
    });
  });
}

void budgetAlertTests() {
  group('budget alerts for a new expense', () {
    final now = DateTime(2026, 10, 7, 12);
    final food = Budget(id: 'b1', period: BudgetPeriod.monthly, categoryId: 'food', limitMinor: 100000, createdAt: 1);
    final all = Budget(id: 'b2', period: BudgetPeriod.monthly, limitMinor: 300000, createdAt: 1);

    test('tells you when a budget becomes exceeded', () {
      final existing = [txn('1', TxnType.expense, 90000, DateTime(2026, 10, 2), cat: 'food')];
      final added = txn('2', TxnType.expense, 20000, DateTime(2026, 10, 7), cat: 'food');
      final alerts = budgetAlertsFor(budgets: [food, all], existing: existing, added: added, now: now);
      expect(alerts.map((a) => a.budget.id), ['b1']);
      expect(alerts.single.state, BudgetState.exceeded);
    });

    test('tells you about the warning level once', () {
      final existing = [txn('1', TxnType.expense, 50000, DateTime(2026, 10, 2), cat: 'food')];
      final added = txn('2', TxnType.expense, 35000, DateTime(2026, 10, 7), cat: 'food');
      final alerts = budgetAlertsFor(budgets: [food], existing: existing, added: added, now: now);
      expect(alerts.single.state, BudgetState.warning);
      // a further small expense that stays in the same state gives no new alert
      final more = txn('3', TxnType.expense, 1000, DateTime(2026, 10, 7), cat: 'food');
      expect(budgetAlertsFor(budgets: [food], existing: [...existing, added], added: more, now: now), isEmpty);
    });

    test('other categories and income never trigger alerts', () {
      final added = txn('2', TxnType.expense, 999999, DateTime(2026, 10, 7), cat: 'travel');
      expect(budgetAlertsFor(budgets: [food], existing: const [], added: added, now: now), isEmpty);
      final income = txn('3', TxnType.income, 999999, DateTime(2026, 10, 7), cat: 'salary');
      expect(budgetAlertsFor(budgets: [all], existing: const [], added: income, now: now), isEmpty);
    });
  });
}
