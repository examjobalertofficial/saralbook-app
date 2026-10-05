import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/ltext.dart';
import 'calc_math.dart';
import 'calc_model.dart';

// ---- small helpers to keep the definitions short ----
ShowIf _on(String field, List<String> values) => ShowIf(field, values);
CalcChoice _ch(String id, String en, String hi) => CalcChoice(id, t(en, hi));
ResultLine _r(String en, String hi, String value, {bool big = false}) =>
    ResultLine(t(en, hi), value, highlight: big);
CalcOutput _ok(List<ResultLine> lines, {List<LText> notes = const []}) =>
    CalcOutput.ok(lines, notes: notes);
CalcOutput _err(String en, String hi) => CalcOutput.error(t(en, hi));

final CalcOutput _divZero = _err('Value cannot be zero here.', 'यहां मान शून्य नहीं हो सकता।');
final CalcOutput _positive = _err('Please enter values greater than zero.', 'कृपया शून्य से बड़े मान दर्ज करें।');

/// Result row whose value has words in both languages.
ResultLine _rl(String enL, String hiL, String enV, String hiV, {bool big = false}) =>
    ResultLine(t(enL, hiL), enV, highlight: big, valueText: t(enV, hiV));

ResultLine _ymdLine(String enL, String hiL, YMD x, {bool big = false}) => _rl(
      enL,
      hiL,
      '${x.years} years ${x.months} months ${x.days} days',
      '${x.years} वर्ष ${x.months} माह ${x.days} दिन',
      big: big,
    );

// ============================ EXAM CALCULATORS ============================

final _percentage = CalcTool(
  id: 'percentage',
  title: t('Percentage', 'प्रतिशत'),
  description: t('Percent of a value, what percent, % change', 'किसी मान का प्रतिशत, कितना प्रतिशत, % बदलाव'),
  icon: Icons.percent_rounded,
  category: ToolCategory.examCalc,
  keywords: ['percent', '%', 'increase', 'decrease'],
  fields: [
    CalcField.choice('mode', t('Calculate', 'क्या निकालें'), [
      _ch('of', 'X% of Y', 'Y का X%'),
      _ch('what', 'X is what % of Y', 'X, Y का कितना %'),
      _ch('change', '% change X to Y', 'X से Y तक % बदलाव'),
    ]),
    CalcField.number('pct', t('Percent (X)', 'प्रतिशत (X)'), showIf: _on('mode', ['of'])),
    CalcField.number('base', t('Value (Y)', 'मान (Y)'), showIf: _on('mode', ['of'])),
    CalcField.number('part', t('Value (X)', 'मान (X)'), showIf: _on('mode', ['what'])),
    CalcField.number('whole', t('Value (Y)', 'मान (Y)'), showIf: _on('mode', ['what'])),
    CalcField.number('from', t('From (X)', 'से (X)'), showIf: _on('mode', ['change'])),
    CalcField.number('to', t('To (Y)', 'तक (Y)'), showIf: _on('mode', ['change'])),
  ],
  compute: (v) {
    switch (v.choice('mode')) {
      case 'what':
        final w = v.number('whole')!;
        if (w == 0) return _divZero;
        return _ok([_r('Percentage', 'प्रतिशत', '${fmt(v.number('part')! / w * 100, maxDecimals: 4)}%', big: true)]);
      case 'change':
        final f = v.number('from')!;
        if (f == 0) return _divZero;
        final c = (v.number('to')! - f) / f * 100;
        return _ok([
          _r(c >= 0 ? 'Increase' : 'Decrease', c >= 0 ? 'वृद्धि' : 'कमी', '${fmt(c.abs(), maxDecimals: 4)}%', big: true),
        ]);
      default:
        return _ok([_r('Result', 'परिणाम', fmt(v.number('pct')! * v.number('base')! / 100, maxDecimals: 4), big: true)]);
    }
  },
);

final _average = CalcTool(
  id: 'average',
  title: t('Average', 'औसत'),
  description: t('Mean, sum, smallest and largest of numbers', 'संख्याओं का औसत, योग, न्यूनतम और अधिकतम'),
  icon: Icons.functions_rounded,
  category: ToolCategory.examCalc,
  keywords: ['mean', 'sum'],
  fields: [
    CalcField.list('nums', t('Numbers (separate with comma or space)', 'संख्याएं (कॉमा या स्पेस से अलग करें)')),
  ],
  compute: (v) {
    final l = v.list('nums');
    final sum = l.fold<double>(0, (a, b) => a + b);
    return _ok([
      _r('Average', 'औसत', fmt(sum / l.length, maxDecimals: 4), big: true),
      _r('Count', 'गिनती', '${l.length}'),
      _r('Sum', 'योग', fmt(sum, maxDecimals: 4)),
      _r('Smallest', 'न्यूनतम', fmt(l.reduce(math.min), maxDecimals: 4)),
      _r('Largest', 'अधिकतम', fmt(l.reduce(math.max), maxDecimals: 4)),
    ]);
  },
);

final _ratio = CalcTool(
  id: 'ratio',
  title: t('Ratio & Proportion', 'अनुपात और समानुपात'),
  description: t('Simplify A:B and solve A:B = C:X', 'A:B सरल करें और A:B = C:X हल करें'),
  icon: Icons.compare_arrows_rounded,
  category: ToolCategory.examCalc,
  keywords: ['ratio', 'proportion'],
  fields: [
    CalcField.number('a', t('A', 'A')),
    CalcField.number('b', t('B', 'B')),
    CalcField.number('c', t('C (optional)', 'C (वैकल्पिक)'), optional: true),
  ],
  compute: (v) {
    final a = v.number('a')!;
    final b = v.number('b')!;
    if (a == 0) return _divZero;
    final lines = <ResultLine>[];
    if (a == a.roundToDouble() && b == b.roundToDouble()) {
      final g = gcd(a.toInt(), b.toInt());
      if (g > 0) {
        lines.add(_r('Simplest ratio', 'सरलतम अनुपात', '${a ~/ g} : ${b ~/ g}', big: true));
      }
    }
    final c = v.number('c');
    if (c != null) {
      lines.add(_r('X in A : B = C : X', 'A : B = C : X में X', fmt(b * c / a, maxDecimals: 4), big: true));
    }
    lines.add(_r('A ÷ B', 'A ÷ B', b == 0 ? '—' : fmt(a / b, maxDecimals: 4)));
    return _ok(lines);
  },
);

final _profitLoss = CalcTool(
  id: 'profit_loss',
  title: t('Profit & Loss', 'लाभ और हानि'),
  description: t('Profit/loss %, selling price or cost price', 'लाभ/हानि %, विक्रय मूल्य या क्रय मूल्य'),
  icon: Icons.trending_up_rounded,
  category: ToolCategory.examCalc,
  keywords: ['profit', 'loss', 'cost price', 'selling price', 'cp', 'sp'],
  fields: [
    CalcField.choice('mode', t('I know', 'मुझे पता है'), [
      _ch('amounts', 'Cost & selling price', 'क्रय व विक्रय मूल्य'),
      _ch('cp_pct', 'Cost price & profit %', 'क्रय मूल्य व लाभ %'),
      _ch('sp_pct', 'Selling price & profit %', 'विक्रय मूल्य व लाभ %'),
    ]),
    CalcField.number('cp', t('Cost price', 'क्रय मूल्य'), showIf: _on('mode', ['amounts', 'cp_pct'])),
    CalcField.number('sp', t('Selling price', 'विक्रय मूल्य'), showIf: _on('mode', ['amounts', 'sp_pct'])),
    CalcField.number('pct', t('Profit % (use minus for loss)', 'लाभ % (हानि के लिए माइनस)'), showIf: _on('mode', ['cp_pct', 'sp_pct'])),
  ],
  compute: (v) {
    switch (v.choice('mode')) {
      case 'cp_pct':
        final sp = v.number('cp')! * (100 + v.number('pct')!) / 100;
        return _ok([_r('Selling price', 'विक्रय मूल्य', fmt(sp, maxDecimals: 4), big: true)]);
      case 'sp_pct':
        final d = 100 + v.number('pct')!;
        if (d == 0) return _divZero;
        return _ok([_r('Cost price', 'क्रय मूल्य', fmt(v.number('sp')! * 100 / d, maxDecimals: 4), big: true)]);
      default:
        final cp = v.number('cp')!;
        if (cp == 0) return _divZero;
        final diff = v.number('sp')! - cp;
        final pct = diff / cp * 100;
        final profit = diff >= 0;
        return _ok([
          _r(profit ? 'Profit' : 'Loss', profit ? 'लाभ' : 'हानि', fmt(diff.abs(), maxDecimals: 4), big: true),
          _r(profit ? 'Profit %' : 'Loss %', profit ? 'लाभ %' : 'हानि %', '${fmt(pct.abs(), maxDecimals: 4)}%', big: true),
        ]);
    }
  },
);

final _simpleInterest = CalcTool(
  id: 'simple_interest',
  title: t('Simple Interest', 'साधारण ब्याज'),
  description: t('Interest and total amount', 'ब्याज और कुल राशि'),
  icon: Icons.savings_outlined,
  category: ToolCategory.examCalc,
  keywords: ['si', 'interest'],
  fields: [
    CalcField.number('p', t('Principal', 'मूलधन'), suffix: t('₹', '₹')),
    CalcField.number('r', t('Rate per year', 'वार्षिक दर'), suffix: t('%', '%')),
    CalcField.number('t', t('Time', 'समय'), suffix: t('years', 'वर्ष')),
  ],
  compute: (v) {
    final p = v.number('p')!;
    final si = p * v.number('r')! * v.number('t')! / 100;
    return _ok([
      _r('Simple interest', 'साधारण ब्याज', fmtInr(si), big: true),
      _r('Total amount', 'कुल राशि', fmtInr(p + si)),
    ]);
  },
);

final _compoundInterest = CalcTool(
  id: 'compound_interest',
  title: t('Compound Interest', 'चक्रवृद्धि ब्याज'),
  description: t('Compound interest and maturity amount', 'चक्रवृद्धि ब्याज और परिपक्वता राशि'),
  icon: Icons.stacked_line_chart_rounded,
  category: ToolCategory.examCalc,
  keywords: ['ci', 'interest', 'compound'],
  fields: [
    CalcField.number('p', t('Principal', 'मूलधन'), suffix: t('₹', '₹')),
    CalcField.number('r', t('Rate per year', 'वार्षिक दर'), suffix: t('%', '%')),
    CalcField.number('t', t('Time', 'समय'), suffix: t('years', 'वर्ष')),
    CalcField.choice('n', t('Compounded', 'चक्रवृद्धि'), [
      _ch('1', 'Yearly', 'वार्षिक'),
      _ch('2', 'Half-yearly', 'अर्धवार्षिक'),
      _ch('4', 'Quarterly', 'त्रैमासिक'),
      _ch('12', 'Monthly', 'मासिक'),
    ]),
  ],
  compute: (v) {
    final p = v.number('p')!;
    final n = int.parse(v.choice('n'));
    final amount = p * math.pow(1 + v.number('r')! / (100 * n), n * v.number('t')!).toDouble();
    return _ok([
      _r('Compound interest', 'चक्रवृद्धि ब्याज', fmtInr(amount - p), big: true),
      _r('Total amount', 'कुल राशि', fmtInr(amount)),
    ]);
  },
);

final _timeWork = CalcTool(
  id: 'time_work',
  title: t('Time & Work', 'समय और कार्य'),
  description: t('Days taken when people work together', 'साथ काम करने पर लगने वाले दिन'),
  icon: Icons.groups_2_outlined,
  category: ToolCategory.examCalc,
  keywords: ['work', 'days', 'together'],
  fields: [
    CalcField.number('a', t('A alone takes (days)', 'A अकेला लेता है (दिन)')),
    CalcField.number('b', t('B alone takes (days)', 'B अकेला लेता है (दिन)')),
    CalcField.number('c', t('C alone takes (days, optional)', 'C अकेला लेता है (दिन, वैकल्पिक)'), optional: true),
  ],
  compute: (v) {
    final days = [v.number('a')!, v.number('b')!, if (v.number('c') != null) v.number('c')!];
    if (days.any((d) => d <= 0)) return _positive;
    final rate = days.fold<double>(0, (s, d) => s + 1 / d);
    final together = 1 / rate;
    return _ok([
      _rl('Working together', 'साथ मिलकर', '${fmt(together, maxDecimals: 3)} days', '${fmt(together, maxDecimals: 3)} दिन', big: true),
      _r('Work done per day', 'प्रतिदिन कार्य', '${fmt(rate * 100, maxDecimals: 2)}%'),
    ]);
  },
);

final _speedDistance = CalcTool(
  id: 'speed_distance_time',
  title: t('Speed, Distance, Time', 'चाल, दूरी, समय'),
  description: t('Find speed, distance or time', 'चाल, दूरी या समय निकालें'),
  icon: Icons.speed_rounded,
  category: ToolCategory.examCalc,
  keywords: ['speed', 'distance', 'time', 'tsd'],
  fields: [
    CalcField.choice('solve', t('Find', 'निकालें'), [
      _ch('speed', 'Speed', 'चाल'),
      _ch('distance', 'Distance', 'दूरी'),
      _ch('time', 'Time', 'समय'),
    ]),
    CalcField.number('speed', t('Speed', 'चाल'), suffix: t('km/h', 'किमी/घंटा'), showIf: _on('solve', ['distance', 'time'])),
    CalcField.number('distance', t('Distance', 'दूरी'), suffix: t('km', 'किमी'), showIf: _on('solve', ['speed', 'time'])),
    CalcField.number('time', t('Time', 'समय'), suffix: t('hours', 'घंटे'), showIf: _on('solve', ['speed', 'distance'])),
  ],
  compute: (v) {
    switch (v.choice('solve')) {
      case 'distance':
        return _ok([_r('Distance', 'दूरी', '${fmt(v.number('speed')! * v.number('time')!, maxDecimals: 3)} km', big: true)]);
      case 'time':
        final s = v.number('speed')!;
        if (s == 0) return _divZero;
        final h = v.number('distance')! / s;
        final totalMin = (h * 60).round();
        return _ok([
          _r('Time', 'समय', '${fmt(h, maxDecimals: 3)} h', big: true),
          _rl('In hours & minutes', 'घंटे और मिनट में', '${totalMin ~/ 60} h ${totalMin % 60} min', '${totalMin ~/ 60} घंटे ${totalMin % 60} मिनट'),
        ]);
      default:
        final tm = v.number('time')!;
        if (tm == 0) return _divZero;
        final s = v.number('distance')! / tm;
        return _ok([
          _r('Speed', 'चाल', '${fmt(s, maxDecimals: 3)} km/h', big: true),
          _r('In metres/second', 'मीटर/सेकंड में', '${fmt(s * 5 / 18, maxDecimals: 3)} m/s'),
        ]);
    }
  },
);

final _hcfLcm = CalcTool(
  id: 'hcf_lcm',
  title: t('HCF & LCM', 'HCF और LCM'),
  description: t('Highest common factor and least common multiple', 'महत्तम समापवर्तक और लघुत्तम समापवर्त्य'),
  icon: Icons.numbers_rounded,
  category: ToolCategory.examCalc,
  keywords: ['hcf', 'gcd', 'lcm'],
  fields: [
    CalcField.list('nums', t('Whole numbers (comma or space)', 'पूर्ण संख्याएं (कॉमा या स्पेस)'), integer: true),
  ],
  compute: (v) {
    final l = v.list('nums');
    if (l.length > 20 || l.any((e) => e < 1 || e > 1e12)) {
      return _err('Enter up to 20 whole numbers between 1 and 1,000,000,000,000.', '1 से 1,000,000,000,000 के बीच अधिकतम 20 पूर्ण संख्याएं दर्ज करें।');
    }
    final ints = l.map((e) => e.toInt()).toList();
    final h = ints.reduce(gcd);
    final lcm = ints.map(BigInt.from).reduce(lcmBig);
    return _ok([
      _r('HCF', 'HCF', '$h', big: true),
      _r('LCM', 'LCM', lcm.toString(), big: true),
    ]);
  },
);

final _fraction = CalcTool(
  id: 'fraction',
  title: t('Fraction', 'भिन्न'),
  description: t('Add, subtract, multiply, divide fractions', 'भिन्नों का जोड़, घटाव, गुणा, भाग'),
  icon: Icons.pie_chart_outline_rounded,
  category: ToolCategory.examCalc,
  keywords: ['fraction', 'mixed'],
  fields: [
    CalcField.number('n1', t('Numerator 1', 'अंश 1'), integer: true),
    CalcField.number('d1', t('Denominator 1', 'हर 1'), integer: true),
    CalcField.choice('op', t('Operation', 'क्रिया'), [
      _ch('+', '+', '+'),
      _ch('-', '−', '−'),
      _ch('*', '×', '×'),
      _ch('/', '÷', '÷'),
    ]),
    CalcField.number('n2', t('Numerator 2', 'अंश 2'), integer: true),
    CalcField.number('d2', t('Denominator 2', 'हर 2'), integer: true),
  ],
  compute: (v) {
    final n1 = v.integer('n1')!, d1 = v.integer('d1')!;
    final n2 = v.integer('n2')!, d2 = v.integer('d2')!;
    if (d1 == 0 || d2 == 0) return _divZero;
    int n, d;
    switch (v.choice('op')) {
      case '-':
        n = n1 * d2 - n2 * d1;
        d = d1 * d2;
      case '*':
        n = n1 * n2;
        d = d1 * d2;
      case '/':
        if (n2 == 0) return _divZero;
        n = n1 * d2;
        d = d1 * n2;
      default:
        n = n1 * d2 + n2 * d1;
        d = d1 * d2;
    }
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = gcd(n, d);
    if (g > 1) {
      n ~/= g;
      d ~/= g;
    }
    final lines = <ResultLine>[
      _r('Fraction', 'भिन्न', d == 1 ? '$n' : '$n/$d', big: true),
      _r('Decimal', 'दशमलव', fmt(n / d, maxDecimals: 6)),
    ];
    if (d != 1 && n.abs() > d) {
      final whole = n.abs() ~/ d;
      final rem = n.abs() % d;
      lines.add(_r('Mixed number', 'मिश्रित भिन्न', '${n < 0 ? '-' : ''}$whole $rem/$d'));
    }
    return _ok(lines);
  },
);

final _simplification = CalcTool(
  id: 'simplification',
  title: t('Simplification', 'सरलीकरण'),
  description: t('Solve expressions with brackets, × ÷ + − and powers', 'ब्रैकेट, × ÷ + − और घात वाले व्यंजक हल करें'),
  icon: Icons.calculate_outlined,
  category: ToolCategory.examCalc,
  keywords: ['bodmas', 'expression', 'calculator'],
  fields: [
    CalcField.text('expr', t('Expression, e.g. (12+8)×3÷4', 'व्यंजक, जैसे (12+8)×3÷4')),
  ],
  compute: (v) {
    final r = evaluateExpression(v.text('expr'));
    if (r == null) {
      return _err('This expression is not valid.', 'यह व्यंजक मान्य नहीं है।');
    }
    return _ok([_r('Answer', 'उत्तर', fmt(r, maxDecimals: 6), big: true)]);
  },
);

final _marksPercentage = CalcTool(
  id: 'marks_percentage',
  title: t('Marks Percentage', 'अंक प्रतिशत'),
  description: t('Percentage from marks obtained', 'प्राप्तांकों से प्रतिशत'),
  icon: Icons.grade_outlined,
  category: ToolCategory.examCalc,
  keywords: ['marks', 'percentage', 'result'],
  fields: [
    CalcField.number('got', t('Marks obtained', 'प्राप्त अंक')),
    CalcField.number('total', t('Total marks', 'कुल अंक')),
  ],
  compute: (v) {
    final total = v.number('total')!;
    if (total <= 0) return _positive;
    final got = v.number('got')!;
    if (got > total) return _err('Marks obtained cannot be more than total marks.', 'प्राप्त अंक कुल अंकों से अधिक नहीं हो सकते।');
    return _ok([_r('Percentage', 'प्रतिशत', '${fmt(got / total * 100, maxDecimals: 3)}%', big: true)]);
  },
);

final _cgpa = CalcTool(
  id: 'cgpa',
  title: t('CGPA ↔ Percentage', 'CGPA ↔ प्रतिशत'),
  description: t('Convert CGPA to percentage and back', 'CGPA को प्रतिशत में और वापस बदलें'),
  icon: Icons.school_outlined,
  category: ToolCategory.examCalc,
  keywords: ['cgpa', 'gpa', 'percentage', 'cbse'],
  note: t('CBSE uses a multiplier of 9.5. Other boards/universities may differ — check yours.', 'CBSE में गुणक 9.5 है। अन्य बोर्ड/विश्वविद्यालय अलग हो सकते हैं — अपना जांचें।'),
  fields: [
    CalcField.choice('mode', t('Convert', 'बदलें'), [
      _ch('c2p', 'CGPA → %', 'CGPA → %'),
      _ch('p2c', '% → CGPA', '% → CGPA'),
    ]),
    CalcField.number('mult', t('Multiplier', 'गुणक'), defaultValue: '9.5'),
    CalcField.number('cgpa', t('CGPA', 'CGPA'), showIf: _on('mode', ['c2p'])),
    CalcField.number('pct', t('Percentage', 'प्रतिशत'), showIf: _on('mode', ['p2c'])),
  ],
  compute: (v) {
    final m = v.number('mult')!;
    if (m <= 0) return _positive;
    if (v.choice('mode') == 'p2c') {
      return _ok([_r('CGPA', 'CGPA', fmt(v.number('pct')! / m, maxDecimals: 3), big: true)]);
    }
    return _ok([_r('Percentage', 'प्रतिशत', '${fmt(v.number('cgpa')! * m, maxDecimals: 2)}%', big: true)]);
  },
);

final _examScore = CalcTool(
  id: 'exam_score',
  title: t('Exam Score & Negative Marking', 'परीक्षा स्कोर और निगेटिव मार्किंग'),
  description: t('Net score after negative marking', 'निगेटिव मार्किंग के बाद नेट स्कोर'),
  icon: Icons.fact_check_outlined,
  category: ToolCategory.examCalc,
  keywords: ['score', 'negative marking', 'mock test', 'accuracy'],
  fields: [
    CalcField.number('total', t('Total questions', 'कुल प्रश्न'), integer: true),
    CalcField.number('correct', t('Correct answers', 'सही उत्तर'), integer: true),
    CalcField.number('wrong', t('Wrong answers', 'गलत उत्तर'), integer: true),
    CalcField.number('mc', t('Marks per correct', 'प्रति सही अंक'), defaultValue: '1'),
    CalcField.number('mw', t('Negative per wrong', 'प्रति गलत कटौती'), defaultValue: '0.25'),
  ],
  compute: (v) {
    final total = v.integer('total')!, c = v.integer('correct')!, w = v.integer('wrong')!;
    if (total <= 0 || c < 0 || w < 0 || c + w > total) {
      return _err('Correct + wrong cannot be more than total questions.', 'सही + गलत कुल प्रश्नों से अधिक नहीं हो सकते।');
    }
    final mc = v.number('mc')!, mw = v.number('mw')!;
    final score = c * mc - w * mw;
    final max = total * mc;
    return _ok([
      _r('Net score', 'नेट स्कोर', '${fmt(score, maxDecimals: 3)} / ${fmt(max, maxDecimals: 3)}', big: true),
      _r('Score %', 'स्कोर %', max == 0 ? '—' : '${fmt(score / max * 100, maxDecimals: 2)}%'),
      _r('Accuracy', 'सटीकता', (c + w) == 0 ? '—' : '${fmt(c / (c + w) * 100, maxDecimals: 2)}%'),
      _r('Not attempted', 'अनुत्तरित', '${total - c - w}'),
    ]);
  },
);

final _rankPercentile = CalcTool(
  id: 'rank_percentile',
  title: t('Rank & Percentile', 'रैंक और पर्सेंटाइल'),
  description: t('Percentile from rank, or estimated rank', 'रैंक से पर्सेंटाइल, या अनुमानित रैंक'),
  icon: Icons.leaderboard_outlined,
  category: ToolCategory.examCalc,
  keywords: ['rank', 'percentile'],
  note: t('Formula used: Percentile = (Total − Rank) ÷ Total × 100. Some exams use a slightly different method.', 'सूत्र: पर्सेंटाइल = (कुल − रैंक) ÷ कुल × 100। कुछ परीक्षाएं थोड़ा अलग तरीका अपनाती हैं।'),
  fields: [
    CalcField.choice('mode', t('Find', 'निकालें'), [
      _ch('p', 'Percentile', 'पर्सेंटाइल'),
      _ch('r', 'Rank', 'रैंक'),
    ]),
    CalcField.number('total', t('Total candidates', 'कुल परीक्षार्थी'), integer: true),
    CalcField.number('rank', t('Your rank', 'आपकी रैंक'), integer: true, showIf: _on('mode', ['p'])),
    CalcField.number('pct', t('Percentile', 'पर्सेंटाइल'), showIf: _on('mode', ['r'])),
  ],
  compute: (v) {
    final total = v.integer('total')!;
    if (total <= 0) return _positive;
    if (v.choice('mode') == 'r') {
      final p = v.number('pct')!;
      if (p < 0 || p > 100) return _err('Percentile must be between 0 and 100.', 'पर्सेंटाइल 0 से 100 के बीच होना चाहिए।');
      return _ok([_r('Approximate rank', 'अनुमानित रैंक', '${math.max(1, ((100 - p) / 100 * total).round())}', big: true)]);
    }
    final rank = v.integer('rank')!;
    if (rank < 1 || rank > total) return _err('Rank must be between 1 and total candidates.', 'रैंक 1 से कुल परीक्षार्थियों के बीच होनी चाहिए।');
    return _ok([_r('Percentile', 'पर्सेंटाइल', fmt((total - rank) / total * 100, maxDecimals: 3), big: true)]);
  },
);

final _studyTime = CalcTool(
  id: 'study_time',
  title: t('Study Time Planner', 'अध्ययन समय योजना'),
  description: t('Total study hours until your exam', 'परीक्षा तक कुल अध्ययन घंटे'),
  icon: Icons.timer_outlined,
  category: ToolCategory.examCalc,
  keywords: ['study', 'hours', 'countdown', 'exam date'],
  fields: [
    CalcField.date('exam', t('Exam date', 'परीक्षा की तारीख')),
    CalcField.number('hours', t('Study hours per day', 'प्रतिदिन अध्ययन घंटे')),
    CalcField.number('subjects', t('Number of subjects (optional)', 'विषयों की संख्या (वैकल्पिक)'), integer: true, optional: true),
  ],
  compute: (v) {
    final days = daysBetween(DateTime.now(), v.date('exam')!);
    if (days < 0) return _err('The exam date is in the past.', 'परीक्षा की तारीख बीत चुकी है।');
    final h = v.number('hours')!;
    if (h <= 0 || h > 24) return _err('Study hours must be between 0 and 24.', 'अध्ययन घंटे 0 से 24 के बीच होने चाहिए।');
    final total = days * h;
    final lines = <ResultLine>[
      _r('Days left', 'बचे दिन', '$days', big: true),
      _r('Total study hours', 'कुल अध्ययन घंटे', fmt(total, maxDecimals: 1), big: true),
    ];
    final s = v.integer('subjects');
    if (s != null && s > 0) {
      lines.add(_r('Hours per subject', 'प्रति विषय घंटे', fmt(total / s, maxDecimals: 1)));
    }
    return _ok(lines);
  },
);

final _emi = CalcTool(
  id: 'emi',
  title: t('EMI Calculator', 'EMI कैलकुलेटर'),
  description: t('Monthly instalment, total interest and payment', 'मासिक किस्त, कुल ब्याज और भुगतान'),
  icon: Icons.account_balance_outlined,
  category: ToolCategory.examCalc,
  keywords: ['emi', 'loan'],
  fields: [
    CalcField.number('p', t('Loan amount', 'ऋण राशि'), suffix: t('₹', '₹')),
    CalcField.number('r', t('Interest rate per year', 'वार्षिक ब्याज दर'), suffix: t('%', '%')),
    CalcField.number('n', t('Tenure', 'अवधि')),
    CalcField.choice('unit', t('Tenure in', 'अवधि इकाई'), [
      _ch('months', 'Months', 'महीने'),
      _ch('years', 'Years', 'वर्ष'),
    ]),
  ],
  compute: (v) {
    final p = v.number('p')!;
    var n = v.number('n')!;
    if (v.choice('unit') == 'years') n *= 12;
    if (p <= 0 || n <= 0) return _positive;
    final r = v.number('r')! / 12 / 100;
    final emi = r == 0 ? p / n : p * r * math.pow(1 + r, n) / (math.pow(1 + r, n) - 1);
    final total = emi * n;
    return _ok([
      _r('Monthly EMI', 'मासिक EMI', fmtInr(emi), big: true),
      _r('Total interest', 'कुल ब्याज', fmtInr(total - p)),
      _r('Total payment', 'कुल भुगतान', fmtInr(total)),
    ]);
  },
);

final _gst = CalcTool(
  id: 'gst',
  title: t('GST Calculator', 'GST कैलकुलेटर'),
  description: t('Add or remove GST from an amount', 'राशि में GST जोड़ें या हटाएं'),
  icon: Icons.receipt_long_outlined,
  category: ToolCategory.examCalc,
  keywords: ['gst', 'tax'],
  fields: [
    CalcField.choice('mode', t('Mode', 'तरीका'), [
      _ch('add', 'Add GST', 'GST जोड़ें'),
      _ch('remove', 'Remove GST', 'GST हटाएं'),
    ]),
    CalcField.number('amount', t('Amount', 'राशि'), suffix: t('₹', '₹')),
    CalcField.number('rate', t('GST rate', 'GST दर'), suffix: t('%', '%'), defaultValue: '18'),
  ],
  compute: (v) {
    final a = v.number('amount')!, rate = v.number('rate')!;
    if (rate < 0) return _positive;
    late double base, gst;
    if (v.choice('mode') == 'remove') {
      base = a * 100 / (100 + rate);
      gst = a - base;
    } else {
      base = a;
      gst = a * rate / 100;
    }
    return _ok([
      _r('GST amount', 'GST राशि', fmtInr(gst), big: true),
      _r('Amount without GST', 'GST रहित राशि', fmtInr(base)),
      _r('Amount with GST', 'GST सहित राशि', fmtInr(base + gst), big: true),
      _r('CGST / SGST (each)', 'CGST / SGST (प्रत्येक)', fmtInr(gst / 2)),
    ]);
  },
);

// ---- unit converter ----
class _Unit {
  final String id;
  final LText label;
  final double factor; // to the base unit of its category
  const _Unit(this.id, this.label, this.factor);
}

final Map<String, List<_Unit>> _units = {
  'length': [
    _Unit('m', t('Metre (m)', 'मीटर (m)'), 1),
    _Unit('km', t('Kilometre (km)', 'किलोमीटर (km)'), 1000),
    _Unit('cm', t('Centimetre (cm)', 'सेंटीमीटर (cm)'), 0.01),
    _Unit('mm', t('Millimetre (mm)', 'मिलीमीटर (mm)'), 0.001),
    _Unit('mile', t('Mile', 'मील'), 1609.344),
    _Unit('yard', t('Yard', 'गज'), 0.9144),
    _Unit('foot', t('Foot', 'फुट'), 0.3048),
    _Unit('inch', t('Inch', 'इंच'), 0.0254),
  ],
  'mass': [
    _Unit('kg', t('Kilogram (kg)', 'किलोग्राम (kg)'), 1),
    _Unit('g', t('Gram (g)', 'ग्राम (g)'), 0.001),
    _Unit('mg', t('Milligram (mg)', 'मिलीग्राम (mg)'), 0.000001),
    _Unit('quintal', t('Quintal', 'क्विंटल'), 100),
    _Unit('tonne', t('Tonne', 'टन'), 1000),
    _Unit('pound', t('Pound', 'पाउंड'), 0.45359237),
    _Unit('ounce', t('Ounce', 'औंस'), 0.028349523125),
  ],
  'area': [
    _Unit('sqm', t('Square metre', 'वर्ग मीटर'), 1),
    _Unit('sqkm', t('Square km', 'वर्ग किमी'), 1000000),
    _Unit('hectare', t('Hectare', 'हेक्टेयर'), 10000),
    _Unit('acre', t('Acre', 'एकड़'), 4046.8564224),
    _Unit('sqft', t('Square foot', 'वर्ग फुट'), 0.09290304),
  ],
  'volume': [
    _Unit('l', t('Litre (L)', 'लीटर (L)'), 1),
    _Unit('ml', t('Millilitre (mL)', 'मिलीलीटर (mL)'), 0.001),
    _Unit('m3', t('Cubic metre', 'घन मीटर'), 1000),
    _Unit('gallon', t('US gallon', 'यूएस गैलन'), 3.785411784),
  ],
  'temperature': [
    _Unit('c', t('Celsius (°C)', 'सेल्सियस (°C)'), 1),
    _Unit('f', t('Fahrenheit (°F)', 'फ़ारेनहाइट (°F)'), 1),
    _Unit('k', t('Kelvin (K)', 'केल्विन (K)'), 1),
  ],
};

double _toCelsius(String u, double x) => u == 'f' ? (x - 32) * 5 / 9 : (u == 'k' ? x - 273.15 : x);
double _fromCelsius(String u, double c) => u == 'f' ? c * 9 / 5 + 32 : (u == 'k' ? c + 273.15 : c);

/// Public for unit tests.
double convertUnit(String category, String from, String to, double value) {
  if (category == 'temperature') return _fromCelsius(to, _toCelsius(from, value));
  final list = _units[category]!;
  final f = list.firstWhere((u) => u.id == from).factor;
  final tt = list.firstWhere((u) => u.id == to).factor;
  return value * f / tt;
}

final _unitConverter = CalcTool(
  id: 'unit_converter',
  title: t('Unit Converter', 'यूनिट कन्वर्टर'),
  description: t('Length, weight, area, volume, temperature', 'लंबाई, वज़न, क्षेत्रफल, आयतन, तापमान'),
  icon: Icons.swap_horiz_rounded,
  category: ToolCategory.examCalc,
  keywords: ['unit', 'convert', 'km', 'kg', 'celsius', 'feet'],
  fields: [
    CalcField.choice('cat', t('Type', 'प्रकार'), [
      _ch('length', 'Length', 'लंबाई'),
      _ch('mass', 'Weight', 'वज़न'),
      _ch('area', 'Area', 'क्षेत्रफल'),
      _ch('volume', 'Volume', 'आयतन'),
      _ch('temperature', 'Temperature', 'तापमान'),
    ]),
    CalcField.number('value', t('Value', 'मान')),
    for (final e in _units.entries) ...[
      CalcField.choice('from_${e.key}', t('From', 'से'),
          [for (final u in e.value) CalcChoice(u.id, u.label)],
          showIf: _on('cat', [e.key])),
      CalcField.choice('to_${e.key}', t('To', 'में'),
          [for (final u in e.value) CalcChoice(u.id, u.label)],
          defaultChoice: e.value[1].id, showIf: _on('cat', [e.key])),
    ],
  ],
  compute: (v) {
    final cat = v.choice('cat');
    final r = convertUnit(cat, v.choice('from_$cat'), v.choice('to_$cat'), v.number('value')!);
    return _ok([_r('Converted value', 'बदला हुआ मान', fmt(r, maxDecimals: 6), big: true)]);
  },
);

// ---- dates ----
final _ageCalculator = CalcTool(
  id: 'age_calculator',
  title: t('Age Calculator', 'आयु कैलकुलेटर'),
  description: t('Exact age in years, months and days', 'वर्ष, माह और दिन में सटीक आयु'),
  icon: Icons.cake_outlined,
  category: ToolCategory.examCalc,
  keywords: ['age', 'birthday', 'dob'],
  fields: [
    CalcField.date('dob', t('Date of birth', 'जन्म तिथि')),
    CalcField.date('on', t('Age as on', 'आयु की गणना तिथि'), today: true),
  ],
  compute: (v) {
    final dob = v.date('dob')!, on = v.date('on')!;
    if (dob.isAfter(on)) return _err('Date of birth is after the "as on" date.', 'जन्म तिथि गणना तिथि के बाद है।');
    final age = ymdBetween(dob, on);
    var next = DateTime(on.year, dob.month, math.min(dob.day, daysInMonth(on.year, dob.month)));
    if (!next.isAfter(on)) {
      next = DateTime(on.year + 1, dob.month, math.min(dob.day, daysInMonth(on.year + 1, dob.month)));
    }
    return _ok([
      _ymdLine('Age', 'आयु', age, big: true),
      _r('Total days lived', 'कुल जिए दिन', '${daysBetween(dob, on)}'),
      _rl('Next birthday in', 'अगला जन्मदिन', '${daysBetween(on, next)} days', '${daysBetween(on, next)} दिन'),
    ]);
  },
);

final _dateDifference = CalcTool(
  id: 'date_difference',
  title: t('Date Difference', 'तारीखों का अंतर'),
  description: t('Days, weeks and months between two dates', 'दो तारीखों के बीच दिन, सप्ताह और माह'),
  icon: Icons.date_range_outlined,
  category: ToolCategory.examCalc,
  keywords: ['date', 'days between', 'difference'],
  fields: [
    CalcField.date('from', t('From date', 'प्रारंभ तिथि')),
    CalcField.date('to', t('To date', 'अंतिम तिथि'), today: true),
  ],
  compute: (v) {
    var a = v.date('from')!, b = v.date('to')!;
    if (b.isBefore(a)) {
      final x = a;
      a = b;
      b = x;
    }
    final days = daysBetween(a, b);
    return _ok([
      _r('Total days', 'कुल दिन', '$days', big: true),
      _rl('Weeks & days', 'सप्ताह और दिन', '${days ~/ 7} weeks ${days % 7} days', '${days ~/ 7} सप्ताह ${days % 7} दिन'),
      _ymdLine('Years, months, days', 'वर्ष, माह, दिन', ymdBetween(a, b)),
    ]);
  },
);

// ============================ EXAM & JOB TOOLS ============================

const Map<String, int> _relaxation = {
  'general': 0,
  'obc': 3,
  'scst': 5,
  'pwd_gen': 10,
  'pwd_obc': 13,
  'pwd_scst': 15,
};

final _ageEligibility = CalcTool(
  id: 'age_eligibility',
  title: t('Age Eligibility (RRB / SSC / Govt)', 'आयु पात्रता (RRB / SSC / सरकारी)'),
  description: t('Check age limit with category relaxation', 'श्रेणी छूट के साथ आयु सीमा जांचें'),
  icon: Icons.how_to_reg_outlined,
  category: ToolCategory.examJob,
  keywords: ['rrb', 'ssc', 'age', 'eligibility', 'relaxation', 'railway', 'govt job'],
  note: t(
    'Uses the common "born between" rule. Age limits and relaxation differ for every exam — enter the limits from the official notification and confirm the result there.',
    'यह सामान्य "जन्म तिथि सीमा" नियम उपयोग करता है। हर परीक्षा की आयु सीमा और छूट अलग होती है — आधिकारिक अधिसूचना से सीमाएं दर्ज करें और वहीं पुष्टि करें।',
  ),
  fields: [
    CalcField.date('dob', t('Date of birth', 'जन्म तिथि')),
    CalcField.date('cutoff', t('Age as on (cut-off date)', 'आयु की गणना तिथि (कट-ऑफ)')),
    CalcField.number('min', t('Minimum age', 'न्यूनतम आयु'), integer: true),
    CalcField.number('max', t('Maximum age', 'अधिकतम आयु'), integer: true),
    CalcField.choice('cat', t('Category (standard central govt relaxation)', 'श्रेणी (केंद्र सरकार की मानक छूट)'), [
      _ch('general', 'General / EWS (0)', 'सामान्य / EWS (0)'),
      _ch('obc', 'OBC (+3)', 'OBC (+3)'),
      _ch('scst', 'SC / ST (+5)', 'SC / ST (+5)'),
      _ch('pwd_gen', 'PwBD General (+10)', 'दिव्यांग सामान्य (+10)'),
      _ch('pwd_obc', 'PwBD OBC (+13)', 'दिव्यांग OBC (+13)'),
      _ch('pwd_scst', 'PwBD SC/ST (+15)', 'दिव्यांग SC/ST (+15)'),
    ]),
    CalcField.number('extra', t('Extra relaxation, years (optional)', 'अतिरिक्त छूट, वर्ष (वैकल्पिक)'), integer: true, optional: true),
  ],
  compute: (v) {
    final dob = v.date('dob')!, cutoff = v.date('cutoff')!;
    final minAge = v.integer('min')!, maxAge = v.integer('max')!;
    if (minAge < 0 || maxAge < minAge || maxAge > 80) {
      return _err('Check the minimum and maximum age.', 'न्यूनतम और अधिकतम आयु जांचें।');
    }
    final relax = (_relaxation[v.choice('cat')] ?? 0) + (v.integer('extra') ?? 0);
    final effectiveMax = maxAge + relax;
    final earliest = addDays(subtractYears(cutoff, effectiveMax), 1);
    final latest = subtractYears(cutoff, minAge);
    final ok = !dob.isBefore(earliest) && !dob.isAfter(latest);
    final age = dob.isAfter(cutoff) ? null : ymdBetween(dob, cutoff);
    return _ok([
      _rl(
        'Result',
        'परिणाम',
        ok ? 'Eligible by age' : 'Not eligible by age',
        ok ? 'आयु के अनुसार पात्र' : 'आयु के अनुसार अपात्र',
        big: true,
      ),
      if (age != null) _ymdLine('Age on cut-off', 'कट-ऑफ पर आयु', age),
      _rl('Upper age limit (with relaxation)', 'ऊपरी आयु सीमा (छूट सहित)', '$effectiveMax years', '$effectiveMax वर्ष'),
      _r('Must be born between', 'जन्म तिथि इनके बीच होनी चाहिए', '${fmtDate(earliest)} – ${fmtDate(latest)}'),
    ]);
  },
);

/// All calculator tools, in the order they appear.
final List<CalcTool> allCalcTools = [
  _percentage,
  _average,
  _ratio,
  _profitLoss,
  _simpleInterest,
  _compoundInterest,
  _timeWork,
  _speedDistance,
  _hcfLcm,
  _fraction,
  _simplification,
  _marksPercentage,
  _cgpa,
  _examScore,
  _rankPercentile,
  _studyTime,
  _emi,
  _gst,
  _unitConverter,
  _ageCalculator,
  _dateDifference,
  _ageEligibility,
];

CalcTool? calcToolById(String id) {
  for (final tool in allCalcTools) {
    if (tool.id == id) return tool;
  }
  return null;
}
