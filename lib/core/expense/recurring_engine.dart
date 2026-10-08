import '../personal/personal_data.dart';
import 'logic.dart';

/// Creates the transactions that repeating rules owe up to today.
/// Safe to call often: ids are fixed per rule + day, and each rule remembers
/// how far it got. Returns how many transactions were created.
int runRecurringNow(PersonalData data, {DateTime? now}) {
  final plans = planRecurring(data.recurring.items, now ?? DateTime.now());
  var created = 0;
  for (final p in plans) {
    for (final t in p.txns) {
      data.expenses.upsert(t);
      created++;
    }
    data.recurring.upsert(p.rule.copyWith(lastGenerated: p.newLastGenerated));
  }
  return created;
}

/// Once per session, after the lists were loaded from the account.
int ensureRecurring(PersonalData data, {DateTime? now}) {
  if (data.recurringChecked) return 0;
  if (!data.expenses.loaded || !data.recurring.loaded) return 0;
  data.recurringChecked = true;
  return runRecurringNow(data, now: now);
}
