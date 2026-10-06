import 'models.dart';

/// Pure functions (no Flutter, no Firebase) behind the study screens.

// ============================ Notes ============================

List<Note> sortNotes(List<Note> notes) =>
    List<Note>.of(notes)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

List<String> allTags(List<Note> notes) {
  final set = <String>{for (final n in notes) ...n.tags};
  return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Search in title, text and tags; optionally only one tag.
List<Note> filterNotes(List<Note> notes, {String query = '', String? tag}) {
  final q = query.trim().toLowerCase();
  return sortNotes([
    for (final n in notes)
      if ((tag == null || n.tags.contains(tag)) &&
          (q.isEmpty ||
              n.title.toLowerCase().contains(q) ||
              n.body.toLowerCase().contains(q) ||
              n.tags.any((t) => t.toLowerCase().contains(q))))
        n,
  ]);
}

/// "maths, physics ,  " -> [maths, physics]
List<String> parseTags(String input) {
  final out = <String>[];
  for (final part in input.split(RegExp(r'[,;\n]'))) {
    final t = part.trim().replaceFirst(RegExp(r'^#'), '');
    if (t.isNotEmpty && !out.contains(t) && out.length < 10) {
      out.add(t.length > 30 ? t.substring(0, 30) : t);
    }
  }
  return out;
}

enum NoteSaveAction { nothing, create, update, saveAsCopy }

/// Decides what to do when a note is saved, WITHOUT ever overwriting changes
/// made on another phone:
///  * [base]    - the note as it was when the editor opened (null = new note)
///  * [current] - the note as it is stored right now (null = it was deleted)
///  * [draft]   - what the person typed
NoteSaveAction resolveNoteSave({Note? base, Note? current, required Note draft}) {
  if (base == null) return draft.isEmpty ? NoteSaveAction.nothing : NoteSaveAction.create;
  if (draft.sameContent(base)) return NoteSaveAction.nothing;
  if (current == null) return NoteSaveAction.create; // deleted elsewhere: keep the work
  if (current.updatedAt == base.updatedAt) return NoteSaveAction.update;
  if (current.sameContent(draft)) return NoteSaveAction.nothing;
  return NoteSaveAction.saveAsCopy; // changed elsewhere meanwhile: keep both
}

// ============================ To-do / tasks ============================

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool isOverdue(int? dueAt, bool done, DateTime now) {
  if (dueAt == null || done) return false;
  return DateTime.fromMillisecondsSinceEpoch(dueAt).isBefore(dayOf(now));
}

/// Pending first (earliest due date first, then higher priority), done last.
List<Todo> sortTodos(List<Todo> todos) {
  final list = List<Todo>.of(todos);
  list.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.done && b.done) return (b.completedAt ?? 0).compareTo(a.completedAt ?? 0);
    final ad = a.dueAt, bd = b.dueAt;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    return a.createdAt.compareTo(b.createdAt);
  });
  return list;
}

List<StudyTask> sortTasks(List<StudyTask> tasks) {
  final list = List<StudyTask>.of(tasks);
  list.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ad = a.dueAt, bd = b.dueAt;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    return a.createdAt.compareTo(b.createdAt);
  });
  return list;
}

// ============================ Progress ============================

enum ProgressPeriod { today, week, month }

class DateRange {
  final DateTime start; // inclusive, midnight
  final DateTime endExclusive; // midnight after the last day
  const DateRange(this.start, this.endExclusive);

  int get days => endExclusive.difference(start).inDays;

  bool contains(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }
}

/// today = this day; week = Monday to Sunday of this week; month = this calendar month.
DateRange rangeFor(ProgressPeriod p, DateTime now) {
  final today = dayOf(now);
  switch (p) {
    case ProgressPeriod.today:
      return DateRange(today, DateTime(today.year, today.month, today.day + 1));
    case ProgressPeriod.week:
      final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
      return DateRange(monday, DateTime(monday.year, monday.month, monday.day + 7));
    case ProgressPeriod.month:
      return DateRange(DateTime(today.year, today.month, 1), DateTime(today.year, today.month + 1, 1));
  }
}

DateRange rangeForGoal(GoalPeriod p, DateTime now) => switch (p) {
      GoalPeriod.daily => rangeFor(ProgressPeriod.today, now),
      GoalPeriod.weekly => rangeFor(ProgressPeriod.week, now),
      GoalPeriod.monthly => rangeFor(ProgressPeriod.month, now),
    };

int minutesInRange(List<StudySession> sessions, DateRange range, {String? subjectId}) {
  var total = 0;
  for (final s in sessions) {
    if (!range.contains(s.startedAt)) continue;
    if (subjectId != null && subjectId.isNotEmpty && s.subjectId != subjectId) continue;
    total += s.minutes;
  }
  return total;
}

/// One entry per day of the range (zero when nothing was studied).
List<({DateTime day, int minutes})> dailyMinutes(List<StudySession> sessions, DateRange range) {
  final byDay = <DateTime, int>{};
  for (final s in sessions) {
    if (!range.contains(s.startedAt)) continue;
    final d = dayOf(DateTime.fromMillisecondsSinceEpoch(s.startedAt));
    byDay[d] = (byDay[d] ?? 0) + s.minutes;
  }
  return [
    for (var i = 0; i < range.days; i++)
      (
        day: DateTime(range.start.year, range.start.month, range.start.day + i),
        minutes: byDay[DateTime(range.start.year, range.start.month, range.start.day + i)] ?? 0,
      ),
  ];
}

/// Minutes per subject id ('' = studied without choosing a subject), biggest first.
List<MapEntry<String, int>> minutesBySubject(List<StudySession> sessions, DateRange range) {
  final map = <String, int>{};
  for (final s in sessions) {
    if (!range.contains(s.startedAt)) continue;
    map[s.subjectId] = (map[s.subjectId] ?? 0) + s.minutes;
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Study tasks and to-dos completed inside the range.
int completedInRange({required List<StudyTask> tasks, required List<Todo> todos, required DateRange range}) {
  var n = 0;
  for (final t in tasks) {
    if (t.done && t.completedAt != null && range.contains(t.completedAt!)) n++;
  }
  for (final t in todos) {
    if (t.done && t.completedAt != null && range.contains(t.completedAt!)) n++;
  }
  return n;
}

class GoalProgress {
  final int minutes;
  final int target;
  const GoalProgress(this.minutes, this.target);
  double get fraction => target <= 0 ? 0 : (minutes / target).clamp(0.0, 1.0);
  bool get reached => minutes >= target;
}

GoalProgress goalProgress(Goal goal, List<StudySession> sessions, DateTime now) {
  final range = rangeForGoal(goal.period, now);
  return GoalProgress(
    minutesInRange(sessions, range, subjectId: goal.subjectId),
    goal.targetMinutes,
  );
}

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

// ============================ Exam countdown ============================

class Countdown {
  final bool passed;
  final int days;
  final int hours;
  final int minutes;
  const Countdown({required this.passed, this.days = 0, this.hours = 0, this.minutes = 0});
}

Countdown countdownTo(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.isNegative || diff == Duration.zero) return const Countdown(passed: true);
  return Countdown(
    passed: false,
    days: diff.inDays,
    hours: diff.inHours.remainder(24),
    minutes: diff.inMinutes.remainder(60),
  );
}

/// Upcoming exams first (soonest first), then past exams (most recent first).
List<Exam> sortExams(List<Exam> exams, DateTime now) {
  final nowMs = now.millisecondsSinceEpoch;
  final upcoming = exams.where((e) => e.at >= nowMs).toList()..sort((a, b) => a.at.compareTo(b.at));
  final past = exams.where((e) => e.at < nowMs).toList()..sort((a, b) => b.at.compareTo(a.at));
  return [...upcoming, ...past];
}

// ============================ Favourites ============================

/// Best guess of what a saved page is, from its address and title.
FavoriteKind guessFavoriteKind(String url, String title) {
  final u = url.toLowerCase();
  final t = title.toLowerCase();
  if (u.startsWith('saralbook://tool/')) return FavoriteKind.tool;
  final host = Uri.tryParse(u)?.host ?? '';
  if (host == 'test.saralbook.com') return FavoriteKind.mockTest;
  if (host == 'store.saralbook.com') return FavoriteKind.product;
  if (host == 'onlinecalcy.com' || host.endsWith('.onlinecalcy.com')) return FavoriteKind.tool;
  bool has(List<String> words) => words.any((w) => t.contains(w) || u.contains(w));
  if (has(['admit card', 'admit-card', 'hall ticket', 'hall-ticket', 'call letter'])) return FavoriteKind.admitCard;
  if (has(['result', 'cut off', 'cut-off', 'merit list', 'answer key'])) return FavoriteKind.result;
  if (has(['recruitment', 'vacancy', 'vacancies', 'notification', 'bharti', 'job'])) return FavoriteKind.job;
  return FavoriteKind.article;
}
