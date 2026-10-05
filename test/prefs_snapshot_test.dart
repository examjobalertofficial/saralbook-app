import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/auth/prefs_snapshot.dart';
import 'package:app/core/config/remote_config.dart';
import 'package:app/core/home/home_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trip', () {
    const s = PrefsSnapshot(
      themeMode: ThemeMode.dark,
      language: 'hi',
      hiddenSections: ['recent'],
      sectionOrder: ['platforms', 'latest_jobs'],
    );
    final back = PrefsSnapshot.fromMap(s.toMap())!;
    expect(back.themeMode, ThemeMode.dark);
    expect(back.language, 'hi');
    expect(back.hiddenSections, ['recent']);
    expect(back.sectionOrder, ['platforms', 'latest_jobs']);
  });

  test('damaged or missing cloud data is ignored, never throws', () {
    expect(PrefsSnapshot.fromMap(null), isNull);
    expect(PrefsSnapshot.fromMap('text'), isNull);
    expect(PrefsSnapshot.fromMap({'themeMode': 'purple', 'language': 'en'}), isNull);
    expect(PrefsSnapshot.fromMap({'themeMode': 'dark', 'language': 'xx'}), isNull);
  });

  test('lists are cleaned and limited', () {
    final s = PrefsSnapshot.fromMap({
      'themeMode': 'light',
      'language': 'en',
      'homeHidden': ['ok', 5, null, 'x' * 100],
      'homeOrder': [for (var i = 0; i < 100; i++) 's$i'],
    })!;
    expect(s.hiddenSections, ['ok']);
    expect(s.sectionOrder.length, 40);
  });

  test('HomeLayoutController.applyRemote replaces the layout in one step', () async {
    SharedPreferences.setMockInitialValues({});
    final l = HomeLayoutController.load(await SharedPreferences.getInstance());
    var notifications = 0;
    l.addListener(() => notifications++);
    await l.applyRemote(hidden: ['b'], order: ['c', 'a', 'b']);
    expect(notifications, 1);
    const all = [
      HomeSection(id: 'a', type: 'recent'),
      HomeSection(id: 'b', type: 'recent'),
      HomeSection(id: 'c', type: 'recent'),
    ];
    expect(l.visible(all).map((e) => e.id).toList(), ['c', 'a']);
    expect(l.hiddenIds, ['b']);
    expect(l.orderIds, ['c', 'a', 'b']);
  });
}
