import 'ids.dart';

typedef Json = Map<String, Object?>;

String _s(Object? v, int max) {
  if (v is! String) return '';
  return v.length > max ? v.substring(0, max) : v;
}

int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
int? _iOrNull(Object? v) => v is num ? v.toInt() : null;

List<String> _tags(Object? v) {
  if (v is! List) return const [];
  final out = <String>[];
  for (final e in v) {
    if (e is String && e.trim().isNotEmpty) {
      final t = e.trim().length > 30 ? e.trim().substring(0, 30) : e.trim();
      if (!out.contains(t)) out.add(t);
    }
    if (out.length == 10) break;
  }
  return out;
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

// ============================ Notes ============================

class Note {
  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final int createdAt;
  final int updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.create({String title = '', String body = '', List<String> tags = const []}) {
    final now = nowMs();
    return Note(id: newId(), title: title, body: body, tags: tags, createdAt: now, updatedAt: now);
  }

  Note copyWith({String? title, String? body, List<String>? tags, int? updatedAt}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  bool sameContent(Note o) =>
      title == o.title && body == o.body && tags.join('\u0001') == o.tags.join('\u0001');

  Json toMap() => {
        'title': title,
        'body': body,
        'tags': tags,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Note? fromMap(Json m) {
    final id = _s(m['id'], 80);
    if (id.isEmpty) return null;
    final created = _i(m['createdAt']);
    return Note(
      id: id,
      title: _s(m['title'], 200),
      body: _s(m['body'], 20000),
      tags: _tags(m['tags']),
      createdAt: created,
      updatedAt: _i(m['updatedAt'], created),
    );
  }
}

// ============================ To-do ============================

class Todo {
  final String id;
  final String title;
  final bool done;

  /// 0 = low, 1 = medium, 2 = high
  final int priority;

  /// Due date (midnight of that day) in milliseconds, or null.
  final int? dueAt;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;

  const Todo({
    required this.id,
    required this.title,
    this.done = false,
    this.priority = 1,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Todo.create({required String title, int priority = 1, int? dueAt}) {
    final now = nowMs();
    return Todo(id: newId(), title: title, priority: priority, dueAt: dueAt, createdAt: now, updatedAt: now);
  }

  Todo copyWith({String? title, bool? done, int? priority, int? dueAt, bool clearDue = false}) {
    final now = nowMs();
    final nowDone = done ?? this.done;
    return Todo(
      id: id,
      title: title ?? this.title,
      done: nowDone,
      priority: priority ?? this.priority,
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      createdAt: createdAt,
      updatedAt: now,
      completedAt: nowDone ? (this.done ? completedAt : now) : null,
    );
  }

  Json toMap() => {
        'title': title,
        'done': done,
        'priority': priority,
        'dueAt': dueAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'completedAt': completedAt,
      };

  static Todo? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final title = _s(m['title'], 300);
    if (id.isEmpty || title.isEmpty) return null;
    final created = _i(m['createdAt']);
    return Todo(
      id: id,
      title: title,
      done: m['done'] == true,
      priority: _i(m['priority'], 1).clamp(0, 2),
      dueAt: _iOrNull(m['dueAt']),
      createdAt: created,
      updatedAt: _i(m['updatedAt'], created),
      completedAt: _iOrNull(m['completedAt']),
    );
  }
}

// ============================ Study planner ============================

class Subject {
  final String id;
  final String name;

  /// index into the colour palette (kept as a number so it syncs anywhere)
  final int colorIndex;
  final int createdAt;

  const Subject({required this.id, required this.name, this.colorIndex = 0, required this.createdAt});

  factory Subject.create({required String name, int colorIndex = 0}) =>
      Subject(id: newId(), name: name, colorIndex: colorIndex, createdAt: nowMs());

  Json toMap() => {'name': name, 'colorIndex': colorIndex, 'createdAt': createdAt};

  static Subject? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final name = _s(m['name'], 60);
    if (id.isEmpty || name.isEmpty) return null;
    return Subject(
      id: id,
      name: name,
      colorIndex: _i(m['colorIndex']).clamp(0, 99),
      createdAt: _i(m['createdAt']),
    );
  }
}

class StudyTask {
  final String id;
  final String subjectId; // '' = no subject
  final String title;
  final bool done;
  final int? dueAt;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;

  const StudyTask({
    required this.id,
    this.subjectId = '',
    required this.title,
    this.done = false,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory StudyTask.create({required String title, String subjectId = '', int? dueAt}) {
    final now = nowMs();
    return StudyTask(id: newId(), subjectId: subjectId, title: title, dueAt: dueAt, createdAt: now, updatedAt: now);
  }

  StudyTask copyWith({String? title, bool? done, String? subjectId, int? dueAt, bool clearDue = false}) {
    final now = nowMs();
    final nowDone = done ?? this.done;
    return StudyTask(
      id: id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      done: nowDone,
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      createdAt: createdAt,
      updatedAt: now,
      completedAt: nowDone ? (this.done ? completedAt : now) : null,
    );
  }

  Json toMap() => {
        'subjectId': subjectId,
        'title': title,
        'done': done,
        'dueAt': dueAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'completedAt': completedAt,
      };

  static StudyTask? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final title = _s(m['title'], 300);
    if (id.isEmpty || title.isEmpty) return null;
    final created = _i(m['createdAt']);
    return StudyTask(
      id: id,
      subjectId: _s(m['subjectId'], 80),
      title: title,
      done: m['done'] == true,
      dueAt: _iOrNull(m['dueAt']),
      createdAt: created,
      updatedAt: _i(m['updatedAt'], created),
      completedAt: _iOrNull(m['completedAt']),
    );
  }
}

class StudySession {
  final String id;
  final String subjectId;
  final int minutes;

  /// When the studying happened (milliseconds).
  final int startedAt;
  final String note;
  final int createdAt;

  const StudySession({
    required this.id,
    this.subjectId = '',
    required this.minutes,
    required this.startedAt,
    this.note = '',
    required this.createdAt,
  });

  factory StudySession.create({String subjectId = '', required int minutes, required int startedAt, String note = ''}) =>
      StudySession(id: newId(), subjectId: subjectId, minutes: minutes, startedAt: startedAt, note: note, createdAt: nowMs());

  Json toMap() => {
        'subjectId': subjectId,
        'minutes': minutes,
        'startedAt': startedAt,
        'note': note,
        'createdAt': createdAt,
      };

  static StudySession? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final minutes = _i(m['minutes']);
    if (id.isEmpty || minutes < 1 || minutes > 1440) return null;
    final created = _i(m['createdAt']);
    return StudySession(
      id: id,
      subjectId: _s(m['subjectId'], 80),
      minutes: minutes,
      startedAt: _i(m['startedAt'], created),
      note: _s(m['note'], 300),
      createdAt: created,
    );
  }
}

enum GoalPeriod { daily, weekly, monthly }

class Goal {
  final String id;
  final String title;
  final GoalPeriod period;
  final int targetMinutes;
  final String subjectId; // '' = all subjects
  final int createdAt;

  const Goal({
    required this.id,
    required this.title,
    required this.period,
    required this.targetMinutes,
    this.subjectId = '',
    required this.createdAt,
  });

  factory Goal.create({
    required String title,
    required GoalPeriod period,
    required int targetMinutes,
    String subjectId = '',
  }) =>
      Goal(id: newId(), title: title, period: period, targetMinutes: targetMinutes, subjectId: subjectId, createdAt: nowMs());

  Json toMap() => {
        'title': title,
        'period': period.name,
        'targetMinutes': targetMinutes,
        'subjectId': subjectId,
        'createdAt': createdAt,
      };

  static Goal? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final target = _i(m['targetMinutes']);
    final period = GoalPeriod.values.where((p) => p.name == m['period']);
    if (id.isEmpty || target < 1 || target > 100000 || period.isEmpty) return null;
    return Goal(
      id: id,
      title: _s(m['title'], 100),
      period: period.first,
      targetMinutes: target,
      subjectId: _s(m['subjectId'], 80),
      createdAt: _i(m['createdAt']),
    );
  }
}

// ============================ Exam countdown ============================

class Exam {
  final String id;
  final String name;

  /// Exam date and time in milliseconds.
  final int at;
  final int createdAt;

  const Exam({required this.id, required this.name, required this.at, required this.createdAt});

  factory Exam.create({required String name, required int at}) =>
      Exam(id: newId(), name: name, at: at, createdAt: nowMs());

  Exam copyWith({String? name, int? at}) =>
      Exam(id: id, name: name ?? this.name, at: at ?? this.at, createdAt: createdAt);

  Json toMap() => {'name': name, 'at': at, 'createdAt': createdAt};

  static Exam? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final name = _s(m['name'], 120);
    final at = _iOrNull(m['at']);
    if (id.isEmpty || name.isEmpty || at == null) return null;
    return Exam(id: id, name: name, at: at, createdAt: _i(m['createdAt']));
  }
}

// ============================ Favourites ============================

enum FavoriteKind { job, article, result, admitCard, mockTest, tool, product, page }

class Favorite {
  final String id;
  final FavoriteKind kind;
  final String title;
  final String url;
  final int createdAt;

  const Favorite({
    required this.id,
    required this.kind,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  /// The id comes from the address, so saving the same page twice (even on two
  /// phones) never makes a duplicate.
  factory Favorite.create({required FavoriteKind kind, required String title, required String url}) =>
      Favorite(id: 'f_${stableHash(url)}', kind: kind, title: title, url: url, createdAt: nowMs());

  Json toMap() => {'kind': kind.name, 'title': title, 'url': url, 'createdAt': createdAt};

  static Favorite? fromMap(Json m) {
    final id = _s(m['id'], 80);
    final url = _s(m['url'], 2000);
    if (id.isEmpty || url.isEmpty) return null;
    final kind = FavoriteKind.values.where((k) => k.name == m['kind']);
    return Favorite(
      id: id,
      kind: kind.isEmpty ? FavoriteKind.page : kind.first,
      title: _s(m['title'], 200).isEmpty ? url : _s(m['title'], 200),
      url: url,
      createdAt: _i(m['createdAt']),
    );
  }
}
