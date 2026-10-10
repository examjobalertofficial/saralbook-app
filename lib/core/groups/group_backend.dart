import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../personal/models.dart' show Json;
import 'group_models.dart';

/// What a person sees before joining.
class InviteInfo {
  final String groupId;
  final String groupName;
  const InviteInfo(this.groupId, this.groupName);
}

/// Thrown when joining with a wrong, old or reset code.
class InviteInvalidException implements Exception {
  const InviteInvalidException();
}

/// Everything the group feature needs from the cloud.
/// Firestore implements it for real; tests use [MemoryGroupBackend].
abstract class GroupBackend {
  Stream<List<Json>> watchMyGroups(String uid);
  Stream<List<Json>> watchMembers(String gid);
  Stream<List<Json>> watchExpenses(String gid);
  Stream<List<Json>> watchSettlements(String gid);
  Stream<List<Json>> watchActivity(String gid);

  Future<void> createGroup({
    required ExpenseGroup group,
    required GroupMember owner,
    required GroupActivity activity,
  });

  /// null = no such code (or it was reset).
  Future<InviteInfo?> lookupInvite(String code);

  Future<void> joinGroup({
    required String gid,
    required String code,
    required GroupMember me,
    required GroupActivity activity,
  });

  Future<void> leaveGroup({required String gid, required String uid, required GroupActivity activity});

  Future<void> removeMember({required String gid, required String uid, required GroupActivity activity});

  /// Changes only the given fields of the group (name, icon, colour, status, budget).
  Future<void> updateGroup(String gid, Json fields, GroupActivity? activity);

  Future<void> resetInviteCode({
    required String gid,
    required String oldCode,
    required String newCode,
    required String groupName,
    required GroupActivity activity,
  });

  Future<void> setRole({required String gid, required String uid, required GroupRole role, required GroupActivity activity});

  Future<void> transferOwnership({
    required String gid,
    required String fromUid,
    required String toUid,
    required GroupActivity activity,
  });

  Future<void> saveExpense(String gid, GroupExpense e, {required bool isNew, required GroupActivity activity});

  Future<void> deleteExpense(String gid, String expenseId, GroupActivity activity);

  Future<void> saveSettlement(String gid, GroupSettlement s, GroupActivity activity);

  Future<void> deleteSettlement(String gid, String settlementId, GroupActivity? activity);
}

// ============================ Firestore ============================

class FirestoreGroupBackend implements GroupBackend {
  FirestoreGroupBackend() : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('expenseGroups');
  DocumentReference<Map<String, dynamic>> _g(String gid) => _groups.doc(gid);
  DocumentReference<Map<String, dynamic>> _invite(String code) => _db.collection('groupInvites').doc(code);

  Stream<List<Json>> _rows(Query<Map<String, dynamic>> q) => q.snapshots().map(
        (s) => [
          for (final d in s.docs) <String, Object?>{...d.data(), 'id': d.id},
        ],
      );

  @override
  Stream<List<Json>> watchMyGroups(String uid) => _rows(_groups.where('memberIds', arrayContains: uid));

  @override
  Stream<List<Json>> watchMembers(String gid) => _rows(_g(gid).collection('members'));

  @override
  Stream<List<Json>> watchExpenses(String gid) => _rows(_g(gid).collection('expenses').orderBy('date', descending: true).limit(3000));

  @override
  Stream<List<Json>> watchSettlements(String gid) =>
      _rows(_g(gid).collection('settlements').orderBy('createdAt', descending: true).limit(1000));

  @override
  Stream<List<Json>> watchActivity(String gid) => _rows(_g(gid).collection('activity').orderBy('at', descending: true).limit(200));

  void _log(WriteBatch b, String gid, GroupActivity a) {
    b.set(_g(gid).collection('activity').doc(a.id), a.toMap());
  }

  @override
  Future<void> createGroup({required ExpenseGroup group, required GroupMember owner, required GroupActivity activity}) {
    final b = _db.batch();
    b.set(_g(group.id), group.toMap());
    b.set(_g(group.id).collection('members').doc(owner.uid), owner.toMap());
    b.set(_invite(group.inviteCode), {'groupId': group.id, 'groupName': group.name, 'active': true});
    _log(b, group.id, activity);
    return b.commit();
  }

  @override
  Future<InviteInfo?> lookupInvite(String code) async {
    final d = await _invite(code).get();
    final m = d.data();
    if (m == null || m['active'] != true) return null;
    final gid = m['groupId'];
    final name = m['groupName'];
    if (gid is! String || gid.isEmpty) return null;
    return InviteInfo(gid, name is String ? name : '');
  }

  @override
  Future<void> joinGroup({
    required String gid,
    required String code,
    required GroupMember me,
    required GroupActivity activity,
  }) {
    final b = _db.batch();
    // The member document carries the code as proof; the rules compare it
    // with the group's real code before they allow the group to change.
    b.set(_g(gid).collection('members').doc(me.uid), {...me.toMap(), 'inviteCode': code});
    b.update(_g(gid), {
      'memberIds': FieldValue.arrayUnion([me.uid]),
    });
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> leaveGroup({required String gid, required String uid, required GroupActivity activity}) {
    final b = _db.batch();
    b.delete(_g(gid).collection('members').doc(uid));
    b.update(_g(gid), {
      'memberIds': FieldValue.arrayRemove([uid]),
    });
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> removeMember({required String gid, required String uid, required GroupActivity activity}) =>
      leaveGroup(gid: gid, uid: uid, activity: activity);

  @override
  Future<void> updateGroup(String gid, Json fields, GroupActivity? activity) {
    final b = _db.batch();
    b.update(_g(gid), {...fields, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
    if (activity != null) _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> resetInviteCode({
    required String gid,
    required String oldCode,
    required String newCode,
    required String groupName,
    required GroupActivity activity,
  }) {
    final b = _db.batch();
    b.delete(_invite(oldCode));
    b.set(_invite(newCode), {'groupId': gid, 'groupName': groupName, 'active': true});
    b.update(_g(gid), {'inviteCode': newCode, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> setRole({required String gid, required String uid, required GroupRole role, required GroupActivity activity}) {
    final b = _db.batch();
    b.update(_g(gid).collection('members').doc(uid), {'role': role.name});
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> transferOwnership({
    required String gid,
    required String fromUid,
    required String toUid,
    required GroupActivity activity,
  }) {
    final b = _db.batch();
    b.update(_g(gid).collection('members').doc(toUid), {'role': GroupRole.owner.name});
    b.update(_g(gid).collection('members').doc(fromUid), {'role': GroupRole.admin.name});
    b.update(_g(gid), {'ownerId': toUid, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> saveExpense(String gid, GroupExpense e, {required bool isNew, required GroupActivity activity}) {
    final b = _db.batch();
    b.set(_g(gid).collection('expenses').doc(e.id), e.toMap());
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> deleteExpense(String gid, String expenseId, GroupActivity activity) {
    final b = _db.batch();
    b.delete(_g(gid).collection('expenses').doc(expenseId));
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> saveSettlement(String gid, GroupSettlement s, GroupActivity activity) {
    final b = _db.batch();
    b.set(_g(gid).collection('settlements').doc(s.id), s.toMap());
    _log(b, gid, activity);
    return b.commit();
  }

  @override
  Future<void> deleteSettlement(String gid, String settlementId, GroupActivity? activity) {
    final b = _db.batch();
    b.delete(_g(gid).collection('settlements').doc(settlementId));
    if (activity != null) _log(b, gid, activity);
    return b.commit();
  }
}

// ============================ Memory (tests) ============================

class MemoryGroupBackend implements GroupBackend {
  final Map<String, Json> groups = {};
  final Map<String, Map<String, Json>> members = {};
  final Map<String, Map<String, Json>> expenses = {};
  final Map<String, Map<String, Json>> settlements = {};
  final Map<String, Map<String, Json>> activity = {};
  final Map<String, Json> invites = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _emit() => _changes.add(null);

  List<Json> _list(Map<String, Json>? m) => [
        if (m != null)
          for (final e in m.entries) <String, Object?>{...e.value, 'id': e.key},
      ];

  Stream<List<Json>> _watch(List<Json> Function() read) {
    late StreamController<List<Json>> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<List<Json>>(
      onListen: () {
        // listen first, then send the current list: no change can slip through
        sub = _changes.stream.listen((_) => controller.add(read()));
        controller.add(read());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<List<Json>> watchMyGroups(String uid) => _watch(() => [
        for (final e in groups.entries)
          if ((e.value['memberIds'] as List).contains(uid)) <String, Object?>{...e.value, 'id': e.key},
      ]);

  @override
  Stream<List<Json>> watchMembers(String gid) => _watch(() => _list(members[gid]));

  @override
  Stream<List<Json>> watchExpenses(String gid) => _watch(() => _list(expenses[gid]));

  @override
  Stream<List<Json>> watchSettlements(String gid) => _watch(() => _list(settlements[gid]));

  @override
  Stream<List<Json>> watchActivity(String gid) => _watch(() => _list(activity[gid]));

  void _log(String gid, GroupActivity a) {
    (activity[gid] ??= {})[a.id] = a.toMap();
  }

  List<String> _ids(String gid) => List<String>.of((groups[gid]!['memberIds'] as List).cast<String>());

  @override
  Future<void> createGroup({required ExpenseGroup group, required GroupMember owner, required GroupActivity activity}) async {
    groups[group.id] = group.toMap();
    (members[group.id] ??= {})[owner.uid] = owner.toMap();
    invites[group.inviteCode] = {'groupId': group.id, 'groupName': group.name, 'active': true};
    _log(group.id, activity);
    _emit();
  }

  @override
  Future<InviteInfo?> lookupInvite(String code) async {
    final m = invites[code];
    if (m == null) return null;
    return InviteInfo(m['groupId']! as String, m['groupName']! as String);
  }

  @override
  Future<void> joinGroup({
    required String gid,
    required String code,
    required GroupMember me,
    required GroupActivity activity,
  }) async {
    final g = groups[gid];
    if (g == null || g['inviteCode'] != code) throw const InviteInvalidException();
    final ids = _ids(gid);
    if (!ids.contains(me.uid)) ids.add(me.uid);
    g['memberIds'] = ids;
    (members[gid] ??= {})[me.uid] = {...me.toMap(), 'inviteCode': code};
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> leaveGroup({required String gid, required String uid, required GroupActivity activity}) async {
    final g = groups[gid];
    if (g == null) return;
    g['memberIds'] = _ids(gid)..remove(uid);
    members[gid]?.remove(uid);
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> removeMember({required String gid, required String uid, required GroupActivity activity}) =>
      leaveGroup(gid: gid, uid: uid, activity: activity);

  @override
  Future<void> updateGroup(String gid, Json fields, GroupActivity? activity) async {
    groups[gid]?.addAll(fields);
    if (activity != null) _log(gid, activity);
    _emit();
  }

  @override
  Future<void> resetInviteCode({
    required String gid,
    required String oldCode,
    required String newCode,
    required String groupName,
    required GroupActivity activity,
  }) async {
    invites.remove(oldCode);
    invites[newCode] = {'groupId': gid, 'groupName': groupName, 'active': true};
    groups[gid]?['inviteCode'] = newCode;
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> setRole({required String gid, required String uid, required GroupRole role, required GroupActivity activity}) async {
    members[gid]?[uid]?['role'] = role.name;
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> transferOwnership({
    required String gid,
    required String fromUid,
    required String toUid,
    required GroupActivity activity,
  }) async {
    members[gid]?[toUid]?['role'] = GroupRole.owner.name;
    members[gid]?[fromUid]?['role'] = GroupRole.admin.name;
    groups[gid]?['ownerId'] = toUid;
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> saveExpense(String gid, GroupExpense e, {required bool isNew, required GroupActivity activity}) async {
    final map = expenses[gid] ??= {};
    final old = map[e.id];
    // same rule as the security rules: an edit must be "old version + 1"
    if (old != null && (old['version'] as num).toInt() + 1 != e.version) {
      throw StateError('conflict');
    }
    map[e.id] = e.toMap();
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> deleteExpense(String gid, String expenseId, GroupActivity activity) async {
    expenses[gid]?.remove(expenseId);
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> saveSettlement(String gid, GroupSettlement s, GroupActivity activity) async {
    (settlements[gid] ??= {})[s.id] = s.toMap();
    _log(gid, activity);
    _emit();
  }

  @override
  Future<void> deleteSettlement(String gid, String settlementId, GroupActivity? activity) async {
    settlements[gid]?.remove(settlementId);
    if (activity != null) _log(gid, activity);
    _emit();
  }
}
