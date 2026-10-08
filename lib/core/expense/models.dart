import '../l10n/ltext.dart';
import '../personal/ids.dart';
import '../personal/models.dart' show Json, nowMs;

String _s(Object? v, int max) {
  if (v is! String) return '';
  return v.length > max ? v.substring(0, max) : v;
}

int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

/// Noon of a calendar day (so a transaction belongs to that day in any time zone).
int dayNoonMs(DateTime d) => DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch;

enum TxnType { expense, income }

// ============================ Categories ============================

enum CategoryKind { expense, income, both }

/// A category shown in the app (built-in or made by the person).
class CategoryInfo {
  final String id;
  final LText name;
  final CategoryKind kind;

  /// key understood by the UI to pick an icon
  final String iconKey;
  final int colorIndex;
  final bool custom;

  const CategoryInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.colorIndex,
    this.custom = false,
  });

  bool fits(TxnType type) =>
      kind == CategoryKind.both ||
      (type == TxnType.expense ? kind == CategoryKind.expense : kind == CategoryKind.income);
}

final List<CategoryInfo> defaultCategories = [
  CategoryInfo(id: 'food', name: t('Food', 'खाना'), kind: CategoryKind.expense, iconKey: 'food', colorIndex: 2),
  CategoryInfo(id: 'travel', name: t('Travel', 'यात्रा'), kind: CategoryKind.expense, iconKey: 'travel', colorIndex: 1),
  CategoryInfo(id: 'shopping', name: t('Shopping', 'खरीदारी'), kind: CategoryKind.expense, iconKey: 'shopping', colorIndex: 3),
  CategoryInfo(id: 'education', name: t('Education', 'शिक्षा'), kind: CategoryKind.expense, iconKey: 'education', colorIndex: 0),
  CategoryInfo(id: 'bills', name: t('Bills', 'बिल'), kind: CategoryKind.expense, iconKey: 'bills', colorIndex: 6),
  CategoryInfo(id: 'health', name: t('Health', 'स्वास्थ्य'), kind: CategoryKind.expense, iconKey: 'health', colorIndex: 4),
  CategoryInfo(id: 'entertainment', name: t('Entertainment', 'मनोरंजन'), kind: CategoryKind.expense, iconKey: 'entertainment', colorIndex: 5),
  CategoryInfo(id: 'other', name: t('Other', 'अन्य'), kind: CategoryKind.expense, iconKey: 'other', colorIndex: 7),
  CategoryInfo(id: 'salary', name: t('Salary', 'वेतन'), kind: CategoryKind.income, iconKey: 'salary', colorIndex: 4),
  CategoryInfo(id: 'business', name: t('Business', 'व्यापार'), kind: CategoryKind.income, iconKey: 'business', colorIndex: 1),
  CategoryInfo(id: 'gift', name: t('Gift', 'उपहार'), kind: CategoryKind.income, iconKey: 'gift', colorIndex: 3),
  CategoryInfo(id: 'other_income', name: t('Other income', 'अन्य आय'), kind: CategoryKind.income, iconKey: 'other', colorIndex: 7),
];

/// A category created by the person (stored in their account).
class CustomCategory {
  final String id;
  final String name;
  final CategoryKind kind;
  final int colorIndex;
  final int createdAt;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.colorIndex,
    required this.createdAt,
  });

  factory CustomCategory.create({required String name, required CategoryKind kind, int colorIndex = 0}) =>
      CustomCategory(id: 'c_${newId()}', name: name, kind: kind, colorIndex: colorIndex, createdAt: nowMs());

  CategoryInfo toInfo() => CategoryInfo(
        id: id,
        name: LText({'en': name, 'hi': name}),
        kind: kind,
        iconKey: 'label',
        colorIndex: colorIndex,
        custom: true,
      );

  Json toMap() => {'name': name, 'kind': kind.name, 'colorIndex': colorIndex, 'createdAt': createdAt};

  static CustomCategory? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final name = _s(m['name'], 40).trim();
    if (id.isEmpty || name.isEmpty) return null;
    final kind = CategoryKind.values.where((k) => k.name == m['kind']);
    return CustomCategory(
      id: id,
      name: name,
      kind: kind.isEmpty ? CategoryKind.expense : kind.first,
      colorIndex: _i(m['colorIndex']).clamp(0, 99),
      createdAt: _i(m['createdAt']),
    );
  }
}

/// Built-in categories followed by the person's own. Unknown ids fall back to "other".
List<CategoryInfo> allCategories(List<CustomCategory> custom) =>
    [...defaultCategories, for (final c in custom) c.toInfo()];

CategoryInfo categoryById(String id, List<CustomCategory> custom) {
  for (final c in defaultCategories) {
    if (c.id == id) return c;
  }
  for (final c in custom) {
    if (c.id == id) return c.toInfo();
  }
  return defaultCategories.firstWhere((c) => c.id == 'other');
}

// ============================ Transactions ============================

class ExpenseTxn {
  final String id;
  final TxnType type;

  /// Amount in rupees' minor units (paise): what reports and budgets use.
  final int amountMinor;
  final String categoryId;
  final String note;

  /// Noon of the day it happened (milliseconds).
  final int date;

  /// Currency the person paid in, the amount in that currency's minor units,
  /// and the rate used (rupees per 1 unit). For rupees: 'INR', same amount, 1.0.
  final String currency;
  final int origMinor;
  final double rate;

  /// set when a repeating rule created it
  final String recurringId;
  final int createdAt;
  final int updatedAt;

  const ExpenseTxn({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    this.note = '',
    required this.date,
    this.currency = 'INR',
    required this.origMinor,
    this.rate = 1.0,
    this.recurringId = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isForeign => currency != 'INR';

  factory ExpenseTxn.create({
    required TxnType type,
    required int amountMinor,
    required String categoryId,
    String note = '',
    required DateTime date,
    String currency = 'INR',
    int? origMinor,
    double rate = 1.0,
  }) {
    final now = nowMs();
    return ExpenseTxn(
      id: newId(),
      type: type,
      amountMinor: amountMinor,
      categoryId: categoryId,
      note: note,
      date: dayNoonMs(date),
      currency: currency,
      origMinor: origMinor ?? amountMinor,
      rate: rate,
      createdAt: now,
      updatedAt: now,
    );
  }

  ExpenseTxn copyWith({
    TxnType? type,
    int? amountMinor,
    String? categoryId,
    String? note,
    DateTime? date,
    String? currency,
    int? origMinor,
    double? rate,
  }) =>
      ExpenseTxn(
        id: id,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
        date: date == null ? this.date : dayNoonMs(date),
        currency: currency ?? this.currency,
        origMinor: origMinor ?? this.origMinor,
        rate: rate ?? this.rate,
        recurringId: recurringId,
        createdAt: createdAt,
        updatedAt: nowMs(),
      );

  Json toMap() => {
        'type': type.name,
        'amountMinor': amountMinor,
        'categoryId': categoryId,
        'note': note,
        'date': date,
        'currency': currency,
        'origMinor': origMinor,
        'rate': rate,
        'recurringId': recurringId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static ExpenseTxn? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final amount = _i(m['amountMinor']);
    final type = TxnType.values.where((t) => t.name == m['type']);
    if (id.isEmpty || type.isEmpty || amount < 1 || amount > 1000000000000) return null;
    final created = _i(m['createdAt']);
    final currency = _s(m['currency'], 3).isEmpty ? 'INR' : _s(m['currency'], 3).toUpperCase();
    final rate = _d(m['rate'], 1.0);
    return ExpenseTxn(
      id: id,
      type: type.first,
      amountMinor: amount,
      categoryId: _s(m['categoryId'], 80),
      note: _s(m['note'], 300),
      date: _i(m['date'], created),
      currency: currency,
      origMinor: _i(m['origMinor'], amount).clamp(1, 1000000000000),
      rate: rate > 0 && rate.isFinite ? rate : 1.0,
      recurringId: _s(m['recurringId'], 120),
      createdAt: created,
      updatedAt: _i(m['updatedAt'], created),
    );
  }
}

// ============================ Budgets ============================

enum BudgetPeriod { weekly, monthly }

class Budget {
  final String id;
  final BudgetPeriod period;

  /// '' = all spending; otherwise only this category
  final String categoryId;
  final int limitMinor;

  /// warn when this percent of the limit is used (50-100)
  final int warnPercent;
  final int createdAt;

  const Budget({
    required this.id,
    required this.period,
    this.categoryId = '',
    required this.limitMinor,
    this.warnPercent = 80,
    required this.createdAt,
  });

  factory Budget.create({
    required BudgetPeriod period,
    String categoryId = '',
    required int limitMinor,
    int warnPercent = 80,
  }) =>
      Budget(
        id: newId(),
        period: period,
        categoryId: categoryId,
        limitMinor: limitMinor,
        warnPercent: warnPercent,
        createdAt: nowMs(),
      );

  Json toMap() => {
        'period': period.name,
        'categoryId': categoryId,
        'limitMinor': limitMinor,
        'warnPercent': warnPercent,
        'createdAt': createdAt,
      };

  static Budget? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final limit = _i(m['limitMinor']);
    final period = BudgetPeriod.values.where((p) => p.name == m['period']);
    if (id.isEmpty || period.isEmpty || limit < 1 || limit > 1000000000000) return null;
    return Budget(
      id: id,
      period: period.first,
      categoryId: _s(m['categoryId'], 80),
      limitMinor: limit,
      warnPercent: _i(m['warnPercent'], 80).clamp(50, 100),
      createdAt: _i(m['createdAt']),
    );
  }
}

// ============================ Repeating transactions ============================

enum Frequency { daily, weekly, monthly, yearly }

class RecurringRule {
  final String id;
  final String title;
  final TxnType type;
  final int amountMinor;
  final String categoryId;
  final Frequency frequency;

  /// First occurrence (noon of that day). Later ones are counted from here.
  final int startDate;
  final bool active;

  /// Last occurrence that was already turned into a transaction (0 = none yet).
  /// Deleting a generated transaction therefore never brings it back.
  final int lastGenerated;
  final int createdAt;

  const RecurringRule({
    required this.id,
    required this.title,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    this.active = true,
    this.lastGenerated = 0,
    required this.createdAt,
  });

  factory RecurringRule.create({
    required String title,
    required TxnType type,
    required int amountMinor,
    required String categoryId,
    required Frequency frequency,
    required DateTime startDate,
  }) =>
      RecurringRule(
        id: newId(),
        title: title,
        type: type,
        amountMinor: amountMinor,
        categoryId: categoryId,
        frequency: frequency,
        startDate: dayNoonMs(startDate),
        createdAt: nowMs(),
      );

  RecurringRule copyWith({
    String? title,
    TxnType? type,
    int? amountMinor,
    String? categoryId,
    Frequency? frequency,
    DateTime? startDate,
    bool? active,
    int? lastGenerated,
  }) =>
      RecurringRule(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        categoryId: categoryId ?? this.categoryId,
        frequency: frequency ?? this.frequency,
        startDate: startDate == null ? this.startDate : dayNoonMs(startDate),
        active: active ?? this.active,
        lastGenerated: lastGenerated ?? this.lastGenerated,
        createdAt: createdAt,
      );

  Json toMap() => {
        'title': title,
        'type': type.name,
        'amountMinor': amountMinor,
        'categoryId': categoryId,
        'frequency': frequency.name,
        'startDate': startDate,
        'active': active,
        'lastGenerated': lastGenerated,
        'createdAt': createdAt,
      };

  static RecurringRule? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final amount = _i(m['amountMinor']);
    final type = TxnType.values.where((t) => t.name == m['type']);
    final freq = Frequency.values.where((f) => f.name == m['frequency']);
    final title = _s(m['title'], 100).trim();
    if (id.isEmpty || type.isEmpty || freq.isEmpty || title.isEmpty || amount < 1 || amount > 1000000000000) {
      return null;
    }
    return RecurringRule(
      id: id,
      title: title,
      type: type.first,
      amountMinor: amount,
      categoryId: _s(m['categoryId'], 80),
      frequency: freq.first,
      startDate: _i(m['startDate']),
      active: m['active'] != false,
      lastGenerated: _i(m['lastGenerated']),
      createdAt: _i(m['createdAt']),
    );
  }
}
