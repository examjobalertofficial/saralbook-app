import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_backend.dart';
import '../auth/auth_controller.dart';
import '../personal/ids.dart';
import '../personal/models.dart' show Json, nowMs;
import 'group_backend.dart';
import 'group_logic.dart';
import 'group_models.dart';

enum JoinResult { joined, alreadyMember, invalidCode, failed }

/// The groups of ONE signed-in account (a new object per account).
class GroupsController extends ChangeNotifier {
  GroupsController({required this.backend, required this.me});

  final GroupBackend backend;
  final AppUser me;

  StreamSubscription<List<Json>>? _sub;
  List<ExpenseGroup> _groups = const [];
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;

  bool get loaded => _loaded;
  bool get hasError => _hasError;

  List<ExpenseGroup> get active => _sorted(false);
  List<ExpenseGroup> get archived => _sorted(true);

  List<ExpenseGroup> _sorted(bool archivedOnes) {
    final out = [
      for (final g in _groups)
        if (g.archived == archivedOnes) g,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  ExpenseGroup? byId(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  void start() {
    _sub ??= backend.watchMyGroups(me.uid).listen(
      (rows) {
        _groups = [
          for (final r in rows)
            if (ExpenseGroup.fromMap(r) case final ExpenseGroup g) g,
        ];
        _loaded = true;
        _hasError = false;
        _notify();
      },
      onError: (Object _) {
        _loaded = true;
        _hasError = true;
        _notify();
      },
    );
  }

  GroupMember _meAs(GroupRole role, {String code = ''}) => GroupMember(
        uid: me.uid,
        name: me.name.trim().isEmpty ? me.email : me.name.trim(),
        photoUrl: me.photoUrl ?? '',
        role: role,
        joinedAt: nowMs(),
        inviteCode: code,
      );

  GroupActivity _act(String type, {String subject = '', int amount = 0}) => GroupActivity.create(
        type: type,
        actorId: me.uid,
        actorName: _meAs(GroupRole.member).name,
        subject: subject,
        amountMinor: amount,
      );

  /// Makes a group and shows it at once (also offline).
  ExpenseGroup createGroup({
    required String name,
    String iconKey = 'group',
    int colorIndex = 0,
    int budgetMinor = 0,
  }) {
    final now = nowMs();
    final cleanName = name.trim().length > 60 ? name.trim().substring(0, 60) : name.trim();
    final g = ExpenseGroup(
      id: 'g_${newId()}',
      name: cleanName,
      iconKey: iconKey,
      colorIndex: colorIndex,
      ownerId: me.uid,
      memberIds: [me.uid],
      inviteCode: newInviteCode(),
      budgetMinor: budgetMinor,
      createdAt: now,
      updatedAt: now,
    );
    _groups = [..._groups, g];
    _notify();
    unawaited(
      backend
          .createGroup(group: g, owner: _meAs(GroupRole.owner), activity: _act('group_created', subject: g.name))
          .catchError(_onWriteError),
    );
    return g;
  }

  /// Looks the code up (needs internet) without joining.
  Future<InviteInfo?> preview(String input) async {
    final code = extractInviteCode(input);
    if (code == null) return null;
    try {
      return await backend.lookupInvite(code);
    } catch (_) {
      return null;
    }
  }

  /// Joins with a code or a pasted invite message. Needs internet.
  Future<JoinResult> join(String input) async {
    final code = extractInviteCode(input);
    if (code == null) return JoinResult.invalidCode;
    try {
      final info = await backend.lookupInvite(code);
      if (info == null) return JoinResult.invalidCode;
      if (byId(info.groupId) != null) return JoinResult.alreadyMember;
      await backend.joinGroup(
        gid: info.groupId,
        code: code,
        me: _meAs(GroupRole.member, code: code),
        activity: _act('member_joined', subject: _meAs(GroupRole.member).name),
      );
      // wait (a few seconds at most) until the new group shows in the list
      for (var i = 0; i < 40 && byId(info.groupId) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return JoinResult.joined;
    } on InviteInvalidException {
      return JoinResult.invalidCode;
    } catch (_) {
      return JoinResult.failed;
    }
  }

  void _onWriteError(Object _) {
    _hasError = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// Everything about ONE open group: people, bills, payments, history.
/// Create it when the group screen opens, dispose it when it closes.
class GroupSession extends ChangeNotifier {
  GroupSession({required this.groups, required this.gid}) {
    groups.addListener(_notify);
    final b = groups.backend;
    _subs.add(b.watchMembers(gid).listen(_onMembers, onError: _onReadError));
    _subs.add(b.watchExpenses(gid).listen(_onExpenses, onError: _onReadError));
    _subs.add(b.watchSettlements(gid).listen(_onSettlements, onError: _onReadError));
    _subs.add(b.watchActivity(gid).listen(_onActivity, onError: _onReadError));
  }

  final GroupsController groups;
  final String gid;
  final List<StreamSubscription<List<Json>>> _subs = [];

  List<GroupMember> _members = const [];
  List<GroupExpense> _expenses = const [];
  List<GroupSettlement> _settlements = const [];
  List<GroupActivity> _activity = const [];
  bool _membersLoaded = false;
  bool _expensesLoaded = false;
  bool _readFailed = false;
  bool _writeFailed = false;
  bool _disposed = false;

  Map<String, int>? _netCache;

  List<GroupMember> get members => _members;
  List<GroupExpense> get expenses => _expenses;
  List<GroupSettlement> get settlements => _settlements;
  List<GroupActivity> get activity => _activity;
  bool get loaded => _membersLoaded && _expensesLoaded;
  bool get hasError => _readFailed || _writeFailed || groups.hasError;
  bool get writeFailed => _writeFailed;

  void clearWriteProblem() {
    _writeFailed = false;
    _notify();
  }

  AppUser get me => groups.me;
  ExpenseGroup? get group => groups.byId(gid);
  bool get isArchived => group?.archived ?? false;

  GroupMember? memberById(String uid) {
    for (final m in _members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  String nameOf(String uid) => memberById(uid)?.name ?? 'Former member';

  GroupRole get myRole => memberById(me.uid)?.role ?? GroupRole.member;
  bool get iAmAdmin => isAdminRole(myRole);

  /// Net position of every current member (see [netBalances]).
  Map<String, int> get net => _netCache ??= netBalances(
        memberIds: _memberIdsForMath(),
        expenses: _expenses,
        settlements: _settlements,
      );

  /// People in the balance: members now, plus anybody who still appears in a bill.
  List<String> _memberIdsForMath() {
    final ids = <String>{for (final m in _members) m.uid};
    for (final e in _expenses) {
      ids.addAll(e.paidBy.keys);
      ids.addAll(e.splits.keys);
    }
    for (final s in _settlements) {
      ids.add(s.from);
      ids.add(s.to);
    }
    return ids.toList();
  }

  List<Transfer> get suggestedPayments => simplifyDebts(net);

  int get myBalance => net[me.uid] ?? 0;

  BudgetProgress budgetThisMonth() => budgetProgress(_expenses, group?.budgetMinor ?? 0, DateTime.now());

  // ---------- reading ----------

  void _onMembers(List<Json> rows) {
    final list = [
      for (final r in rows)
        if (GroupMember.fromMap(r) case final GroupMember m) m,
    ]..sort((a, b) {
        final c = a.role.index.compareTo(b.role.index);
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    _members = list;
    _membersLoaded = true;
    _netCache = null;
    _notify();
  }

  void _onExpenses(List<Json> rows) {
    _expenses = [
      for (final r in rows)
        if (GroupExpense.fromMap(r) case final GroupExpense e) e,
    ]..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
    _expensesLoaded = true;
    _netCache = null;
    _notify();
  }

  void _onSettlements(List<Json> rows) {
    _settlements = [
      for (final r in rows)
        if (GroupSettlement.fromMap(r) case final GroupSettlement s) s,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _netCache = null;
    _notify();
  }

  void _onActivity(List<Json> rows) {
    _activity = [
      for (final r in rows)
        if (GroupActivity.fromMap(r) case final GroupActivity a) a,
    ]..sort((a, b) => b.at.compareTo(a.at));
    _notify();
  }

  void _onReadError(Object _) {
    _readFailed = true;
    _membersLoaded = true;
    _expensesLoaded = true;
    _notify();
  }

  // ---------- writing ----------

  GroupActivity _act(String type, {String subject = '', int amount = 0}) => GroupActivity.create(
        type: type,
        actorId: me.uid,
        actorName: nameOf(me.uid),
        subject: subject,
        amountMinor: amount,
      );

  void _run(Future<void> job) {
    unawaited(job.catchError((Object _) {
      _writeFailed = true;
      _netCache = null;
      _notify();
    }));
  }

  /// A bill is only accepted if paid and owed amounts both add up to the total.
  static bool isConsistent(GroupExpense e) =>
      e.amountMinor > 0 &&
      checkAmounts(e.amountMinor, e.paidBy) == SplitProblem.none &&
      checkAmounts(e.amountMinor, e.splits) == SplitProblem.none;

  /// Makes (or, with [existing], changes) a bill. Returns false if it is not valid
  /// or the group is archived / the person may not change it.
  bool saveExpense({
    GroupExpense? existing,
    required String title,
    required int amountMinor,
    String currency = 'INR',
    int? origMinor,
    double rate = 1.0,
    String categoryId = 'other',
    required int date,
    required Map<String, int> paidBy,
    required Map<String, int> splits,
    SplitType splitType = SplitType.equal,
    Map<String, double> percents = const {},
    String note = '',
  }) {
    if (isArchived) return false;
    if (existing != null && !canEditExpense(myRole, me.uid, existing)) return false;
    final now = nowMs();
    final cleanTitle = title.trim().length > 100 ? title.trim().substring(0, 100) : title.trim();
    final e = GroupExpense(
      id: existing?.id ?? 'x_${newId()}',
      title: cleanTitle.isEmpty ? 'Expense' : cleanTitle,
      amountMinor: amountMinor,
      currency: currency,
      origMinor: origMinor ?? amountMinor,
      rate: rate,
      categoryId: categoryId,
      date: date,
      paidBy: withoutZero(paidBy),
      splits: withoutZero(splits),
      splitType: splitType,
      percents: splitType == SplitType.percent ? percents : const {},
      note: note.trim(),
      createdBy: existing?.createdBy ?? me.uid,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      version: existing == null ? 1 : existing.version + 1,
    );
    if (!isConsistent(e)) return false;
    _run(groups.backend.saveExpense(
      gid,
      e,
      isNew: existing == null,
      activity: _act(existing == null ? 'expense_added' : 'expense_edited', subject: e.title, amount: e.amountMinor),
    ));
    return true;
  }

  bool deleteExpense(GroupExpense e) {
    if (isArchived || !canEditExpense(myRole, me.uid, e)) return false;
    _run(groups.backend.deleteExpense(gid, e.id, _act('expense_deleted', subject: e.title, amount: e.amountMinor)));
    return true;
  }

  /// "I paid [to]" (waits for [to] to confirm) or "[from] paid me" (counts at once).
  bool recordPayment({required String from, required String to, required int amountMinor, String note = ''}) {
    if (isArchived || amountMinor < 1 || from == to) return false;
    final iPaid = from == me.uid;
    final iReceived = to == me.uid;
    if (!iPaid && !iReceived) return false;
    final s = GroupSettlement.create(
      from: from,
      to: to,
      amountMinor: amountMinor,
      status: iReceived ? SettlementStatus.confirmed : SettlementStatus.pending,
      note: note,
    );
    _run(groups.backend.saveSettlement(
      gid,
      s,
      _act(iReceived ? 'settlement_confirmed' : 'settlement_paid', subject: nameOf(iReceived ? from : to), amount: amountMinor),
    ));
    return true;
  }

  bool confirmPayment(GroupSettlement s) {
    if (isArchived || s.confirmed || s.to != me.uid) return false;
    _run(groups.backend.saveSettlement(gid, s.confirmedNow(), _act('settlement_confirmed', subject: nameOf(s.from), amount: s.amountMinor)));
    return true;
  }

  /// Cancels a payment that is still waiting for confirmation.
  bool cancelPayment(GroupSettlement s) {
    if (isArchived || s.confirmed) return false;
    if (s.from != me.uid && s.to != me.uid && !iAmAdmin) return false;
    _run(groups.backend.deleteSettlement(gid, s.id, _act('settlement_cancelled', subject: nameOf(s.to), amount: s.amountMinor)));
    return true;
  }

  bool rename(String name) {
    final n = name.trim();
    if (!iAmAdmin || n.isEmpty || n.length > 60) return false;
    _run(groups.backend.updateGroup(gid, {'name': n}, _act('group_renamed', subject: n)));
    return true;
  }

  bool setLook({required String iconKey, required int colorIndex}) {
    if (!iAmAdmin || !groupIconKeys.contains(iconKey)) return false;
    _run(groups.backend.updateGroup(gid, {'iconKey': iconKey, 'colorIndex': colorIndex}, null));
    return true;
  }

  bool setBudget(int budgetMinor) {
    if (!iAmAdmin || budgetMinor < 0) return false;
    _run(groups.backend.updateGroup(gid, {'budgetMinor': budgetMinor}, _act('budget_changed', amount: budgetMinor)));
    return true;
  }

  bool setArchived(bool archive) {
    if (!iAmAdmin) return false;
    _run(groups.backend.updateGroup(
      gid,
      {'status': archive ? GroupStatus.archived.name : GroupStatus.active.name},
      _act(archive ? 'group_archived' : 'group_restored'),
    ));
    return true;
  }

  bool resetInviteCode() {
    final g = group;
    if (g == null || !iAmAdmin) return false;
    _run(groups.backend.resetInviteCode(
      gid: gid,
      oldCode: g.inviteCode,
      newCode: newInviteCode(),
      groupName: g.name,
      activity: _act('code_reset'),
    ));
    return true;
  }

  bool changeRole(GroupMember target, GroupRole role) {
    if (myRole != GroupRole.owner || target.uid == me.uid || role == GroupRole.owner) return false;
    _run(groups.backend.setRole(gid: gid, uid: target.uid, role: role, activity: _act('role_changed', subject: target.name)));
    return true;
  }

  bool transferOwnership(GroupMember target) {
    if (myRole != GroupRole.owner || target.uid == me.uid) return false;
    _run(groups.backend.transferOwnership(
      gid: gid,
      fromUid: me.uid,
      toUid: target.uid,
      activity: _act('role_changed', subject: target.name),
    ));
    return true;
  }

  bool removeMember(GroupMember target) {
    if (!canRemoveMember(actor: myRole, actorId: me.uid, target: target)) return false;
    _run(groups.backend.removeMember(gid: gid, uid: target.uid, activity: _act('member_removed', subject: target.name)));
    return true;
  }

  /// Why this person cannot leave right now (null = may leave).
  String? get cannotLeaveReason {
    if (myRole == GroupRole.owner) return 'owner';
    if (myBalance != 0) return 'balance';
    return null;
  }

  Future<bool> leave() async {
    if (cannotLeaveReason != null) return false;
    try {
      await groups.backend.leaveGroup(gid: gid, uid: me.uid, activity: _act('member_left', subject: nameOf(me.uid)));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    groups.removeListener(_notify);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Makes the right [GroupsController] for whoever is signed in (none when
/// signed out). Switching account replaces everything - data never mixes.
class GroupsHub extends ChangeNotifier {
  GroupsHub(this._auth, this._backend) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AuthController _auth;
  final GroupBackend Function() _backend;
  GroupsController? _current;

  GroupsController? get current => _current;

  void _onAuth() {
    final user = _auth.user;
    if (user?.uid == _current?.me.uid) return;
    final old = _current;
    _current = user == null ? null : (GroupsController(backend: _backend(), me: user)..start());
    notifyListeners();
    if (old != null) scheduleMicrotask(old.dispose);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _current?.dispose();
    super.dispose();
  }
}
