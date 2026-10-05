import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentItem {
  final String title;
  final String url;
  const RecentItem(this.title, this.url);
}

/// The last pages the user opened (for the "Recently Viewed" section).
class RecentsController extends ChangeNotifier {
  RecentsController._(this._prefs, this._items);

  static const String _key = 'home.recents';
  static const int maxItems = 10;

  final SharedPreferences _prefs;
  final List<RecentItem> _items;

  List<RecentItem> get items => List.unmodifiable(_items);

  static RecentsController load(SharedPreferences prefs) {
    final items = <RecentItem>[];
    for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        items.add(RecentItem(m['t'] as String, m['u'] as String));
      } catch (_) {/* skip damaged row */}
    }
    return RecentsController._(prefs, items);
  }

  Future<void> add(String title, String url) async {
    _items.removeWhere((e) => e.url == url);
    _items.insert(0, RecentItem(title, url));
    if (_items.length > maxItems) _items.removeRange(maxItems, _items.length);
    notifyListeners();
    await _prefs.setStringList(
      _key,
      [for (final e in _items) jsonEncode({'t': e.title, 'u': e.url})],
    );
  }
}
