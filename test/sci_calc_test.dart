import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/sci_calc.dart';

double _e(String s, {bool deg = true, double ans = 0}) => SciCalc.evaluate(s, degrees: deg, ans: ans);
String _f(String s, {bool deg = true}) => SciCalc.format(_e(s, deg: deg));

void main() {
  test('basic arithmetic and order of operations', () {
    expect(_e('2+3×4'), 14);
    expect(_e('(2+3)×4'), 20);
    expect(_e('10÷4'), 2.5);
    expect(_e('10-2-3'), 5);
    expect(_f('0.1+0.2'), '0.3');
  });

  test('powers go right to left and minus binds loosely', () {
    expect(_e('2^3^2'), 512);
    expect(_e('-2^2'), -4);
    expect(_e('2^-1'), 0.5);
    expect(_e('3^2'), 9);
  });

  test('trig in degrees and radians', () {
    expect(_f('sin(30)'), '0.5');
    expect(_f('cos(60)'), '0.5');
    expect(_f('tan(45)'), '1');
    expect(_f('sin(180)'), '0');
    expect(_f('asin(0.5)'), '30');
    expect(_f('sin(π/2)', deg: false), '1');
    expect(() => _e('tan(90)'), throwsA(isA<SciCalcException>()));
    expect(() => _e('asin(2)'), throwsA(isA<SciCalcException>()));
  });

  test('roots, logs, factorial, percent, abs', () {
    expect(_e('√(16)'), 4);
    expect(_e('sqrt(2)×sqrt(2)').toStringAsFixed(6), '2.000000');
    expect(_f('∛(27)'), '3');
    expect(_f('∛(-8)'), '-2');
    expect(_f('log(1000)'), '3');
    expect(_f('ln(e)'), '1');
    expect(_f('exp(0)'), '1');
    expect(_e('5!'), 120);
    expect(_e('0!'), 1);
    expect(_e('50%'), 0.5);
    expect(_e('200×10%'), 20);
    expect(_e('abs(-3)'), 3);
    expect(() => _e('(-1)!'), throwsA(isA<SciCalcException>()));
    expect(() => _e('2.5!'), throwsA(isA<SciCalcException>()));
    expect(() => _e('√(-4)'), throwsA(isA<SciCalcException>()));
    expect(() => _e('log(0)'), throwsA(isA<SciCalcException>()));
  });

  test('short multiplication, constants, answer and missing brackets', () {
    expect(_e('2π'), closeTo(6.283185307, 1e-8));
    expect(_e('2(3+1)'), 8);
    expect(_e('(2+3'), 5);
    expect(_e('Ans×2', ans: 21), 42);
    expect(_e('3×10^2'), 300);
  });

  test('bad input is an error, never a crash or hidden code', () {
    for (final bad in ['', '2+', '*3', ')', '2++', '1/0', 'foo(2)', '2@3', '1..2', 'alert(1)', 'sin']) {
      expect(() => _e(bad), throwsA(isA<SciCalcException>()), reason: bad);
    }
  });

  test('formatting', () {
    expect(SciCalc.format(5), '5');
    expect(SciCalc.format(-0.0), '0');
    expect(SciCalc.format(1 / 3), '0.333333333333');
    expect(SciCalc.format(1e20), '1E20');
    expect(SciCalc.format(1.5e-12), '1.5E-12');
    expect(SciCalc.format(123456789012), '123456789012');
  });
}
