import 'package:flutter/material.dart';

import '../../core/expense/logic.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'expense_ui.dart';

final LText _title = t('Budgets', 'बजट');

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Budgets(data: data));
}

class _Budgets extends StatelessWidget {
  final PersonalData data;
  const _Budgets({required this.data});

  static final LText _add = t('Add budget', 'बजट जोड़ें');
  static final LText _empty = t(
    'Set a weekly or monthly limit, for all spending or one category, and get warned before you overspend.',
    'साप्ताहिक या मासिक सीमा तय करें, सारे खर्च या किसी एक श्रेणी के लिए, और ज़्यादा खर्च से पहले चेतावनी पाएं।',
  );
  static final LText _deleted = t('Budget deleted', 'बजट हटाया गया');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFormSheet<void>(context, (ctx) => _BudgetForm(data: data, existing: null)),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, _add)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.budgets, data.expenses, data.expenseCategories]),
          builder: (context, _) {
            if (!data.budgets.loaded || !data.expenses.loaded) return const Center(child: CircularProgressIndicator());
            final now = DateTime.now();
            final statuses = [
              for (final b in data.budgets.items) budgetStatus(b, data.expenses.items, now),
            ]..sort((a, b) => b.fraction.compareTo(a.fraction));
            if (statuses.isEmpty) {
              return EmptyState(icon: Icons.savings_outlined, message: _empty);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: statuses.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return SyncProblemBanner(visible: data.budgets.hasError);
                final s = statuses[i - 1];
                final b = s.budget;
                final cat = b.categoryId.isEmpty
                    ? tr(context, t('All spending', 'सारा खर्च'))
                    : categoryName(context, categoryFor(data, b.categoryId));
                final period = tr(context, b.period == BudgetPeriod.weekly ? t('Weekly', 'साप्ताहिक') : t('Monthly', 'मासिक'));
                final state = s.state;
                final color = switch (state) {
                  BudgetState.ok => scheme.primary,
                  BudgetState.warning => Colors.orange,
                  BudgetState.exceeded => scheme.error,
                };
                return Dismissible(
                  key: ValueKey(b.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    data.budgets.remove(b.id);
                    showUndo(context, _deleted, () => data.budgets.upsert(b));
                  },
                  child: GestureDetector(
                    onTap: () => showFormSheet<void>(context, (ctx) => _BudgetForm(data: data, existing: b)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: state == BudgetState.ok ? scheme.outlineVariant : color),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('$cat  •  $period', style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (state != BudgetState.ok) Icon(Icons.warning_amber_rounded, color: color, size: 20),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: s.fraction.clamp(0.0, 1.0),
                            minHeight: 10,
                            color: color,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text('${formatInr(s.spentMinor)} / ${formatInr(b.limitMinor)}'),
                          Text(
                            s.remainingMinor >= 0
                                ? '${formatInr(s.remainingMinor)} ${tr(context, t('left', 'बाकी'))}'
                                : '${formatInr(-s.remainingMinor)} ${tr(context, t('over the limit', 'सीमा से ज़्यादा'))}',
                            style: TextStyle(color: color, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BudgetForm extends StatefulWidget {
  final PersonalData data;
  final Budget? existing;
  const _BudgetForm({required this.data, required this.existing});

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  late BudgetPeriod _period = widget.existing?.period ?? BudgetPeriod.monthly;
  late String? _categoryId = (widget.existing?.categoryId.isEmpty ?? true) ? null : widget.existing!.categoryId;
  late int _warn = widget.existing?.warnPercent ?? 80;
  late final TextEditingController _limit = TextEditingController(
    text: widget.existing == null ? '' : minorToPlain(widget.existing!.limitMinor),
  );

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  int? get _limitMinor => parseMinor(_limit.text);

  void _submit() {
    final limit = _limitMinor;
    if (limit == null) return;
    final e = widget.existing;
    final b = Budget(
      id: e?.id ?? Budget.create(period: _period, limitMinor: limit).id,
      period: _period,
      categoryId: _categoryId ?? '',
      limitMinor: limit,
      warnPercent: _warn,
      createdAt: e?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    widget.data.budgets.upsert(b);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, widget.existing == null ? t('New budget', 'नया बजट') : t('Edit budget', 'बजट बदलें')),
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ChipRow<BudgetPeriod>(
          value: _period,
          options: [(BudgetPeriod.weekly, t('Weekly', 'साप्ताहिक')), (BudgetPeriod.monthly, t('Monthly', 'मासिक'))],
          onChanged: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _limit,
          autofocus: widget.existing == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr(context, t('Spending limit', 'खर्च की सीमा')),
            prefixText: '₹ ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(tr(context, t('Applies to', 'किस पर लागू')), style: text.labelLarge),
        const SizedBox(height: 6),
        CategoryChips(
          data: widget.data,
          type: TxnType.expense,
          selected: _categoryId,
          allowAll: true,
          onChanged: (id) => setState(() => _categoryId = id),
        ),
        const SizedBox(height: 12),
        Text(tr(context, t('Warn me at', 'चेतावनी कब')), style: text.labelLarge),
        const SizedBox(height: 6),
        ChipRow<int>(
          value: _warn,
          options: [for (final p in const [50, 60, 70, 80, 90, 100]) (p, LText({'en': '$p%', 'hi': '$p%'}))],
          onChanged: (v) => setState(() => _warn = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _limitMinor == null ? null : _submit,
            child: Text(tr(context, t('Save', 'सेव करें'))),
          ),
        ),
      ],
    );
  }
}
