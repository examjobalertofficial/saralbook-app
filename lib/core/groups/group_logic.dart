import 'dart:math' as math;

import 'group_models.dart';

// ======================= Splitting one bill =======================
// Every function works in whole paise and the shares ALWAYS add up to the
// total, so no paisa is ever lost or invented.

/// Why a split was refused.
enum SplitProblem { none, noPeople, notAdding, badPercent, negative }

/// Equal split. The leftover paise (total is not divisible) go one each to the
/// first people in sorted order, so every phone computes the same result.
Map<String, int> splitEqual(int total, Iterable<String> people) {
  final ids = people.toSet().toList()..sort();
  if (ids.isEmpty || total < 0) return const {};
  final base = total ~/ ids.length;
  final extra = total % ids.length;
  return {
    for (var i = 0; i < ids.length; i++) ids[i]: base + (i < extra ? 1 : 0),
  };
}

/// Percentage split ("60 % / 40 %"). Percentages must add up to 100.
/// Uses basis points (0.01 %) and the largest-remainder rule so shares add up exactly.
/// Returns null when the percentages are not valid.
Map<String, int>? splitByPercent(int total, Map<String, double> percents) {
  if (percents.isEmpty || total < 0) return null;
  final bp = <String, int>{};
  var sum = 0;
  for (final e in percents.entries) {
    if (!e.value.isFinite || e.value < 0) return null;
    final v = (e.value * 100).round();
    bp[e.key] = v;
    sum += v;
  }
  if (sum != 10000) return null;
  final ids = bp.keys.toList()..sort();
  final shares = <String, int>{};
  final rema = <String, int>{};
  var given = 0;
  for (final id in ids) {
    final prod = total * bp[id]!;
    shares[id] = prod ~/ 10000;
    rema[id] = prod % 10000;
    given += shares[id]!;
  }
  var left = total - given;
  final order = [...ids]..sort((a, b) {
      final c = rema[b]!.compareTo(rema[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  for (var i = 0; left > 0 && order.isNotEmpty; i = (i + 1) % order.length) {
    shares[order[i]] = shares[order[i]]! + 1;
    left--;
  }
  return shares;
}

/// Checks typed amounts ("exact" split or "who paid how much").
SplitProblem checkAmounts(int total, Map<String, int> amounts) {
  if (amounts.isEmpty) return SplitProblem.noPeople;
  var sum = 0;
  for (final v in amounts.values) {
    if (v < 0) return SplitProblem.negative;
    sum += v;
  }
  return sum == total ? SplitProblem.none : SplitProblem.notAdding;
}

/// Removes people with 0 paise (they take no part).
Map<String, int> withoutZero(Map<String, int> m) => {
      for (final e in m.entries)
        if (e.value > 0) e.key: e.value,
    };

/// Sum of percent values rounded to basis points, for the "must be 100" hint.
double percentTotal(Iterable<double> values) {
  var bp = 0;
  for (final v in values) {
    bp += (v * 100).round();
  }
  return bp / 100;
}

// ======================= Balances =======================

/// Net position of every person in paise.
/// Positive = the group owes them. Negative = they owe the group.
/// Only CONFIRMED settlements count; a pending one is only a promise.
Map<String, int> netBalances({
  required Iterable<String> memberIds,
  required Iterable<GroupExpense> expenses,
  required Iterable<GroupSettlement> settlements,
}) {
  final net = <String, int>{for (final id in memberIds) id: 0};
  void add(String id, int v) => net[id] = (net[id] ?? 0) + v;
  for (final e in expenses) {
    e.paidBy.forEach((id, v) => add(id, v));
    e.splits.forEach((id, v) => add(id, -v));
  }
  for (final s in settlements) {
    if (!s.confirmed) continue;
    add(s.from, s.amountMinor); // paying a debt raises your position
    add(s.to, -s.amountMinor);
  }
  return net;
}

class Transfer {
  final String from;
  final String to;
  final int amountMinor;
  const Transfer(this.from, this.to, this.amountMinor);

  @override
  String toString() => '$from -> $to $amountMinor';
}

/// Smallest practical list of payments that clears everything:
/// repeatedly the biggest debtor pays the biggest creditor.
List<Transfer> simplifyDebts(Map<String, int> net) {
  final creditors = <MapEntry<String, int>>[];
  final debtors = <MapEntry<String, int>>[];
  for (final e in net.entries) {
    if (e.value > 0) creditors.add(MapEntry(e.key, e.value));
    if (e.value < 0) debtors.add(MapEntry(e.key, -e.value));
  }
  int order(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  creditors.sort(order);
  debtors.sort(order);
  final out = <Transfer>[];
  var ci = 0;
  var di = 0;
  var cLeft = creditors.isEmpty ? 0 : creditors[0].value;
  var dLeft = debtors.isEmpty ? 0 : debtors[0].value;
  while (ci < creditors.length && di < debtors.length) {
    final pay = math.min(cLeft, dLeft);
    if (pay > 0) out.add(Transfer(debtors[di].key, creditors[ci].key, pay));
    cLeft -= pay;
    dLeft -= pay;
    if (cLeft == 0) {
      ci++;
      if (ci < creditors.length) cLeft = creditors[ci].value;
    }
    if (dLeft == 0) {
      di++;
      if (di < debtors.length) dLeft = debtors[di].value;
    }
  }
  return out;
}

/// Pending (not yet confirmed) amount [from] has promised to [to].
int pendingBetween(Iterable<GroupSettlement> settlements, String from, String to) {
  var sum = 0;
  for (final s in settlements) {
    if (!s.confirmed && s.from == from && s.to == to) sum += s.amountMinor;
  }
  return sum;
}

/// What this person owes / is owed in total.
({int owes, int owed}) positionOf(Map<String, int> net, String uid) {
  final v = net[uid] ?? 0;
  return (owes: v < 0 ? -v : 0, owed: v > 0 ? v : 0);
}

// ======================= Budget =======================

class BudgetProgress {
  final int spent;
  final int budget;
  const BudgetProgress(this.spent, this.budget);

  bool get hasBudget => budget > 0;
  double get fraction => budget <= 0 ? 0 : spent / budget;
  bool get over => budget > 0 && spent > budget;
  bool get nearLimit => budget > 0 && !over && fraction >= 0.8;
  int get remaining => budget - spent;
}

/// How much of the monthly group budget [month] has been used by group expenses.
BudgetProgress budgetProgress(Iterable<GroupExpense> expenses, int budgetMinor, DateTime month) {
  var spent = 0;
  for (final e in expenses) {
    final d = DateTime.fromMillisecondsSinceEpoch(e.date);
    if (d.year == month.year && d.month == month.month) spent += e.amountMinor;
  }
  return BudgetProgress(spent, budgetMinor);
}

/// Total spent by the whole group (all time).
int totalSpent(Iterable<GroupExpense> expenses) => expenses.fold(0, (a, e) => a + e.amountMinor);

// ======================= Permissions =======================

bool isAdminRole(GroupRole r) => r == GroupRole.owner || r == GroupRole.admin;

/// A member can change or delete their own entries; owner/admin can change anyone's.
bool canEditExpense(GroupRole role, String uid, GroupExpense e) => isAdminRole(role) || e.createdBy == uid;

bool canRemoveMember({required GroupRole actor, required String actorId, required GroupMember target}) {
  if (target.uid == actorId) return false; // leaving is a separate action
  if (target.role == GroupRole.owner) return false;
  if (actor == GroupRole.owner) return true;
  return actor == GroupRole.admin && target.role == GroupRole.member;
}

// ======================= Invite codes =======================

const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
final math.Random _rng = math.Random.secure();

/// 8 characters, easy to read out loud.
String newInviteCode() => List.generate(8, (_) => _codeChars[_rng.nextInt(_codeChars.length)]).join();

bool looksLikeInviteCode(String s) => RegExp('^[$_codeChars]{8}\$').hasMatch(s);

/// Accepts a plain code, a code with spaces/dashes, or a whole shared message /
/// link that contains the code. Returns null if nothing usable is found.
String? extractInviteCode(String input) {
  final up = input.toUpperCase();
  final compact = up.replaceAll(RegExp(r'[\s-]'), '');
  if (looksLikeInviteCode(compact)) return compact;
  final m = RegExp('(?:CODE[:=]?\\s*|JOIN/)([$_codeChars]{8})').firstMatch(up);
  return m?.group(1);
}

String inviteMessage(String groupName, String code) =>
    'Join my group "$groupName" on SaralBook (Study > Expenses > Groups).\n'
    'Invite code: $code\n'
    'सरलबुक ऐप में ग्रुप "$groupName" से जुड़ें। कोड: $code';
