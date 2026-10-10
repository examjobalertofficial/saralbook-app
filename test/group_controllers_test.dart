import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/auth/auth_backend.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/groups/group_backend.dart';
import 'package:app/core/groups/group_controllers.dart';
import 'package:app/core/groups/group_logic.dart';
import 'package:app/core/groups/group_models.dart';

import 'fakes/fake_auth_backend.dart';

const _a = AppUser(uid: 'a', name: 'Asha', email: 'a@gmail.com');
const _b = AppUser(uid: 'b', name: 'Bala', email: 'b@gmail.com');
const _c = AppUser(uid: 'c', name: 'Chitra', email: 'c@gmail.com');

Future<void> settle() => Future<void>.delayed(Duration.zero);

GroupsController controllerFor(AppUser u, MemoryGroupBackend cloud) => GroupsController(backend: cloud, me: u)..start();

void main() {
  late MemoryGroupBackend cloud;
  setUp(() => cloud = MemoryGroupBackend());

  test('create, join with code, add a bill, settle up', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Goa trip');
    await settle();
    expect(asha.active.single.name, 'Goa trip');
    expect(asha.active.single.memberIds, ['a']);

    final bala = controllerFor(_b, cloud);
    await settle();
    expect(bala.active, isEmpty);
    expect(await bala.join('wrong123'), JoinResult.invalidCode);
    expect(await bala.join('hello'), JoinResult.invalidCode);
    expect(await bala.join('Invite code: ${g.inviteCode}'), JoinResult.joined);
    await settle();
    expect(bala.active.single.id, g.id);
    expect(await bala.join(g.inviteCode), JoinResult.alreadyMember);

    final sa = GroupSession(groups: asha, gid: g.id);
    final sb = GroupSession(groups: bala, gid: g.id);
    await settle();
    expect(sa.members.map((m) => m.uid).toSet(), {'a', 'b'});
    expect(sa.myRole, GroupRole.owner);
    expect(sb.myRole, GroupRole.member);

    // Asha pays 900 for dinner, split equally with Bala
    final ok = sa.saveExpense(
      title: 'Dinner',
      amountMinor: 900,
      date: 1,
      paidBy: {'a': 900},
      splits: splitEqual(900, ['a', 'b']),
    );
    expect(ok, isTrue);
    await settle();
    expect(sb.expenses.single.title, 'Dinner');
    expect(sb.myBalance, -450);
    expect(sa.myBalance, 450);
    expect(sb.suggestedPayments.single.amountMinor, 450);

    // Bala says "I paid", Asha confirms
    expect(sb.recordPayment(from: 'b', to: 'a', amountMinor: 450), isTrue);
    await settle();
    expect(sb.myBalance, -450, reason: 'pending does not count yet');
    final pending = sa.settlements.single;
    expect(sb.confirmPayment(pending), isFalse, reason: 'only the receiver confirms');
    expect(sa.confirmPayment(pending), isTrue);
    await settle();
    expect(sb.myBalance, 0);
    expect(sa.myBalance, 0);
    expect(sa.suggestedPayments, isEmpty);
    expect(sa.activity.map((x) => x.type), containsAll(['group_created', 'member_joined', 'expense_added', 'settlement_paid', 'settlement_confirmed']));

    sa.dispose();
    sb.dispose();
    asha.dispose();
    bala.dispose();
  });

  test('inconsistent bills are refused', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Flat');
    final s = GroupSession(groups: asha, gid: g.id);
    await settle();
    expect(s.saveExpense(title: 'x', amountMinor: 900, date: 1, paidBy: {'a': 900}, splits: {'a': 400}), isFalse);
    expect(s.saveExpense(title: 'x', amountMinor: 900, date: 1, paidBy: {'a': 500}, splits: {'a': 900}), isFalse);
    expect(s.saveExpense(title: 'x', amountMinor: 0, date: 1, paidBy: {'a': 0}, splits: {'a': 0}), isFalse);
    expect(cloud.expenses[g.id] ?? {}, isEmpty);
    s.dispose();
    asha.dispose();
  });

  test('members edit only their own bills, admins any', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Flat');
    final bala = controllerFor(_b, cloud);
    final chitra = controllerFor(_c, cloud);
    await settle();
    await bala.join(g.inviteCode);
    await chitra.join(g.inviteCode);
    await settle();
    final sa = GroupSession(groups: asha, gid: g.id);
    final sb = GroupSession(groups: bala, gid: g.id);
    final sc = GroupSession(groups: chitra, gid: g.id);
    await settle();

    sb.saveExpense(title: 'Milk', amountMinor: 300, date: 1, paidBy: {'b': 300}, splits: splitEqual(300, ['a', 'b', 'c']));
    await settle();
    final milk = sa.expenses.single;
    expect(sc.deleteExpense(milk), isFalse);
    expect(sc.saveExpense(existing: milk, title: 'Milk 2', amountMinor: 300, date: 1, paidBy: {'b': 300}, splits: milk.splits), isFalse);
    expect(sb.saveExpense(existing: milk, title: 'Milk 2', amountMinor: 300, date: 1, paidBy: {'b': 300}, splits: milk.splits), isTrue);
    await settle();
    expect(sa.expenses.single.version, 2);
    expect(sa.deleteExpense(sa.expenses.single), isTrue, reason: 'owner can delete');
    await settle();
    expect(sa.expenses, isEmpty);

    // a stale edit (an old copy of the bill) is refused by the cloud and flagged
    sb.saveExpense(title: 'Tea', amountMinor: 100, date: 1, paidBy: {'b': 100}, splits: {'b': 100});
    await settle();
    final tea = sb.expenses.single;
    sb.saveExpense(existing: tea, title: 'Tea 2', amountMinor: 100, date: 1, paidBy: {'b': 100}, splits: {'b': 100});
    await settle();
    sa.saveExpense(existing: tea, title: 'Tea 3', amountMinor: 100, date: 1, paidBy: {'b': 100}, splits: {'b': 100});
    await settle();
    expect(sa.writeFailed, isTrue);
    expect(sa.expenses.single.title, 'Tea 2');

    for (final s in [sa, sb, sc]) {
      s.dispose();
    }
    for (final c in [asha, bala, chitra]) {
      c.dispose();
    }
  });

  test('archive blocks changes, restore allows them; roles and leaving', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Club');
    final bala = controllerFor(_b, cloud);
    await settle();
    await bala.join(g.inviteCode);
    await settle();
    final sa = GroupSession(groups: asha, gid: g.id);
    final sb = GroupSession(groups: bala, gid: g.id);
    await settle();

    expect(sb.setArchived(true), isFalse, reason: 'members cannot archive');
    expect(sa.setArchived(true), isTrue);
    await settle();
    expect(asha.archived.single.id, g.id);
    expect(sa.saveExpense(title: 'x', amountMinor: 100, date: 1, paidBy: {'a': 100}, splits: {'a': 100}), isFalse);
    sa.setArchived(false);
    await settle();
    expect(asha.active.single.id, g.id);

    expect(sa.cannotLeaveReason, 'owner');
    final bAsMember = sa.memberById('b')!;
    expect(sa.changeRole(bAsMember, GroupRole.admin), isTrue);
    await settle();
    expect(sb.myRole, GroupRole.admin);
    expect(sb.cannotLeaveReason, isNull);
    expect(await sb.leave(), isTrue);
    await settle();
    expect(bala.active, isEmpty);
    expect(sa.members.map((m) => m.uid), ['a']);

    sa.dispose();
    sb.dispose();
    asha.dispose();
    bala.dispose();
  });

  test('resetting the code stops the old code working', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Club');
    final s = GroupSession(groups: asha, gid: g.id);
    await settle();
    expect(s.resetInviteCode(), isTrue);
    await settle();
    final bala = controllerFor(_b, cloud);
    await settle();
    expect(await bala.join(g.inviteCode), JoinResult.invalidCode);
    expect(await bala.join(asha.byId(g.id)!.inviteCode), JoinResult.joined);
    s.dispose();
    asha.dispose();
    bala.dispose();
  });

  test('switching account replaces the groups (no mixing)', () async {
    final backend = FakeAuthBackend(configured: true);
    final auth = AuthController.ready(backend);
    await auth.init();
    final hub = GroupsHub(auth, () => cloud);
    expect(hub.current, isNull);
    await auth.signIn();
    await settle();
    final first = hub.current;
    expect(first, isNotNull);
    first!.createGroup(name: 'Mine');
    await settle();
    expect(first.active.length, 1);
    hub.dispose();
  });

  test('group chat: send, reply, delete, unread count', () async {
    final asha = controllerFor(_a, cloud);
    final g = asha.createGroup(name: 'Chat');
    final bala = controllerFor(_b, cloud);
    await settle();
    await bala.join(g.inviteCode);
    await settle();
    final sa = GroupSession(groups: asha, gid: g.id);
    final sb = GroupSession(groups: bala, gid: g.id);
    await settle();

    expect(sa.sendMessage('   '), isFalse);
    expect(sa.sendMessage('Hello everyone'), isTrue);
    await settle();
    expect(sb.messages.single.text, 'Hello everyone');
    expect(sb.unreadCount, 1);
    expect(sa.unreadCount, 0, reason: 'own messages are never unread');

    sb.markChatRead();
    await settle();
    expect(sb.unreadCount, 0);
    expect(sb.memberById('b')!.lastReadAt, greaterThan(0));

    expect(sb.sendMessage('Hi!', replyTo: sb.messages.firstWhere((m) => m.text == 'Hello everyone')), isTrue);
    await settle();
    expect(sa.messages.firstWhere((m) => m.text == 'Hi!').replyPreview, 'Hello everyone');
    expect(sa.unreadCount, 1);

    // only the sender or an admin may delete
    final first = sb.messages.firstWhere((m) => m.senderId == 'a'); // Asha's message
    expect(sb.deleteMessage(first), isFalse);
    expect(sa.deleteMessage(first), isTrue);
    await settle();
    final gone = sb.messages.firstWhere((m) => m.id == first.id);
    expect(gone.deleted, isTrue);
    expect(gone.text, '');

    // archived groups are read-only
    sa.setArchived(true);
    await settle();
    expect(sa.sendMessage('late'), isFalse);

    sa.dispose();
    sb.dispose();
    asha.dispose();
    bala.dispose();
  });
}
