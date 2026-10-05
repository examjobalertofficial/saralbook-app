import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/calc_model.dart';
import 'package:app/core/tools/calculators.dart';

/// Runs a tool and returns its result values (English) in order.
List<String> _run(
  String id,
  Map<String, String> raw, {
  Map<String, DateTime?> dates = const {},
}) {
  final tool = calcToolById(id)!;
  // fill defaults like the screen does
  final full = <String, String>{
    for (final f in tool.fields)
      if (f.defaultValue != null) f.id: f.defaultValue!,
    ...raw,
  };
  final out = tool.run(CalcValues(full, dates));
  expect(out, isNotNull, reason: 'inputs not ready for $id');
  expect(out!.error, isNull, reason: out.error?.of('en'));
  return out.lines.map((l) => l.valueFor('en')).toList();
}

String _error(String id, Map<String, String> raw, {Map<String, DateTime?> dates = const {}}) {
  final tool = calcToolById(id)!;
  final full = <String, String>{
    for (final f in tool.fields)
      if (f.defaultValue != null) f.id: f.defaultValue!,
    ...raw,
  };
  final out = tool.run(CalcValues(full, dates))!;
  expect(out.error, isNotNull);
  return out.error!.of('en');
}

void main() {
  test('catalog: unique ids, every field has both languages', () {
    final ids = allCalcTools.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final tool in allCalcTools) {
      expect(tool.title.of('hi'), isNot(''), reason: tool.id);
      expect(tool.description.of('hi'), isNot(''), reason: tool.id);
      for (final f in tool.fields) {
        expect(f.label.of('hi'), isNot(''), reason: '${tool.id}.${f.id}');
        for (final c in f.choices) {
          expect(c.label.of('hi'), isNot(''), reason: '${tool.id}.${f.id}.${c.id}');
        }
      }
    }
  });

  test('missing input returns null (screen shows a hint)', () {
    expect(calcToolById('emi')!.run(const CalcValues({'p': '1000'})), isNull);
  });

  test('percentage', () {
    expect(_run('percentage', {'mode': 'of', 'pct': '20', 'base': '150'}), ['30']);
    expect(_run('percentage', {'mode': 'what', 'part': '30', 'whole': '150'}), ['20%']);
    expect(_run('percentage', {'mode': 'change', 'from': '80', 'to': '100'}), ['25%']);
    expect(_error('percentage', {'mode': 'what', 'part': '1', 'whole': '0'}), isNotEmpty);
  });

  test('average', () {
    expect(_run('average', {'nums': '10, 20 30'}).first, '20');
    expect(calcToolById('average')!.run(const CalcValues({'nums': '10, abc'})), isNull);
  });

  test('profit and loss', () {
    expect(_run('profit_loss', {'mode': 'amounts', 'cp': '100', 'sp': '120'}), ['20', '20%']);
    expect(_run('profit_loss', {'mode': 'amounts', 'cp': '100', 'sp': '80'}), ['20', '20%']);
    expect(_run('profit_loss', {'mode': 'cp_pct', 'cp': '200', 'pct': '10'}), ['220']);
    expect(_run('profit_loss', {'mode': 'sp_pct', 'sp': '110', 'pct': '10'}), ['100']);
  });

  test('interest', () {
    expect(_run('simple_interest', {'p': '1000', 'r': '10', 't': '2'}), ['₹200.00', '₹1,200.00']);
    expect(_run('compound_interest', {'p': '1000', 'r': '10', 't': '2', 'n': '1'}),
        ['₹210.00', '₹1,210.00']);
  });

  test('time and work, speed distance time', () {
    expect(_run('time_work', {'a': '10', 'b': '15'}).first, '6 days');
    expect(_run('time_work', {'a': '10', 'b': '15', 'c': '30'}).first, '5 days');
    expect(_run('speed_distance_time', {'solve': 'speed', 'distance': '120', 'time': '2'}).first, '60 km/h');
    expect(_run('speed_distance_time', {'solve': 'distance', 'speed': '60', 'time': '2.5'}).first, '150 km');
    expect(_run('speed_distance_time', {'solve': 'time', 'speed': '40', 'distance': '100'})[1], '2 h 30 min');
  });

  test('hcf lcm', () {
    expect(_run('hcf_lcm', {'nums': '12 18'}), ['6', '36']);
    expect(_run('hcf_lcm', {'nums': '4,6,8'}), ['2', '24']);
    expect(calcToolById('hcf_lcm')!.run(const CalcValues({'nums': '4, 2.5'})), isNull);
  });

  test('fraction', () {
    final base = {'n1': '1', 'd1': '2', 'n2': '1', 'd2': '3'};
    expect(_run('fraction', {...base, 'op': '+'}).first, '5/6');
    expect(_run('fraction', {...base, 'op': '-'}).first, '1/6');
    expect(_run('fraction', {...base, 'op': '*'}).first, '1/6');
    expect(_run('fraction', {...base, 'op': '/'}).first, '3/2');
    expect(_run('fraction', {...base, 'op': '/'}).last, '1 1/2');
    expect(_error('fraction', {...base, 'op': '/', 'n2': '0'}), isNotEmpty);
  });

  test('simplification', () {
    expect(_run('simplification', {'expr': '(12+8)×3÷4'}), ['15']);
    expect(_error('simplification', {'expr': '5/0'}), isNotEmpty);
  });

  test('marks, cgpa, exam score, rank', () {
    expect(_run('marks_percentage', {'got': '450', 'total': '500'}), ['90%']);
    expect(_error('marks_percentage', {'got': '501', 'total': '500'}), isNotEmpty);
    expect(_run('cgpa', {'mode': 'c2p', 'cgpa': '8'}), ['76%']);
    expect(_run('cgpa', {'mode': 'p2c', 'pct': '95'}), ['10']);
    expect(
      _run('exam_score', {'total': '100', 'correct': '60', 'wrong': '20'}).first,
      '55 / 100',
    );
    expect(_error('exam_score', {'total': '10', 'correct': '8', 'wrong': '5'}), isNotEmpty);
    expect(_run('rank_percentile', {'mode': 'p', 'total': '1000', 'rank': '100'}), ['90']);
    expect(_run('rank_percentile', {'mode': 'r', 'total': '1000', 'pct': '90'}), ['100']);
  });

  test('emi and gst', () {
    expect(_run('emi', {'p': '100000', 'r': '10', 'n': '12', 'unit': 'months'}).first, '₹8,791.59');
    expect(_run('emi', {'p': '120000', 'r': '0', 'n': '1', 'unit': 'years'}).first, '₹10,000.00');
    expect(_run('gst', {'mode': 'add', 'amount': '1000'}), ['₹180.00', '₹1,000.00', '₹1,180.00', '₹90.00']);
    expect(_run('gst', {'mode': 'remove', 'amount': '1180'})[1], '₹1,000.00');
  });

  test('unit converter', () {
    expect(convertUnit('length', 'km', 'm', 1), 1000);
    expect(convertUnit('length', 'mile', 'km', 1), closeTo(1.609344, 1e-9));
    expect(convertUnit('temperature', 'c', 'f', 100), 212);
    expect(convertUnit('temperature', 'k', 'c', 273.15), closeTo(0, 1e-9));
    expect(convertUnit('mass', 'quintal', 'kg', 2), 200);
    expect(
      _run('unit_converter', {'cat': 'length', 'value': '5', 'from_length': 'km', 'to_length': 'm'}),
      ['5000'],
    );
  });

  test('age calculator and date difference', () {
    final out = _run(
      'age_calculator',
      {},
      dates: {'dob': DateTime(1995, 5, 15), 'on': DateTime(2026, 10, 2)},
    );
    expect(out.first, '31 years 4 months 17 days');
    expect(out[1], '11463');

    final d = _run('date_difference', {}, dates: {
      'from': DateTime(2026, 1, 1),
      'to': DateTime(2026, 1, 31),
    });
    expect(d.first, '30');
    expect(d[1], '4 weeks 2 days');

    expect(
      _error('age_calculator', {}, dates: {'dob': DateTime(2030, 1, 1), 'on': DateTime(2026, 1, 1)}),
      isNotEmpty,
    );
  });

  test('age eligibility uses the born-between rule with relaxation', () {
    String result(DateTime dob, {String cat = 'general', String extra = ''}) => _run(
          'age_eligibility',
          {'min': '18', 'max': '32', 'cat': cat, 'extra': extra},
          dates: {'dob': dob, 'cutoff': DateTime(2026, 1, 1)},
        ).first;

    expect(result(DateTime(1994, 1, 2)), 'Eligible by age');
    expect(result(DateTime(1994, 1, 1)), 'Not eligible by age');
    expect(result(DateTime(2008, 1, 1)), 'Eligible by age');
    expect(result(DateTime(2008, 1, 2)), 'Not eligible by age');
    // OBC +3: born on/after 02-01-1991
    expect(result(DateTime(1991, 1, 2), cat: 'obc'), 'Eligible by age');
    expect(result(DateTime(1991, 1, 1), cat: 'obc'), 'Not eligible by age');
    // extra relaxation adds on top: 32 + 3 + 2 = 37 -> born on/after 02-01-1987
    expect(result(DateTime(1987, 1, 2), cat: 'obc', extra: '2'), 'Eligible by age');
    expect(result(DateTime(1987, 1, 1), cat: 'obc', extra: '2'), 'Not eligible by age');
  });

  test('study time counts days from today', () {
    final exam = DateTime.now().add(const Duration(days: 10));
    final out = _run('study_time', {'hours': '6', 'subjects': '4'}, dates: {'exam': exam});
    expect(out[0], '10');
    expect(out[1], '60');
    expect(out[2], '15');
  });
}
