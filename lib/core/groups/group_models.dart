import '../personal/ids.dart';
import '../personal/models.dart' show Json, nowMs;

String _s(Object? v, int max) {
  if (v is! String) return '';
  return v.length > max ? v.substring(0, max) : v;
}

int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

/// {uid: paise}. Damaged entries are dropped, zero or negative amounts too.
Map<String, int> _moneyMap(Object? v) {
  if (v is! Map) return const {};
  final out = <String, int>{};
  for (final e in v.entries) {
    final k = e.key;
    final n = e.value;
    if (k is String && k.isNotEmpty && n is num && n > 0) out[k] = n.toInt();
  }
  return out;
}

/// Who may do what inside one group.
enum GroupRole { owner, admin, member }

GroupRole roleFrom(Object? v) {
  for (final r in GroupRole.values) {
    if (r.name == v) return r;
  }
  return GroupRole.member;
}

enum GroupStatus { active, archived }

enum SplitType { equal, exact, percent }

SplitType splitTypeFrom(Object? v) {
  for (final r in SplitType.values) {
    if (r.name == v) return r;
  }
  return SplitType.equal;
}

/// Icons a group can use (stored as a key, the screen maps it to an icon).
const List<String> groupIconKeys = ['group', 'home', 'trip', 'food', 'party', 'work', 'school', 'shopping'];

class ExpenseGroup {
  final String id;
  final String name;
  final String iconKey;
  final int colorIndex;

  /// All group money is kept in this currency's minor units (always INR for now).
  final String baseCurrency;
  final String ownerId;
  final List<String> memberIds;
  final String inviteCode;
  final GroupStatus status;

  /// Monthly budget of the whole group in paise, 0 = no budget.
  final int budgetMinor;
  final int createdAt;
  final int updatedAt;

  const ExpenseGroup({
    required this.id,
    required this.name,
    this.iconKey = 'group',
    this.colorIndex = 0,
    this.baseCurrency = 'INR',
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    this.status = GroupStatus.active,
    this.budgetMinor = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get archived => status == GroupStatus.archived;

  ExpenseGroup copyWith({
    String? name,
    String? iconKey,
    int? colorIndex,
    String? ownerId,
    List<String>? memberIds,
    String? inviteCode,
    GroupStatus? status,
    int? budgetMinor,
  }) =>
      ExpenseGroup(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        colorIndex: colorIndex ?? this.colorIndex,
        baseCurrency: baseCurrency,
        ownerId: ownerId ?? this.ownerId,
        memberIds: memberIds ?? this.memberIds,
        inviteCode: inviteCode ?? this.inviteCode,
        status: status ?? this.status,
        budgetMinor: budgetMinor ?? this.budgetMinor,
        createdAt: createdAt,
        updatedAt: nowMs(),
      );

  Json toMap() => {
        'name': name,
        'iconKey': iconKey,
        'colorIndex': colorIndex,
        'baseCurrency': baseCurrency,
        'ownerId': ownerId,
        'memberIds': memberIds,
        'inviteCode': inviteCode,
        'status': status.name,
        'budgetMinor': budgetMinor,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static ExpenseGroup? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final name = _s(m['name'], 60).trim();
    final owner = _s(m['ownerId'], 128);
    if (id.isEmpty || name.isEmpty || owner.isEmpty) return null;
    final ids = <String>[
      if (m['memberIds'] is List)
        for (final e in m['memberIds'] as List)
          if (e is String && e.isNotEmpty) e,
    ];
    return ExpenseGroup(
      id: id,
      name: name,
      iconKey: groupIconKeys.contains(m['iconKey']) ? m['iconKey']! as String : 'group',
      colorIndex: _i(m['colorIndex']).clamp(0, 99),
      baseCurrency: 'INR',
      ownerId: owner,
      memberIds: ids,
      inviteCode: _s(m['inviteCode'], 20),
      status: m['status'] == 'archived' ? GroupStatus.archived : GroupStatus.active,
      budgetMinor: _i(m['budgetMinor']).clamp(0, 100000000000),
      createdAt: _i(m['createdAt']),
      updatedAt: _i(m['updatedAt']),
    );
  }
}

class GroupMember {
  /// The person's account id (also the document id).
  final String uid;
  final String name;
  final String photoUrl;
  final GroupRole role;
  final int joinedAt;

  /// Only written when joining: proves the person knew the invite code.
  final String inviteCode;

  /// Time (ms) up to which this person has read the group chat.
  final int lastReadAt;

  const GroupMember({
    required this.uid,
    required this.name,
    this.photoUrl = '',
    required this.role,
    required this.joinedAt,
    this.inviteCode = '',
    this.lastReadAt = 0,
  });

  String get initial => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  GroupMember copyWith({GroupRole? role, String? name, String? photoUrl}) => GroupMember(
        uid: uid,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        role: role ?? this.role,
        joinedAt: joinedAt,
        inviteCode: inviteCode,
        lastReadAt: lastReadAt,
      );

  Json toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'role': role.name,
        'joinedAt': joinedAt,
        if (inviteCode.isNotEmpty) 'inviteCode': inviteCode,
      };

  static GroupMember? fromMap(Json m) {
    final id = _s(m['id'], 128);
    if (id.isEmpty) return null;
    final name = _s(m['name'], 60).trim();
    return GroupMember(
      uid: id,
      name: name.isEmpty ? 'Member' : name,
      photoUrl: _s(m['photoUrl'], 500),
      role: roleFrom(m['role']),
      joinedAt: _i(m['joinedAt']),
      inviteCode: _s(m['inviteCode'], 20),
      lastReadAt: _i(m['lastReadAt']),
    );
  }
}

/// One chat message of a group. Deleting only blanks the text (so replies still make sense).
class GroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final int createdAt;
  final String replyToId;
  final String replyPreview;
  final bool deleted;

  const GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.replyToId = '',
    this.replyPreview = '',
    this.deleted = false,
  });

  factory GroupMessage.create({
    required String senderId,
    required String senderName,
    required String text,
    String replyToId = '',
    String replyPreview = '',
  }) =>
      GroupMessage(
        id: 'm_${newId()}',
        senderId: senderId,
        senderName: senderName,
        text: text.length > 1000 ? text.substring(0, 1000) : text,
        createdAt: nowMs(),
        replyToId: replyToId,
        replyPreview: replyPreview.length > 80 ? replyPreview.substring(0, 80) : replyPreview,
      );

  Json toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': createdAt,
        'replyToId': replyToId,
        'replyPreview': replyPreview,
        'deleted': deleted,
      };

  static GroupMessage? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final sender = _s(m['senderId'], 128);
    if (id.isEmpty || sender.isEmpty) return null;
    return GroupMessage(
      id: id,
      senderId: sender,
      senderName: _s(m['senderName'], 60),
      text: _s(m['text'], 1000),
      createdAt: _i(m['createdAt']),
      replyToId: _s(m['replyToId'], 80),
      replyPreview: _s(m['replyPreview'], 80),
      deleted: m['deleted'] == true,
    );
  }
}

class GroupExpense {
  final String id;
  final String title;

  /// Total in the group currency (paise). All shares add up to exactly this.
  final int amountMinor;

  /// Currency the bill was paid in, amount in that currency, rupees per 1 unit.
  final String currency;
  final int origMinor;
  final double rate;
  final String categoryId;

  /// Noon of the day (milliseconds).
  final int date;

  /// Who paid how much (adds up to [amountMinor]).
  final Map<String, int> paidBy;

  /// Who owes how much (adds up to [amountMinor]).
  final Map<String, int> splits;
  final SplitType splitType;

  /// Percentages typed by the person (only for [SplitType.percent]), for editing later.
  final Map<String, double> percents;
  final String note;
  final String createdBy;
  final int createdAt;
  final int updatedAt;

  /// Goes up by one on every edit. The security rules only accept
  /// "old version + 1", so two people editing at once cannot silently overwrite each other.
  final int version;

  const GroupExpense({
    required this.id,
    required this.title,
    required this.amountMinor,
    this.currency = 'INR',
    required this.origMinor,
    this.rate = 1.0,
    this.categoryId = 'other',
    required this.date,
    required this.paidBy,
    required this.splits,
    this.splitType = SplitType.equal,
    this.percents = const {},
    this.note = '',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  bool get isForeign => currency != 'INR';

  Json toMap() => {
        'title': title,
        'amountMinor': amountMinor,
        'currency': currency,
        'origMinor': origMinor,
        'rate': rate,
        'categoryId': categoryId,
        'date': date,
        'paidBy': paidBy,
        'splits': splits,
        'splitType': splitType.name,
        if (percents.isNotEmpty) 'percents': percents,
        'note': note,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'version': version,
      };

  static GroupExpense? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final amount = _i(m['amountMinor']);
    if (id.isEmpty || amount < 1) return null;
    final paid = _moneyMap(m['paidBy']);
    final splits = _moneyMap(m['splits']);
    if (paid.isEmpty || splits.isEmpty) return null;
    final pct = <String, double>{};
    if (m['percents'] is Map) {
      for (final e in (m['percents'] as Map).entries) {
        if (e.key is String && e.value is num) pct[e.key as String] = (e.value as num).toDouble();
      }
    }
    final currency = _s(m['currency'], 5);
    return GroupExpense(
      id: id,
      title: _s(m['title'], 100),
      amountMinor: amount,
      currency: currency.isEmpty ? 'INR' : currency,
      origMinor: _i(m['origMinor'], amount),
      rate: _d(m['rate'], 1.0) > 0 ? _d(m['rate'], 1.0) : 1.0,
      categoryId: _s(m['categoryId'], 80).isEmpty ? 'other' : _s(m['categoryId'], 80),
      date: _i(m['date']),
      paidBy: paid,
      splits: splits,
      splitType: splitTypeFrom(m['splitType']),
      percents: pct,
      note: _s(m['note'], 300),
      createdBy: _s(m['createdBy'], 128),
      createdAt: _i(m['createdAt']),
      updatedAt: _i(m['updatedAt']),
      version: _i(m['version'], 1) < 1 ? 1 : _i(m['version'], 1),
    );
  }
}

enum SettlementStatus { pending, confirmed }

/// "[from] paid [to] this amount" (money handed over outside the app).
class GroupSettlement {
  final String id;
  final String from;
  final String to;
  final int amountMinor;
  final SettlementStatus status;
  final String note;
  final int createdAt;
  final int confirmedAt;

  const GroupSettlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amountMinor,
    required this.status,
    this.note = '',
    required this.createdAt,
    this.confirmedAt = 0,
  });

  bool get confirmed => status == SettlementStatus.confirmed;

  factory GroupSettlement.create({
    required String from,
    required String to,
    required int amountMinor,
    required SettlementStatus status,
    String note = '',
  }) {
    final now = nowMs();
    return GroupSettlement(
      id: 's_${newId()}',
      from: from,
      to: to,
      amountMinor: amountMinor,
      status: status,
      note: note,
      createdAt: now,
      confirmedAt: status == SettlementStatus.confirmed ? now : 0,
    );
  }

  GroupSettlement confirmedNow() => GroupSettlement(
        id: id,
        from: from,
        to: to,
        amountMinor: amountMinor,
        status: SettlementStatus.confirmed,
        note: note,
        createdAt: createdAt,
        confirmedAt: nowMs(),
      );

  Json toMap() => {
        'from': from,
        'to': to,
        'amountMinor': amountMinor,
        'status': status.name,
        'note': note,
        'createdAt': createdAt,
        'confirmedAt': confirmedAt,
      };

  static GroupSettlement? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final from = _s(m['from'], 128);
    final to = _s(m['to'], 128);
    final amount = _i(m['amountMinor']);
    if (id.isEmpty || from.isEmpty || to.isEmpty || from == to || amount < 1) return null;
    return GroupSettlement(
      id: id,
      from: from,
      to: to,
      amountMinor: amount,
      status: m['status'] == 'confirmed' ? SettlementStatus.confirmed : SettlementStatus.pending,
      note: _s(m['note'], 200),
      createdAt: _i(m['createdAt']),
      confirmedAt: _i(m['confirmedAt']),
    );
  }
}

/// What happened in the group (kept as data, the screen turns it into words).
/// Types: group_created, member_joined, member_left, member_removed, role_changed,
/// expense_added, expense_edited, expense_deleted, settlement_paid, settlement_confirmed,
/// settlement_cancelled, group_archived, group_restored, group_renamed, budget_changed, code_reset.
class GroupActivity {
  final String id;
  final String type;
  final String actorId;
  final String actorName;

  /// Short text about the subject (expense title, member name, ...).
  final String subject;
  final int amountMinor;
  final int at;

  const GroupActivity({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.subject = '',
    this.amountMinor = 0,
    required this.at,
  });

  factory GroupActivity.create({
    required String type,
    required String actorId,
    required String actorName,
    String subject = '',
    int amountMinor = 0,
  }) =>
      GroupActivity(
        id: 'a_${newId()}',
        type: type,
        actorId: actorId,
        actorName: actorName,
        subject: subject.length > 100 ? subject.substring(0, 100) : subject,
        amountMinor: amountMinor,
        at: nowMs(),
      );

  Json toMap() => {
        'type': type,
        'actorId': actorId,
        'actorName': actorName,
        'subject': subject,
        'amountMinor': amountMinor,
        'at': at,
      };

  static GroupActivity? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final type = _s(m['type'], 40);
    if (id.isEmpty || type.isEmpty) return null;
    return GroupActivity(
      id: id,
      type: type,
      actorId: _s(m['actorId'], 128),
      actorName: _s(m['actorName'], 60),
      subject: _s(m['subject'], 100),
      amountMinor: _i(m['amountMinor']),
      at: _i(m['at']),
    );
  }
}
