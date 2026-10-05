import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final String payload;
  final DateTime savedAt;
  const CacheEntry(this.payload, this.savedAt);
}

/// Small size-limited cache for downloaded text (config, feeds).
/// Old entries are evicted automatically; callers decide how old is too old.
class CacheStore {
  CacheStore(this._prefs, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const String _prefix = 'cache.';
  static const String _indexKey = 'cache.__index';
  static const int maxEntries = 40;
  static const int maxPayloadChars = 200000;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  List<String> get _index =>
      List<String>.of(_prefs.getStringList(_indexKey) ?? const <String>[]);

  int get entryCount => _index.length;

  CacheEntry? read(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(
        map['d'] as String,
        DateTime.fromMillisecondsSinceEpoch(map['t'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the payload only if it is newer than [maxAge].
  String? get(String key, {required Duration maxAge}) {
    final entry = read(key);
    if (entry == null) return null;
    if (_now().difference(entry.savedAt) > maxAge) return null;
    return entry.payload;
  }

  Future<void> put(String key, String payload) async {
    if (payload.length > maxPayloadChars) return;
    final index = _index..remove(key);
    index.add(key);
    while (index.length > maxEntries) {
      final oldest = index.removeAt(0);
      await _prefs.remove('$_prefix$oldest');
    }
    await _prefs.setString(
      '$_prefix$key',
      jsonEncode({'t': _now().millisecondsSinceEpoch, 'd': payload}),
    );
    await _prefs.setStringList(_indexKey, index);
  }

  Future<void> remove(String key) async {
    final index = _index..remove(key);
    await _prefs.remove('$_prefix$key');
    await _prefs.setStringList(_indexKey, index);
  }

  Future<void> clear() async {
    for (final key in _index) {
      await _prefs.remove('$_prefix$key');
    }
    await _prefs.remove(_indexKey);
  }
}
