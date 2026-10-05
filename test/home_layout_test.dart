import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/config/remote_config.dart';
import 'package:app/core/home/home_layout.dart';

const _all = [
  HomeSection(id: 'a', type: 'platforms'),
  HomeSection(id: 'b', type: 'recent'),
  HomeSection(id: 'c', type: 'recent'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HomeLayoutController> make() async {
    SharedPreferences.setMockInitialValues({});
    return HomeLayoutController.load(await SharedPreferences.getInstance());
  }

  test('default order follows the website; nothing hidden', () async {
    final l = await make();
    expect(l.visible(_all).map((s) => s.id).toList(), ['a', 'b', 'c']);
  });

  test('hide and reorder are applied and survive a reload', () async {
    final l = await make();
    await l.setHidden('b', true);
    await l.setOrder(['c', 'b', 'a']);
    expect(l.visible(_all).map((s) => s.id).toList(), ['c', 'a']);

    final reloaded =
        HomeLayoutController.load(await SharedPreferences.getInstance());
    expect(reloaded.visible(_all).map((s) => s.id).toList(), ['c', 'a']);
  });

  test('a new section added later appears after the ordered ones', () async {
    final l = await make();
    await l.setOrder(['c', 'a']);
    expect(l.ordered(_all).map((s) => s.id).toList(), ['c', 'a', 'b']);
  });

  test('reset restores defaults', () async {
    final l = await make();
    await l.setHidden('a', true);
    await l.setOrder(['c', 'b', 'a']);
    await l.reset();
    expect(l.visible(_all).map((s) => s.id).toList(), ['a', 'b', 'c']);
  });
}
