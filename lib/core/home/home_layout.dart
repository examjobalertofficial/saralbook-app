import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/remote_config.dart';

/// The user's own Home choices: which sections are hidden and their order.
/// Saved on the phone (cloud sync for signed-in users comes with login).
class HomeLayoutController extends ChangeNotifier {
  HomeLayoutController._(this._prefs, this._hidden, this._order);

  static const String _kHidden = 'home.hidden';
  static const String _kOrder = 'home.order';

  final SharedPreferences _prefs;
  final Set<String> _hidden;
  List<String> _order;

  static HomeLayoutController load(SharedPreferences prefs) =>
      HomeLayoutController._(
        prefs,
        (prefs.getStringList(_kHidden) ?? const <String>[]).toSet(),
        List<String>.of(prefs.getStringList(_kOrder) ?? const <String>[]),
      );

  bool isHidden(String id) => _hidden.contains(id);

  List<String> get hiddenIds => _hidden.toList();
  List<String> get orderIds => List<String>.of(_order);

  /// Replaces the layout with the one saved in the cloud (single update).
  Future<void> applyRemote({required List<String> hidden, required List<String> order}) async {
    _hidden
      ..clear()
      ..addAll(hidden);
    _order = List<String>.of(order);
    notifyListeners();
    await _prefs.setStringList(_kHidden, _hidden.toList());
    await _prefs.setStringList(_kOrder, _order);
  }

  /// All sections in the user's order (hidden ones included).
  /// Sections the user never ordered keep the website's order, after the others.
  List<HomeSection> ordered(List<HomeSection> all) {
    final rank = <String, int>{
      for (var i = 0; i < _order.length; i++) _order[i]: i,
    };
    final indexed = <MapEntry<int, HomeSection>>[
      for (var i = 0; i < all.length; i++) MapEntry(i, all[i]),
    ];
    indexed.sort((a, b) {
      final ra = rank[a.value.id] ?? (1000 + a.key);
      final rb = rank[b.value.id] ?? (1000 + b.key);
      return ra.compareTo(rb);
    });
    return [for (final e in indexed) e.value];
  }

  List<HomeSection> visible(List<HomeSection> all) =>
      ordered(all).where((s) => !_hidden.contains(s.id)).toList();

  Future<void> setHidden(String id, bool hidden) async {
    final changed = hidden ? _hidden.add(id) : _hidden.remove(id);
    if (!changed) return;
    notifyListeners();
    await _prefs.setStringList(_kHidden, _hidden.toList());
  }

  Future<void> setOrder(List<String> ids) async {
    _order = List<String>.of(ids);
    notifyListeners();
    await _prefs.setStringList(_kOrder, _order);
  }

  Future<void> reset() async {
    _hidden.clear();
    _order = <String>[];
    notifyListeners();
    await _prefs.remove(_kHidden);
    await _prefs.remove(_kOrder);
  }
}
