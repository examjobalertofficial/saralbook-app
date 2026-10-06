import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/personal/ids.dart';
import 'package:app/core/personal/logic.dart';
import 'package:app/core/personal/models.dart';

int ms(int y, int m, int d, [int h = 0, int min = 0]) => DateTime(y, m, d, h, min).millisecondsSinceEpoch;

Note note(String id, String title, String body, int updated, [List<String> tags = const []]) =>
    Note(id: id, title: title, body: body, tags: tags, createdAt: 1, updatedAt: updated);

void main() {
  group('ids', () {
    test('newId is unique', () {
      final ids = {for (var i = 0; i < 2000; i++) newId()};
      expect(ids.length, 2000);
    });

    test('stableHash is stable and distinguishes pages', () {
      expect(stableHash('https://a.com/x'), stableHash('https://a.com/x'));
      expect(stableHash('https://a.com/x'), isNot(stableHash('https://a.com/y')));
      expect(stableHash(''), isNotEmpty);
    });

    test('same page always gives the same favourite id', () {
      final a = Favorite.create(kind: FavoriteKind.job, title: 'A', url: 'https://examjobalert.com/ssc');
      final b = Favorite.create(kind: FavoriteKind.article, title: 'B', url: 'https://examjobalert.com/ssc');
      expect(a.id, b.id);
    });
  });

  group('models', () {
    test('note round trip and damaged data', () {
      final n = Note.create(title: 'Maths', body: 'x', tags: ['a', 'b']);
      final back = Note.fromMap({...n.toMap(), 'id': n.id})!;
      expect(back.title, 'Maths');
      expect(back.tags, ['a', 'b']);
      expect(Note.fromMap({'title': 'no id'}), isNull);
      expect(Note.fromMap({'id': 'x', 'title': 5, 'tags': 'oops'})!.title, '');
    });

    test('note text is limited', () {
      final n = Note.fromMap({'id': 'x', 'body': 'a' * 50000})!;
      expect(n.body.length, 20000);
    });

    test('tags are cleaned: trimmed, unique, max 10', () {
      final n = Note.fromMap({
        'id': 'x',
        'tags': [' a ', 'a', '', 5, for (var i = 0; i < 20; i++) 't$i'],
      })!;
      expect(n.tags.first, 'a');
      expect(n.tags.length, 10);
    });

    test('todo: completing sets completedAt, un-completing clears it', () {
      final t = Todo.create(title: 'Read');
      final done = t.copyWith(done: true);
      expect(done.done, isTrue);
      expect(done.completedAt, isNotNull);
      final undone = done.copyWith(done: false);
      expect(undone.completedAt, isNull);
      expect(Todo.fromMap({'id': 'x', 'title': ''}), isNull);
      expect(Todo.fromMap({'id': 'x', 'title': 'a', 'priority': 9})!.priority, 2);
    });

    test('session, goal and exam validation', () {
      expect(StudySession.fromMap({'id': 'x', 'minutes': 0}), isNull);
      expect(StudySession.fromMap({'id': 'x', 'minutes': 2000}), isNull);
      expect(StudySession.fromMap({'id': 'x', 'minutes': 30, 'startedAt': 5})!.minutes, 30);
      expect(Goal.fromMap({'id': 'x', 'period': 'yearly', 'targetMinutes': 5}), isNull);
      expect(Goal.fromMap({'id': 'x', 'period': 'weekly', 'targetMinutes': 600})!.period, GoalPeriod.weekly);
      expect(Exam.fromMap({'id': 'x', 'name': 'SSC'}), isNull);
      expect(Exam.fromMap({'id': 'x', 'name': 'SSC', 'at': 5})!.at, 5);
    });

    test('favourite with unknown kind becomes a plain page', () {
      final f = Favorite.fromMap({'id': 'f', 'url': 'https://x.com', 'kind': 'zzz'})!;
      expect(f.kind, FavoriteKind.page);
      expect(f.title, 'https://x.com');
    });
  });

  group('notes', () {
    final notes = [
      note('1', 'Algebra', 'quadratic equations', 100, ['maths']),
      note('2', 'Poly', 'Fundamental rights', 300, ['polity', 'gs']),
      note('3', 'Geometry', 'triangles', 200, ['maths']),
    ];

    test('sorted newest first', () {
      expect(sortNotes(notes).map((n) => n.id), ['2', '3', '1']);
    });

    test('search in title, text and tags; tag filter', () {
      expect(filterNotes(notes, query: 'quadratic').map((n) => n.id), ['1']);
      expect(filterNotes(notes, query: 'RIGHTS').map((n) => n.id), ['2']);
      expect(filterNotes(notes, query: 'gs').map((n) => n.id), ['2']);
      expect(filterNotes(notes, tag: 'maths').map((n) => n.id), ['3', '1']);
      expect(filterNotes(notes, query: 'tri', tag: 'maths').map((n) => n.id), ['3']);
      expect(filterNotes(notes, query: 'zzz'), isEmpty);
    });

    test('allTags is sorted and unique', () {
      expect(allTags(notes), ['gs', 'maths', 'polity']);
    });

    test('parseTags', () {
      expect(parseTags('maths, #physics ;  maths,\n gs'), ['maths', 'physics', 'gs']);
      expect(parseTags('  ,, '), isEmpty);
    });
  });

  group('note save never overwrites other phones', () {
    final base = note('n', 'T', 'old', 100);

    test('new note: create, but not an empty one', () {
      expect(resolveNoteSave(draft: note('n', 'Hi', '', 1)), NoteSaveAction.create);
      expect(resolveNoteSave(draft: note('n', ' ', ' ', 1)), NoteSaveAction.nothing);
    });

    test('no change -> nothing', () {
      expect(resolveNoteSave(base: base, current: base, draft: base), NoteSaveAction.nothing);
    });

    test('normal edit -> update in place', () {
      final draft = base.copyWith(body: 'new');
      expect(resolveNoteSave(base: base, current: base, draft: draft), NoteSaveAction.update);
    });

    test('changed on another phone meanwhile -> keep both as a copy', () {
      final theirs = base.copyWith(body: 'their edit', updatedAt: 500);
      final draft = base.copyWith(body: 'my edit');
      expect(resolveNoteSave(base: base, current: theirs, draft: draft), NoteSaveAction.saveAsCopy);
    });

    test('other phone made the very same edit -> nothing to do', () {
      final theirs = base.copyWith(body: 'same', updatedAt: 500);
      final draft = base.copyWith(body: 'same');
      expect(resolveNoteSave(base: base, current: theirs, draft: draft), NoteSaveAction.nothing);
    });

    test('deleted elsewhere while editing -> recreate so work is not lost', () {
      expect(resolveNoteSave(base: base, current: null, draft: base.copyWith(body: 'mine')), NoteSaveAction.create);
    });
  });

  group('to-do ordering', () {
    final now = DateTime(2026, 10, 5, 10);
    Todo todo(String id, {int? due, int priority = 1, bool done = false, int created = 1, int? completed}) => Todo(
          id: id, title: id, done: done, priority: priority, dueAt: due,
          createdAt: created, updatedAt: created, completedAt: completed,
        );

    test('pending by due date, then priority; done last (most recent first)', () {
      final sorted = sortTodos([
        todo('done1', done: true, completed: 5),
        todo('nodue-low', priority: 0),
        todo('late', due: ms(2026, 10, 9)),
        todo('soon', due: ms(2026, 10, 6)),
        todo('nodue-high', priority: 2),
        todo('done2', done: true, completed: 9),
      ]);
      expect(sorted.map((t) => t.id), ['soon', 'late', 'nodue-high', 'nodue-low', 'done2', 'done1']);
    });

    test('overdue means before today and not done', () {
      expect(isOverdue(ms(2026, 10, 4), false, now), isTrue);
      expect(isOverdue(ms(2026, 10, 5), false, now), isFalse);
      expect(isOverdue(ms(2026, 10, 4), true, now), isFalse);
      expect(isOverdue(null, false, now), isFalse);
    });
  });

  group('progress', () {
    final now = DateTime(2026, 10, 7, 12); // Wednesday
    StudySession s(int y, int m, int d, int minutes, [String subject = '']) => StudySession(
          id: '$y$m$d$minutes$subject', subjectId: subject, minutes: minutes,
          startedAt: ms(y, m, d, 9), createdAt: 1,
        );

    test('ranges', () {
      final w = rangeFor(ProgressPeriod.week, now);
      expect(w.start, DateTime(2026, 10, 5)); // Monday
      expect(w.days, 7);
      final m = rangeFor(ProgressPeriod.month, now);
      expect(m.start, DateTime(2026, 10, 1));
      expect(m.days, 31);
      final t = rangeFor(ProgressPeriod.today, now);
      expect(t.days, 1);
      expect(rangeFor(ProgressPeriod.month, DateTime(2026, 12, 15)).endExclusive, DateTime(2027, 1, 1));
    });

    final sessions = [
      s(2026, 10, 5, 60, 'maths'),
      s(2026, 10, 7, 30, 'maths'),
      s(2026, 10, 7, 45, 'gs'),
      s(2026, 10, 1, 120, 'gs'),
      s(2026, 9, 30, 500, 'gs'),
    ];

    test('totals per period', () {
      expect(minutesInRange(sessions, rangeFor(ProgressPeriod.today, now)), 75);
      expect(minutesInRange(sessions, rangeFor(ProgressPeriod.week, now)), 135);
      expect(minutesInRange(sessions, rangeFor(ProgressPeriod.month, now)), 255);
      expect(minutesInRange(sessions, rangeFor(ProgressPeriod.month, now), subjectId: 'maths'), 90);
    });

    test('daily buckets include empty days', () {
      final d = dailyMinutes(sessions, rangeFor(ProgressPeriod.week, now));
      expect(d.length, 7);
      expect(d.map((e) => e.minutes).toList(), [60, 0, 75, 0, 0, 0, 0]);
    });

    test('subject-wise, biggest first', () {
      final r = minutesBySubject(sessions, rangeFor(ProgressPeriod.month, now));
      expect(r.map((e) => '${e.key}:${e.value}').toList(), ['gs:165', 'maths:90']);
    });

    test('completed counts use completion time', () {
      final range = rangeFor(ProgressPeriod.week, now);
      final tasks = [
        StudyTask(id: 'a', title: 'a', done: true, createdAt: 1, updatedAt: 1, completedAt: ms(2026, 10, 6)),
        StudyTask(id: 'b', title: 'b', done: true, createdAt: 1, updatedAt: 1, completedAt: ms(2026, 9, 1)),
        StudyTask(id: 'c', title: 'c', createdAt: 1, updatedAt: 1),
      ];
      final todos = [
        Todo(id: 'd', title: 'd', done: true, createdAt: 1, updatedAt: 1, completedAt: ms(2026, 10, 7)),
      ];
      expect(completedInRange(tasks: tasks, todos: todos, range: range), 2);
    });

    test('goal progress', () {
      final weekly = Goal(id: 'g', title: 'g', period: GoalPeriod.weekly, targetMinutes: 270, createdAt: 1);
      final p = goalProgress(weekly, sessions, now);
      expect(p.minutes, 135);
      expect(p.fraction, 0.5);
      expect(p.reached, isFalse);
      final maths = Goal(id: 'g2', title: 'g', period: GoalPeriod.daily, targetMinutes: 20, subjectId: 'maths', createdAt: 1);
      final q = goalProgress(maths, sessions, now);
      expect(q.minutes, 30);
      expect(q.fraction, 1.0);
      expect(q.reached, isTrue);
    });

    test('formatMinutes', () {
      expect(formatMinutes(45), '45 min');
      expect(formatMinutes(60), '1 h');
      expect(formatMinutes(135), '2 h 15 min');
    });
  });

  group('countdown', () {
    final now = DateTime(2026, 10, 5, 10, 0);

    test('days, hours, minutes', () {
      final c = countdownTo(DateTime(2026, 10, 8, 12, 30), now);
      expect((c.passed, c.days, c.hours, c.minutes), (false, 3, 2, 30));
    });

    test('passed', () {
      expect(countdownTo(DateTime(2026, 10, 5, 9), now).passed, isTrue);
      expect(countdownTo(now, now).passed, isTrue);
    });

    test('exams: upcoming soonest first, then past most recent first', () {
      Exam e(String id, DateTime at) => Exam(id: id, name: id, at: at.millisecondsSinceEpoch, createdAt: 1);
      final sorted = sortExams([
        e('past-old', DateTime(2026, 1, 1)),
        e('later', DateTime(2026, 12, 1)),
        e('past-new', DateTime(2026, 9, 1)),
        e('soon', DateTime(2026, 10, 20)),
      ], now);
      expect(sorted.map((x) => x.id), ['soon', 'later', 'past-new', 'past-old']);
    });
  });

  group('favourite kind guess', () {
    test('by website', () {
      expect(guessFavoriteKind('https://test.saralbook.com/x', 'Test'), FavoriteKind.mockTest);
      expect(guessFavoriteKind('https://store.saralbook.com/p', 'Notes'), FavoriteKind.product);
      expect(guessFavoriteKind('https://onlinecalcy.com/emi', 'EMI'), FavoriteKind.tool);
      expect(guessFavoriteKind('saralbook://tool/emi', 'EMI'), FavoriteKind.tool);
    });

    test('by words in title or address', () {
      expect(guessFavoriteKind('https://examjobalert.com/a', 'SSC CGL Admit Card 2026'), FavoriteKind.admitCard);
      expect(guessFavoriteKind('https://examjobalert.com/a', 'RRB NTPC Result Declared'), FavoriteKind.result);
      expect(guessFavoriteKind('https://examjobalert.com/a', 'Railway Recruitment 2026'), FavoriteKind.job);
      expect(guessFavoriteKind('https://saralbook.com/blog/tips', 'How to study'), FavoriteKind.article);
    });
  });
}
