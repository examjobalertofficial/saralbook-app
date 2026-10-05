import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/calc_math.dart';

void main() {
  group('formatting', () {
    test('fmt trims zeros', () {
      expect(fmt(30), '30');
      expect(fmt(12.5), '12.5');
      expect(fmt(1 / 3), '0.33');
      expect(fmt(-0.001), '0');
      expect(fmt(double.infinity), '—');
    });

    test('fmtInr uses Indian grouping', () {
      expect(fmtInr(0), '₹0.00');
      expect(fmtInr(999.5), '₹999.50');
      expect(fmtInr(1000), '₹1,000.00');
      expect(fmtInr(123456), '₹1,23,456.00');
      expect(fmtInr(1234567.5), '₹12,34,567.50');
      expect(fmtInr(-50000), '-₹50,000.00');
    });
  });

  group('dates', () {
    test('ymdBetween borrows days and months correctly', () {
      expect(ymdBetween(DateTime(1995, 5, 15), DateTime(2026, 10, 2)), const YMD(31, 4, 17));
      expect(ymdBetween(DateTime(2000, 1, 31), DateTime(2000, 3, 1)), const YMD(0, 1, 1));
      expect(ymdBetween(DateTime(2020, 12, 25), DateTime(2021, 1, 5)), const YMD(0, 0, 11));
    });

    test('daysBetween ignores time of day and DST', () {
      expect(daysBetween(DateTime(1995, 5, 15), DateTime(2026, 10, 2)), 11463);
      expect(daysBetween(DateTime(2026, 3, 1, 23, 59), DateTime(2026, 3, 2, 0, 1)), 1);
    });

    test('subtractYears handles 29 Feb', () {
      expect(subtractYears(DateTime(2024, 2, 29), 1), DateTime(2023, 2, 28));
      expect(subtractYears(DateTime(2026, 1, 1), 32), DateTime(1994, 1, 1));
    });
  });

  group('expression evaluator', () {
    test('precedence, brackets, powers', () {
      expect(evaluateExpression('2+3*4'), 14);
      expect(evaluateExpression('(2+3)*4'), 20);
      expect(evaluateExpression('2^3^2'), 512);
      expect(evaluateExpression('10/4'), 2.5);
      expect(evaluateExpression('-3+5'), 2);
      expect(evaluateExpression('2(3+4)'), 14);
      expect(evaluateExpression('12×3÷4'), 9);
      expect(evaluateExpression(' 1,000 + 1 '), 1001);
    });

    test('invalid input gives null, never throws', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('10/0'), isNull);
      expect(evaluateExpression('2+'), isNull);
      expect(evaluateExpression('(2+3'), isNull);
      expect(evaluateExpression('abc'), isNull);
      expect(evaluateExpression('2^99999'), isNull);
      expect(evaluateExpression('(' * 100 + '1' + ')' * 100), isNull);
      expect(evaluateExpression('1+' * 200), isNull);
    });
  });

  test('gcd / lcm', () {
    expect(gcd(12, 18), 6);
    expect(gcd(0, 5), 5);
    expect(lcmBig(BigInt.from(4), BigInt.from(6)), BigInt.from(12));
  });
}
