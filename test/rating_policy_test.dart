import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/rating/rating_policy.dart';

void main() {
  RatingState used(int opens, int days) {
    var s = const RatingState();
    final start = DateTime(2026, 11, 1);
    for (var i = 0; i < opens; i++) {
      s = s.opened(start.add(Duration(days: i % days)));
    }
    return s;
  }

  final now = DateTime(2026, 12, 1);

  test('not asked at the beginning', () {
    expect(const RatingState().shouldAsk(now), isFalse);
    expect(used(3, 3).shouldAsk(now), isFalse);
  });

  test('needs enough starts and enough different days', () {
    expect(used(20, 2).shouldAsk(now), isFalse); // many starts, only 2 days
    expect(used(8, 4).shouldAsk(now), isTrue);
  });

  test('asked at most twice, 45 days apart', () {
    var s = used(10, 5).wasAsked(now);
    expect(s.shouldAsk(now.add(const Duration(days: 10))), isFalse);
    expect(s.shouldAsk(now.add(const Duration(days: 46))), isTrue);
    s = s.wasAsked(now.add(const Duration(days: 46)));
    expect(s.shouldAsk(now.add(const Duration(days: 200))), isFalse);
  });

  test('saved state survives, bad data gives a fresh state', () {
    final s = used(9, 5).wasAsked(now);
    final back = RatingState.decode(s.encode());
    expect(back.opens, s.opens);
    expect(back.asked, 1);
    expect(RatingState.decode('oops').opens, 0);
    expect(RatingState.decode(null).opens, 0);
  });
}
