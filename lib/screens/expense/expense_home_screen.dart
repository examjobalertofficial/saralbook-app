
import 'package:flutter/material.dart';

import '../../core/expense/logic.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/expense/recurring_engine.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart' show DateRange, ProgressPeriod, rangeFor;
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'currency_screens.dart';
import 'expense_ui.dart';
import '../groups/groups_home_screen.dart';
import 'export_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';
import 'txn_form.dart';

final LText _title = t('Expense Tracker', 'खर्च ट्रैकर');

void _push(BuildContext context, Widget screen) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class ExpenseHomeScreen extends StatelessWidget {
  const ExpenseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _ExpenseHome(data: data));
}

class _ExpenseHome extends StatefulWidget {
  final PersonalData data;
  const _ExpenseHome({required this.data});

  @override
  State<_ExpenseHome> createState() => _ExpenseHomeState();
}

enum _RangeChoice { all, month, last30 }

class _ExpenseHomeState extends State<_ExpenseHome> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  TxnType? _type;
  String? _categoryId;
  _RangeChoice _range = _RangeChoice.all;
  bool _checkedRecurring = false;

  static final LText _empty = t(
    'No transactions yet. Tap Add to record your first income or expense.',
    'अभी कोई लेन-देन नहीं। अपनी पहली आय या खर्च दर्ज करने के लिए जोड़ें दबाएं।',
  );
  static final LText _noMatch = t('No transactions match these filters.', 'इन फ़िल्टर से कोई लेन-देन नहीं मिला।');
  static final LText _add = t('Add', 'जोड़ें');
  static final LText _searchHint = t('Search note, category or amount', 'नोट, श्रेणी या राशि खोजें');
  static final LText _deleted = t('Transaction deleted', 'लेन-देन हटाया गया');
  static final LText _balance = t('Balance this month', 'इस महीने की बचत');
  static final LText _thisMonth = t('This month', 'यह महीना');
  static final LText _last30 = t('Last 30 days', 'पिछले 30 दिन');
  static final LText _allTime = t('All time', 'पूरा समय');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Creates repeating transactions that are due (once per session).
  void _maybeRunRecurring() {
    if (_checkedRecurring) return;
    final d = widget.data;
    if (!d.expenses.loaded || !d.recurring.loaded) return;
    _checkedRecurring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = ensureRecurring(d);
      if (n > 0) {
        final lang = Localizations.localeOf(context).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('$n repeating transactions added', '$n दोहराव वाले लेन-देन जोड़े गए').of(lang))),
        );
      }
    });
  }

  DateRange? _rangeValue() {
    final now = DateTime.now();
    switch (_range) {
      case _RangeChoice.all:
        return null;
      case _RangeChoice.month:
        return rangeFor(ProgressPeriod.month, now);
      case _RangeChoice.last30:
        final today = DateTime(now.year, now.month, now.day);
        return DateRange(DateTime(today.year, today.month, today.day - 29), DateTime(today.year, today.month, today.day + 1));
    }
  }

  void _openForm(BuildContext context, {ExpenseTxn? existing, TxnType type = TxnType.expense}) {
    final data = widget.data;
    showTxnForm(
      context,
      data: data,
      existing: existing,
      type: type,
      onSaved: (txn) {
        // alert if this expense pushes a budget over (checked before saving it)
        final before = [for (final x in data.expenses.items) if (x.id != txn.id) x];
        data.expenses.upsert(txn);
        final alerts = budgetAlertsFor(budgets: data.budgets.items, existing: before, added: txn, now: DateTime.now());
        if (alerts.isNotEmpty && mounted) {
          final lang = Localizations.localeOf(context).languageCode;
          final first = alerts.first;
          final cat = first.budget.categoryId.isEmpty ? '' : ' ${categoryName(context, categoryFor(data, first.budget.categoryId))}';
          final exceeded = first.state == BudgetState.exceeded;
          final msg = exceeded
              ? t('Budget exceeded:$cat', 'बजट पार हो गया:$cat').of(lang)
              : t('Budget warning:$cat is almost used up', 'बजट चेतावनी:$cat लगभग खत्म').of(lang);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: exceeded ? Theme.of(context).colorScheme.error : null,
          ));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, _add)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.expenses, data.expenseCategories, data.budgets]),
          builder: (context, _) {
            if (!data.expenses.loaded) return const Center(child: CircularProgressIndicator());
            _maybeRunRecurring();
            final now = DateTime.now();
            final all = data.expenses.items;
            final month = summarize(inRange(all, rangeFor(ProgressPeriod.month, now)));
            final alerts = [
              for (final b in data.budgets.items) budgetStatus(b, all, now),
            ].where((s) => s.state != BudgetState.ok).toList()
              ..sort((a, b) => b.state.index.compareTo(a.state.index));

            final filtered = applyFilter(
              all,
              TxnFilter(range: _rangeValue(), type: _type, categoryId: _categoryId, query: _query),
              nameOf: (id) => tr(context, categoryFor(data, id).name),
            );
            final groups = groupByDay(filtered);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SyncProblemBanner(visible: data.expenses.hasError)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tr(context, _balance)}  •  ${monthLabel(now)}',
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatInr(month.savings),
                              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniFigure(
                                  icon: Icons.arrow_downward_rounded,
                                  label: tr(context, typeLabel(TxnType.income)),
                                  value: formatInrShort(month.income),
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              Expanded(
                                child: _MiniFigure(
                                  icon: Icons.arrow_upward_rounded,
                                  label: tr(context, typeLabel(TxnType.expense)),
                                  value: formatInrShort(month.expense),
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (alerts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        children: [
                          for (final a in alerts.take(3)) _BudgetBanner(status: a, data: data),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      children: [
                        _nav(Icons.groups_2_outlined, t('Groups', 'ग्रुप'), () => _push(context, const GroupsHomeScreen())),
                        _nav(Icons.bar_chart_rounded, t('Reports', 'रिपोर्ट'), () => _push(context, const ReportsScreen())),
                        _nav(Icons.savings_outlined, t('Budgets', 'बजट'), () => _push(context, const BudgetsScreen())),
                        _nav(Icons.repeat_rounded, t('Repeating', 'दोहराव'), () => _push(context, const RecurringScreen())),
                        _nav(Icons.category_outlined, t('Categories', 'श्रेणियां'), () => _push(context, const CategoriesScreen())),
                        _nav(Icons.file_download_outlined, t('Export', 'एक्सपोर्ट'), () => _push(context, const ExportScreen())),
                        _nav(Icons.currency_exchange_rounded, t('Currency', 'मुद्रा'), () => _push(context, const CurrencyScreen())),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: tr(context, _searchHint),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChipRow<TxnType?>(
                          value: _type,
                          options: [
                            (null, t('All', 'सभी')),
                            (TxnType.expense, typeLabel(TxnType.expense)),
                            (TxnType.income, typeLabel(TxnType.income)),
                          ],
                          onChanged: (v) => setState(() {
                            _type = v;
                            _categoryId = null;
                          }),
                        ),
                        const SizedBox(height: 4),
                        ChipRow<_RangeChoice>(
                          value: _range,
                          options: [
                            (_RangeChoice.all, _allTime),
                            (_RangeChoice.month, _thisMonth),
                            (_RangeChoice.last30, _last30),
                          ],
                          onChanged: (v) => setState(() => _range = v),
                        ),
                        const SizedBox(height: 4),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(tr(context, t('Filter by category', 'श्रेणी से फ़िल्टर'))),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: CategoryChips(
                                data: data,
                                type: _type,
                                selected: _categoryId,
                                allowAll: true,
                                onChanged: (id) => setState(() => _categoryId = id),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      message: all.isEmpty ? _empty : _noMatch,
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      final s = summarize(g.items);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dayLabel(context, g.day),
                                    style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  formatInr(s.savings, showSign: true),
                                  style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          for (final txn in g.items)
                            Dismissible(
                              key: ValueKey(txn.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: scheme.errorContainer,
                                child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                              ),
                              onDismissed: (_) {
                                data.expenses.remove(txn.id);
                                showUndo(context, _deleted, () => data.expenses.upsert(txn));
                              },
                              child: TxnTile(
                                txn: txn,
                                category: categoryFor(data, txn.categoryId),
                                onTap: () => _openForm(context, existing: txn),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _nav(IconData icon, LText label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(avatar: Icon(icon, size: 18), label: Text(tr(context, label)), onPressed: onTap),
      );
}

class _MiniFigure extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniFigure({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Warning / exceeded notice for one budget.
class _BudgetBanner extends StatelessWidget {
  final BudgetStatus status;
  final PersonalData data;
  const _BudgetBanner({required this.status, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exceeded = status.state == BudgetState.exceeded;
    final b = status.budget;
    final cat = b.categoryId.isEmpty ? tr(context, t('All spending', 'सारा खर्च')) : categoryName(context, categoryFor(data, b.categoryId));
    final period = tr(context, b.period == BudgetPeriod.weekly ? t('weekly', 'साप्ताहिक') : t('monthly', 'मासिक'));
    final msg = exceeded
        ? '${tr(context, t('Budget exceeded', 'बजट पार हो गया'))}: $cat ($period) — ${formatInr(-status.remainingMinor)} ${tr(context, t('over', 'ज़्यादा'))}'
        : '${tr(context, t('Budget almost used', 'बजट लगभग खत्म'))}: $cat ($period) — ${formatInr(status.remainingMinor)} ${tr(context, t('left', 'बाकी'))}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: exceeded ? scheme.errorContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            exceeded ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: exceeded ? scheme.onErrorContainer : scheme.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: TextStyle(color: exceeded ? scheme.onErrorContainer : scheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }
}
