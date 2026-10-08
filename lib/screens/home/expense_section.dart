import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/expense/logic.dart';
import '../../core/expense/money.dart';
import '../../core/expense/recurring_engine.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart' show ProgressPeriod, rangeFor;
import '../../widgets/tr.dart';
import '../account/account_widgets.dart';
import '../expense/expense_home_screen.dart';
import 'section_header.dart';

/// Home block: this month's spending at a glance (or a sign-in hint).
class ExpenseSection extends StatelessWidget {
  final String title;
  const ExpenseSection({super.key, required this.title});

  static final LText _signInHint = t('Sign in to track your income, expenses and budgets.', 'आय, खर्च और बजट ट्रैक करने के लिए साइन इन करें।');

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title.isEmpty ? tr(context, t('Expense Tracker', 'खर्च ट्रैकर')) : title),
          ListenableBuilder(
            listenable: services.personal,
            builder: (context, _) {
              final data = services.personal.current;
              if (data == null) {
                return SectionMessage(
                  icon: Icons.account_balance_wallet_outlined,
                  message: tr(context, _signInHint),
                  onRetry: services.auth.isAvailable ? () => requireSignIn(context) : null,
                  retryLabel: s.signInGoogle,
                );
              }
              return ListenableBuilder(
                listenable: Listenable.merge([data.expenses, data.budgets, data.recurring]),
                builder: (context, _) {
                  if (data.expenses.loaded && data.recurring.loaded && !data.recurringChecked) {
                    // create repeating transactions that are due (once per session)
                    WidgetsBinding.instance.addPostFrameCallback((_) => ensureRecurring(data));
                  }
                  final now = DateTime.now();
                  final month = summarize(inRange(data.expenses.items, rangeFor(ProgressPeriod.month, now)));
                  final alerts = [
                    for (final b in data.budgets.items) budgetStatus(b, data.expenses.items, now),
                  ].where((x) => x.state != BudgetState.ok).length;
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: scheme.surfaceContainerLow,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(builder: (_) => const ExpenseHomeScreen()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: scheme.primary, size: 32),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${tr(context, t('Spent this month', 'इस महीने का खर्च'))}: ${formatInrShort(month.expense)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${tr(context, t('Income', 'आय'))}: ${formatInrShort(month.income)}   •   ${tr(context, t('Savings', 'बचत'))}: ${formatInrShort(month.savings)}',
                                    style: TextStyle(color: scheme.onSurfaceVariant),
                                  ),
                                  if (alerts > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '$alerts ${tr(context, t('budget alert(s)', 'बजट चेतावनी'))}',
                                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
