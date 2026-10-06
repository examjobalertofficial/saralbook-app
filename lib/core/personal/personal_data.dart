import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'cloud_collection.dart';
import 'collection_controller.dart';
import 'models.dart';

typedef CollectionFactory = CloudCollection Function(String uid, String name);

/// All personal lists of ONE account. A new object is made for every account,
/// so data of one account can never leak into another.
class PersonalData {
  PersonalData(this.uid, CollectionFactory make)
      : notes = CollectionController<Note>(
          collection: make(uid, 'notes'),
          fromMap: Note.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        todos = CollectionController<Todo>(
          collection: make(uid, 'todos'),
          fromMap: Todo.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        subjects = CollectionController<Subject>(
          collection: make(uid, 'subjects'),
          fromMap: Subject.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        studyTasks = CollectionController<StudyTask>(
          collection: make(uid, 'study_tasks'),
          fromMap: StudyTask.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        sessions = CollectionController<StudySession>(
          collection: make(uid, 'study_sessions'),
          fromMap: StudySession.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        goals = CollectionController<Goal>(
          collection: make(uid, 'goals'),
          fromMap: Goal.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        exams = CollectionController<Exam>(
          collection: make(uid, 'exams'),
          fromMap: Exam.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ),
        favorites = CollectionController<Favorite>(
          collection: make(uid, 'favorites'),
          fromMap: Favorite.fromMap,
          toMap: (n) => n.toMap(),
          idOf: (n) => n.id,
        ) {
    for (final c in all) {
      c.start();
    }
  }

  final String uid;
  final CollectionController<Note> notes;
  final CollectionController<Todo> todos;
  final CollectionController<Subject> subjects;
  final CollectionController<StudyTask> studyTasks;
  final CollectionController<StudySession> sessions;
  final CollectionController<Goal> goals;
  final CollectionController<Exam> exams;
  final CollectionController<Favorite> favorites;

  List<CollectionController<Object>> get all =>
      [notes, todos, subjects, studyTasks, sessions, goals, exams, favorites];

  bool get hasError => all.any((c) => c.hasError);

  Favorite? favoriteForUrl(String url) {
    for (final f in favorites.items) {
      if (f.url == url) return f;
    }
    return null;
  }

  /// Everything as plain data (for "Export my data").
  Map<String, Object?> exportAll() => {
        'exportedAt': DateTime.now().toIso8601String(),
        'notes': [for (final n in notes.items) {'id': n.id, ...n.toMap()}],
        'todos': [for (final n in todos.items) {'id': n.id, ...n.toMap()}],
        'subjects': [for (final n in subjects.items) {'id': n.id, ...n.toMap()}],
        'studyTasks': [for (final n in studyTasks.items) {'id': n.id, ...n.toMap()}],
        'studySessions': [for (final n in sessions.items) {'id': n.id, ...n.toMap()}],
        'goals': [for (final n in goals.items) {'id': n.id, ...n.toMap()}],
        'exams': [for (final n in exams.items) {'id': n.id, ...n.toMap()}],
        'favorites': [for (final n in favorites.items) {'id': n.id, ...n.toMap()}],
      };

  /// Deletes all cloud data of this account (needs the internet).
  Future<void> deleteAll() async {
    for (final c in all) {
      await c.collection.clearAll();
    }
  }

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

/// Creates the right [PersonalData] for whoever is signed in (and none when
/// signed out). Switching account replaces everything.
class PersonalDataHub extends ChangeNotifier {
  PersonalDataHub(this._auth, this._make) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AuthController _auth;
  final CollectionFactory _make;
  PersonalData? _current;

  /// null when nobody is signed in.
  PersonalData? get current => _current;

  void _onAuth() {
    final uid = _auth.user?.uid;
    if (uid == _current?.uid) return;
    final old = _current;
    _current = uid == null ? null : PersonalData(uid, _make);
    notifyListeners();
    // dispose after listeners switched to the new object
    if (old != null) {
      scheduleMicrotask(old.dispose);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _current?.dispose();
    super.dispose();
  }
}
