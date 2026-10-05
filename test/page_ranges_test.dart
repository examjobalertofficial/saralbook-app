import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/files/page_ranges.dart';

void main() {
  test('single pages and ranges', () {
    expect(parsePageList('1-3, 5', 10), [1, 2, 3, 5]);
    expect(parsePageList('7-', 9), [7, 8, 9]);
    expect(parsePageList('-3', 9), [1, 2, 3]);
    expect(parsePageList('all', 4), [1, 2, 3, 4]);
    expect(parsePageList('  2 ; 4-5 ', 5), [2, 4, 5]);
  });

  test('groups keep each item separate (used for splitting)', () {
    expect(parsePageGroups('1-2, 3, 4-5', 5), [
      [1, 2],
      [3],
      [4, 5],
    ]);
  });

  test('invalid input returns null', () {
    for (final bad in ['', ' ', 'abc', '0', '11', '3-2', '1-2-3', '-', '1,,x', '5-11', '--2']) {
      expect(parsePageGroups(bad, 10), isNull, reason: '"$bad"');
    }
    expect(parsePageGroups('1', 0), isNull);
  });
}
