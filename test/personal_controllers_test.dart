import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/auth/auth_backend.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/personal/cloud_collection.dart';
import 'package:app/core/personal/collection_controller.dart';
import 'package:app/core/personal/models.dart';
import 'package:app/core/personal/personal_data.dart';

import 'fakes/fake_auth_backend.dart';

const _userA = AppUser(uid: 'a', name: 'A', email: 'a@gmail.com');
const _userB = AppUser(uid: 'b', name: 'B', email: 'b@gmail.com');

/// Lets queued stream events run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

CollectionController<Note> noteController(MemoryCollection mem) => CollectionController<Note>(
      collection: mem,
      fromMap: Note.fromMap,
      toMap: (n) => n.toMap(),
      idOf: (n) => n.id,
    );

class FailingCollection implements CloudCollection {
  @override
  Stream<List<Json>> watch() => Stream<List<Json>>.error(StateError('permission denied'));
  @override
  Future<void> put(String id, Json data) => Future<void>.error(StateError('denied'));
  @override
  Future<void> remove(String id) => Future<void>.error(StateError('denied'));
  @override
  Future<void> clearAll() => Future<void>.error(StateError('denied'));
}

void main() {
  group('CollectionController', () {
    test('loads existing rows and ignores damaged ones', () async {
      final mem = MemoryCollection();
      mem.externalPut('good', Note.create(title: 'ok').toMap());
      mem.externalPut('bad', {'title': 5, 'tags': 7, 'createdAt': 'x'});
      mem.externalPut('', {'title': 'no id'});
      final c = noteController(mem)..start();
      await settle();
      expect(c.loaded, isTrue);
      // 'bad' still parses (fields default), only the empty id is dropped
      expect(c.items.map((n) => n.id), containsAll(['good', 'bad']));
      expect(c.items.length, 2);
      c.dispose();
    });

    test('add, change and delete show up immediately', () async {
      final mem = MemoryCollection();
      final c = noteController(mem)..start();
      await settle();
      expect(c.items, isEmpty);

      final n = Note.create(title: 'First', body: 'a');
      c.upsert(n);
      await settle();
      expect(c.items.single.title, 'First');
      expect(c.byId(n.id)?.body, 'a');

      c.upsert(n.copyWith(body: 'b'));
      await settle();
      expect(c.items.length, 1); // same id: replaced, not duplicated
      expect(c.byId(n.id)?.body, 'b');

      c.remove(n.id);
      await settle();
      expect(c.items, isEmpty);
      expect(c.byId(n.id), isNull);
      c.dispose();
    });

    test('saving the same record twice never duplicates it', () async {
      final mem = MemoryCollection();
      final c = noteController(mem)..start();
      final n = Note.create(title: 'Once');
      c.upsert(n);
      c.upsert(n);
      c.upsert(n);
      await settle();
      expect(c.items.length, 1);
      c.dispose();
    });

    test('changes made on another phone appear', () async {
      final mem = MemoryCollection();
      final c = noteController(mem)..start();
      await settle();
      var notified = 0;
      c.addListener(() => notified++);
      mem.externalPut('remote1', Note.create(title: 'From tablet').toMap());
      await settle();
      expect(c.items.single.title, 'From tablet');
      expect(notified, greaterThan(0));
      c.dispose();
    });

    test('a failing server marks hasError but never throws', () async {
      final c = CollectionController<Note>(
        collection: FailingCollection(),
        fromMap: Note.fromMap,
        toMap: (n) => n.toMap(),
        idOf: (n) => n.id,
      )..start();
      await settle();
      expect(c.loaded, isTrue);
      expect(c.hasError, isTrue);
      c.upsert(Note.create(title: 'x')); // must not throw
      await settle();
      c.dispose();
    });
  });

  group('PersonalDataHub (one account at a time)', () {
    late Map<String, MemoryCollection> store; // "the cloud": one collection per uid/name

    CloudCollection make(String uid, String name) =>
        store.putIfAbsent('$uid/$name', MemoryCollection.new);

    setUp(() => store = {});

    test('nobody signed in: no data', () async {
      final auth = AuthController.ready(FakeAuthBackend());
      await auth.init();
      final hub = PersonalDataHub(auth, make);
      expect(hub.current, isNull);
      hub.dispose();
    });

    test('data of one account is never visible to another', () async {
      final backend = FakeAuthBackend();
      final auth = AuthController.ready(backend);
      await auth.init();
      final hub = PersonalDataHub(auth, make);

      // Account A writes a note and a favourite
      backend.nextResult = _userA;
      await auth.signIn();
      await settle();
      final a = hub.current!;
      expect(a.uid, 'a');
      a.notes.upsert(Note.create(title: 'Secret of A'));
      a.favorites.upsert(Favorite.create(kind: FavoriteKind.job, title: 'Job A', url: 'https://examjobalert.com/a'));
      await settle();
      expect(a.notes.items.single.title, 'Secret of A');

      // Switch to account B: completely fresh, sees nothing of A
      backend.nextResult = _userB;
      await auth.signIn();
      await settle();
      final b = hub.current!;
      expect(b.uid, 'b');
      expect(identical(a, b), isFalse);
      expect(b.notes.items, isEmpty);
      expect(b.favorites.items, isEmpty);
      b.notes.upsert(Note.create(title: 'Secret of B'));
      await settle();

      // Back to A: A's data is still there and B's is not
      backend.nextResult = _userA;
      await auth.signIn();
      await settle();
      final a2 = hub.current!;
      expect(a2.notes.items.map((n) => n.title), ['Secret of A']);
      expect(a2.favorites.items.length, 1);

      // The two accounts used different storage paths
      expect(store.keys.where((k) => k.startsWith('a/')), isNotEmpty);
      expect(store.keys.where((k) => k.startsWith('b/')), isNotEmpty);
      hub.dispose();
    });

    test('signing out removes access to the data', () async {
      final backend = FakeAuthBackend();
      final auth = AuthController.ready(backend);
      await auth.init();
      final hub = PersonalDataHub(auth, make);
      await auth.signIn();
      await settle();
      expect(hub.current, isNotNull);
      await auth.signOut();
      await settle();
      expect(hub.current, isNull);
      hub.dispose();
    });

    test('export contains everything, delete removes everything', () async {
      final backend = FakeAuthBackend();
      final auth = AuthController.ready(backend);
      await auth.init();
      final hub = PersonalDataHub(auth, make);
      await auth.signIn();
      await settle();
      final data = hub.current!;
      data.notes.upsert(Note.create(title: 'N', tags: ['x']));
      data.todos.upsert(Todo.create(title: 'T'));
      data.subjects.upsert(Subject.create(name: 'Maths'));
      data.exams.upsert(Exam.create(name: 'SSC', at: 123456));
      data.sessions.upsert(StudySession.create(minutes: 30, startedAt: 1000));
      await settle();

      final export = data.exportAll();
      expect((export['notes'] as List).length, 1);
      expect((export['todos'] as List).length, 1);
      expect((export['subjects'] as List).length, 1);
      expect((export['exams'] as List).length, 1);
      expect((export['studySessions'] as List).length, 1);
      expect(export['exportedAt'], isA<String>());
      expect(((export['notes'] as List).first as Map)['id'], isNotEmpty);

      await data.deleteAll();
      await settle();
      expect(data.notes.items, isEmpty);
      expect(data.todos.items, isEmpty);
      expect(data.subjects.items, isEmpty);
      expect(data.exams.items, isEmpty);
      expect(data.sessions.items, isEmpty);
      hub.dispose();
    });

    test('favoriteForUrl finds a saved page', () async {
      final backend = FakeAuthBackend();
      final auth = AuthController.ready(backend);
      await auth.init();
      final hub = PersonalDataHub(auth, make);
      await auth.signIn();
      await settle();
      final data = hub.current!;
      expect(data.favoriteForUrl('https://x.com/p'), isNull);
      data.favorites.upsert(Favorite.create(kind: FavoriteKind.article, title: 'P', url: 'https://x.com/p'));
      await settle();
      expect(data.favoriteForUrl('https://x.com/p')?.title, 'P');
      hub.dispose();
    });
  });
}
