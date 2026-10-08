import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';

IconData categoryIcon(String key) => switch (key) {
      'food' => Icons.restaurant_rounded,
      'travel' => Icons.directions_bus_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'education' => Icons.school_rounded,
      'bills' => Icons.receipt_long_rounded,
      'health' => Icons.medical_services_rounded,
      'entertainment' => Icons.movie_rounded,
      'salary' => Icons.payments_rounded,
      'business' => Icons.storefront_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'label' => Icons.label_rounded,
      _ => Icons.category_rounded,
    };

Color categoryColor(CategoryInfo c) => subjectColor(c.colorIndex);

Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent.shade200 : Colors.green.shade700;

Color expenseColor(BuildContext context) => Theme.of(context).colorScheme.error;

CategoryInfo categoryFor(PersonalData data, String id) => categoryById(id, data.expenseCategories.items);

String categoryName(BuildContext context, CategoryInfo c) => tr(context, c.name);

LText typeLabel(TxnType t) => t == TxnType.income ? _income : _expense;
final LText _income = t('Income', 'आय');
final LText _expense = t('Expense', 'खर्च');

/// "Today", "Yesterday" or "Mon, 7 Oct 2026".
String dayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return tr(context, t('Today', 'आज'));
  if (diff == 1) return tr(context, t('Yesterday', 'कल'));
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[day.weekday - 1]}, ${day.day} ${months[day.month - 1]} ${day.year}';
}

String monthLabel(DateTime d) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[d.month - 1]} ${d.year}';
}

/// One transaction row.
class TxnTile extends StatelessWidget {
  final ExpenseTxn txn;
  final CategoryInfo category;
  final VoidCallback onTap;
  const TxnTile({super.key, required this.txn, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = txn.type == TxnType.income;
    final color = categoryColor(category);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(36),
        child: Icon(categoryIcon(category.iconKey), color: color, size: 22),
      ),
      title: Text(
        txn.note.isEmpty ? categoryName(context, category) : txn.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (txn.note.isNotEmpty) categoryName(context, category),
          if (txn.isForeign) formatForeign(txn.origMinor, txn.currency),
          if (txn.recurringId.isNotEmpty) tr(context, t('Repeating', 'दोहराव')),
        ].join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Text(
        '${income ? '+' : '-'}${formatInr(txn.amountMinor)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: income ? incomeColor(context) : expenseColor(context)),
      ),
    );
  }
}

/// Filled card with a label and a value.
class AmountCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const AmountCard({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income (green) and expense (red) bars side by side for each period.
class PairBarChart extends StatelessWidget {
  final List<int> income;
  final List<int> expense;
  final List<String> labels; // '' = no label under that bar
  const PairBarChart({super.key, required this.income, required this.expense, required this.labels});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var maxV = 1;
    for (final v in [...income, ...expense]) {
      maxV = math.max(maxV, v);
    }
    final many = income.length > 12;
    Widget bar(int v, Color c) => Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: v == 0 ? 0.01 : (v / maxV).clamp(0.02, 1.0),
              child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < income.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: many ? 0.5 : 3),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [bar(income[i], incomeColor(context)), const SizedBox(width: 1), bar(expense[i], expenseColor(context))],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: labels[i].isEmpty
                          ? null
                          : FittedBox(child: Text(labels[i], style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ring chart of shares (e.g. spending by category).
class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final Widget? center;
  const DonutChart({super.key, required this.values, required this.colors, this.size = 150, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(values, colors, Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color empty;
  _DonutPainter(this.values, this.colors, this.empty);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = empty);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, math.max(0.001, sweep - 0.02), false, paint..color = colors[i % colors.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values || old.colors != colors || old.empty != empty;
}

/// Section card used on report screens.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const SectionCard({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Category choice for a transaction type (built-in + custom).
class CategoryChips extends StatelessWidget {
  final PersonalData data;
  final TxnType? type; // null = all
  final String? selected; // null = "All" (only when [allowAll])
  final bool allowAll;
  final ValueChanged<String?> onChanged;
  const CategoryChips({
    super.key,
    required this.data,
    required this.type,
    required this.selected,
    required this.onChanged,
    this.allowAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final cats = [for (final c in allCategories(data.expenseCategories.items)) if (type == null || c.fits(type!)) c];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (allowAll)
          ChoiceChip(
            label: Text(tr(context, t('All', 'सभी'))),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
        for (final c in cats)
          ChoiceChip(
            avatar: Icon(categoryIcon(c.iconKey), size: 18, color: categoryColor(c)),
            label: Text(categoryName(context, c)),
            selected: selected == c.id,
            onSelected: (_) => onChanged(c.id),
          ),
      ],
    );
  }
}
