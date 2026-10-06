import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cloud_collection.dart';
import 'models.dart';

/// A live list of one kind of record (notes, to-dos, ...) for the signed-in
/// person. UI listens to it; it updates instantly, also offline.
class CollectionController<T> extends ChangeNotifier {
  CollectionController({
    required CloudCollection collection,
    required T? Function(Json) fromMap,
    required Json Function(T) toMap,
    required String Function(T) idOf,
  })  : _collection = collection,
        _fromMap = fromMap,
        _toMap = toMap,
        _idOf = idOf;

  final CloudCollection _collection;
  final T? Function(Json) _fromMap;
  final Json Function(T) _toMap;
  final String Function(T) _idOf;

  StreamSubscription<List<Json>>? _sub;
  List<T> _items = const [];
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;

  List<T> get items => _items;

  /// false until the first list arrived (show a loading state).
  bool get loaded => _loaded;

  /// true if reading or saving failed (e.g. rules not published yet).
  bool get hasError => _hasError;

  CloudCollection get collection => _collection;

  void start() {
    _sub ??= _collection.watch().listen(
      (rows) {
        _items = [
          for (final r in rows)
            if (_fromMap(r) case final T item) item,
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

  T? byId(String id) {
    for (final i in _items) {
      if (_idOf(i) == id) return i;
    }
    return null;
  }

  /// Saves without waiting for the server (so the screen never freezes offline).
  void upsert(T item) {
    unawaited(_collection.put(_idOf(item), _toMap(item)).catchError(_onWriteError));
  }

  void remove(String id) {
    unawaited(_collection.remove(id).catchError(_onWriteError));
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
