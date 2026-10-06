import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// One list of records belonging to ONE signed-in person
/// (e.g. their notes). Firestore implements it for real; tests use memory.
abstract class CloudCollection {
  /// Emits the full list now and after every change (also changes made on
  /// other phones). Each row contains its id under the key `id`.
  Stream<List<Json>> watch();

  /// Creates or replaces a record. Completes when the server confirms;
  /// offline, Firestore keeps the change and sends it when the internet returns,
  /// and [watch] already shows it.
  Future<void> put(String id, Json data);

  Future<void> remove(String id);

  /// Deletes every record (used by "Delete my data").
  Future<void> clearAll();
}

/// `users/{uid}/{name}` in Firestore. The security rules only allow this
/// path for the signed-in owner.
class FirestoreCollection implements CloudCollection {
  FirestoreCollection(String uid, String name, {this.orderBy, this.limit})
      : _col = FirebaseFirestore.instance.collection('users').doc(uid).collection(name);

  final CollectionReference<Map<String, dynamic>> _col;
  final String? orderBy;
  final int? limit;

  @override
  Stream<List<Json>> watch() {
    Query<Map<String, dynamic>> q = _col;
    if (orderBy != null) q = q.orderBy(orderBy!, descending: true);
    if (limit != null) q = q.limit(limit!);
    return q.snapshots().map(
          (s) => [
            for (final d in s.docs) <String, Object?>{...d.data(), 'id': d.id},
          ],
        );
  }

  @override
  Future<void> put(String id, Json data) => _col.doc(id).set(Map<String, dynamic>.of(data));

  @override
  Future<void> remove(String id) => _col.doc(id).delete();

  @override
  Future<void> clearAll() async {
    // needs the internet; deletes in batches of 400
    while (true) {
      final snap = await _col.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}

/// Keeps everything in memory (for tests).
class MemoryCollection implements CloudCollection {
  final Map<String, Json> _rows = {};
  final StreamController<List<Json>> _controller = StreamController<List<Json>>.broadcast();

  List<Json> get _snapshot => [
        for (final e in _rows.entries) <String, Object?>{...e.value, 'id': e.key},
      ];

  /// Pretend another phone changed something.
  void externalPut(String id, Json data) {
    _rows[id] = data;
    _controller.add(_snapshot);
  }

  @override
  Stream<List<Json>> watch() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<void> put(String id, Json data) async {
    _rows[id] = Map<String, Object?>.of(data);
    _controller.add(_snapshot);
  }

  @override
  Future<void> remove(String id) async {
    _rows.remove(id);
    _controller.add(_snapshot);
  }

  @override
  Future<void> clearAll() async {
    _rows.clear();
    _controller.add(_snapshot);
  }
}
