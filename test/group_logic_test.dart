import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/groups/group_logic.dart';
import 'package:app/core/groups/group_models.dart';

GroupExpense bill(String id, int total, Map<String, int> paid, Map<String, int> owed, {int date = 0}) => GroupExpense(
      id: id,
      title: id,
      amountMinor: total,
      origMinor: total,
      date: date,
      paidBy: paid,
      splits: owed,
      createdBy: paid.keys.first,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('splitEqual', () {
    test('divides and gives leftover paise to the first people in order', () {
      expect(splitEqual(100, ['b', 'a', 'c']), {'a': 34, 'b': 33, 'c': 33});
    });
    test('always adds up to the total', () {
      for (var total = 1; total < 500; total += 7) {
        for (var n = 1; n < 9; n++) {
          final s = splitEqual(total, [for (var i = 0; i < n; i++) 'u$i']);
          expect(s.values.fold(0, (a, b) => a + b), total);
        }
      }
    });
    test('nobody listed = nothing', () {
      expect(splitEqual(100, const []), isEmpty);
    });
  });

  group('splitByPercent', () {
    test('adds up exactly even when it does not divide', () {
      final s = splitByPercent(10001, {'a': 33.33, 'b': 33.33, 'c': 33.34})!;
      expect(s.values.fold(0, (a, b) => a + b), 10001);
      expect(s['c'], 3335);
    });
    test('refuses percentages that are not 100', () {
      expect(splitByPercent(1000, {'a': 50, 'b': 40}), isNull);
      expect(splitByPercent(1000, {'a': 120, 'b': -20}), isNull);
    });
    test('60/40', () {
      expect(splitByPercent(1000, {'a': 60, 'b': 40}), {'a': 600, 'b': 400});
    });
  });

  test('checkAmounts', () {
    expect(checkAmounts(100, {'a': 60, 'b': 40}), SplitProblem.none);
    expect(checkAmounts(100, {'a': 60, 'b': 30}), SplitProblem.notAdding);
    expect(checkAmounts(100, {'a': 160, 'b': -60}), SplitProblem.negative);
    expect(checkAmounts(100, const {}), SplitProblem.noPeople);
    expect(withoutZero({'a': 0, 'b': 5}), {'b': 5});
  });

  group('balances', () {
    final members = ['a', 'b', 'c'];
    final dinner = bill('dinner', 900, {'a': 900}, {'a': 300, 'b': 300, 'c': 300});

    test('payer is owed, others owe', () {
      final net = netBalances(memberIds: members, expenses: [dinner], settlements: const []);
      expect(net, {'a': 600, 'b': -300, 'c': -300});
      expect(net.values.fold(0, (a, b) => a + b), 0);
    });

    test('two people paying one bill', () {
      final b = bill('x', 1000, {'a': 600, 'b': 400}, {'a': 500, 'b': 500});
      final net = netBalances(memberIds: ['a', 'b'], expenses: [b], settlements: const []);
      expect(net, {'a': 100, 'b': -100});
    });

    test('only confirmed settlements count', () {
      final pending = GroupSettlement.create(from: 'b', to: 'a', amountMinor: 300, status: SettlementStatus.pending);
      final done = GroupSettlement.create(from: 'c', to: 'a', amountMinor: 300, status: SettlementStatus.confirmed);
      final net = netBalances(memberIds: members, expenses: [dinner], settlements: [pending, done]);
      expect(net, {'a': 300, 'b': -300, 'c': 0});
      expect(pendingBetween([pending, done], 'b', 'a'), 300);
    });

    test('a person who left but is in old bills is still counted', () {
      final net = netBalances(memberIds: ['a'], expenses: [dinner], settlements: const []);
      expect(net['b'], -300);
    });
  });

  group('simplifyDebts', () {
    test('biggest debtor pays biggest creditor', () {
      final t = simplifyDebts({'a': 50, 'b': -30, 'c': -20});
      expect(t.map((e) => '${e.from}>${e.to}:${e.amountMinor}'), ['b>a:30', 'c>a:20']);
    });
    test('chain a->b->c becomes one payment', () {
      // a owes b 100, b owes c 100  => a pays c
      final t = simplifyDebts({'a': -100, 'b': 0, 'c': 100});
      expect(t.length, 1);
      expect('${t[0].from}>${t[0].to}:${t[0].amountMinor}', 'a>c:100');
    });
    test('clears every balance and uses at most n-1 payments', () {
      final net = {'a': 700, 'b': -250, 'c': -150, 'd': 50, 'e': -350, 'f': 0};
      final t = simplifyDebts(net);
      final after = Map<String, int>.of(net);
      for (final x in t) {
        after[x.from] = after[x.from]! + x.amountMinor;
        after[x.to] = after[x.to]! - x.amountMinor;
      }
      expect(after.values.every((v) => v == 0), isTrue);
      expect(t.length <= 5, isTrue);
    });
    test('settled group has nothing to do', () {
      expect(simplifyDebts({'a': 0, 'b': 0}), isEmpty);
    });
  });

  test('budget progress counts only this month', () {
    final may = DateTime(2026, 5, 10, 12).millisecondsSinceEpoch;
    final jun = DateTime(2026, 6, 10, 12).millisecondsSinceEpoch;
    final es = [
      bill('a', 500, {'a': 500}, {'a': 500}, date: may),
      bill('b', 800, {'a': 800}, {'a': 800}, date: jun),
    ];
    final p = budgetProgress(es, 1000, DateTime(2026, 6, 20));
    expect(p.spent, 800);
    expect(p.nearLimit, isTrue);
    expect(p.over, isFalse);
    expect(budgetProgress(es, 700, DateTime(2026, 6, 20)).over, isTrue);
    expect(budgetProgress(es, 0, DateTime(2026, 6, 20)).hasBudget, isFalse);
  });

  group('permissions', () {
    final e = bill('x', 100, {'a': 100}, {'a': 100});
    test('creator or admin may edit', () {
      expect(canEditExpense(GroupRole.member, 'a', e), isTrue);
      expect(canEditExpense(GroupRole.member, 'b', e), isFalse);
      expect(canEditExpense(GroupRole.admin, 'b', e), isTrue);
    });
    test('who can remove whom', () {
      GroupMember m(String id, GroupRole r) => GroupMember(uid: id, name: id, role: r, joinedAt: 0);
      expect(canRemoveMember(actor: GroupRole.admin, actorId: 'a', target: m('b', GroupRole.member)), isTrue);
      expect(canRemoveMember(actor: GroupRole.admin, actorId: 'a', target: m('b', GroupRole.admin)), isFalse);
      expect(canRemoveMember(actor: GroupRole.owner, actorId: 'a', target: m('b', GroupRole.admin)), isTrue);
      expect(canRemoveMember(actor: GroupRole.owner, actorId: 'a', target: m('a', GroupRole.owner)), isFalse);
      expect(canRemoveMember(actor: GroupRole.member, actorId: 'a', target: m('b', GroupRole.member)), isFalse);
    });
  });

  group('invite codes', () {
    test('new codes are valid and different', () {
      final a = newInviteCode();
      expect(a.length, 8);
      expect(looksLikeInviteCode(a), isTrue);
      expect(newInviteCode() == a, isFalse);
    });
    test('code can be pasted in many ways', () {
      expect(extractInviteCode('abcd2345'), 'ABCD2345');
      expect(extractInviteCode(' ABCD-2345 '), 'ABCD2345');
      expect(extractInviteCode(inviteMessage('Trip', 'ABCD2345')), 'ABCD2345');
      expect(extractInviteCode('https://x.app/join/abcd2345'), 'ABCD2345');
      expect(extractInviteCode('hello'), isNull);
      expect(extractInviteCode('ABCD0OI1'), isNull); // forbidden look-alike characters
    });
  });

  group('models', () {
    test('expense survives a round trip, damaged rows are dropped', () {
      final e = bill('x', 100, {'a': 100}, {'a': 40, 'b': 60});
      final back = GroupExpense.fromMap({'id': 'x', ...e.toMap()})!;
      expect(back.splits, {'a': 40, 'b': 60});
      expect(GroupExpense.fromMap({'id': 'y', 'amountMinor': 'bad'}), isNull);
      expect(GroupSettlement.fromMap({'id': 's', 'from': 'a', 'to': 'a', 'amountMinor': 5}), isNull);
      expect(ExpenseGroup.fromMap({'id': 'g', 'name': '  '}), isNull);
    });
  });
}
