import 'package:flutter/widgets.dart';

import '../l10n/ltext.dart';

enum ToolCategory { examCalc, files, student, examJob }

enum FieldKind { number, text, list, choice, date }

/// Show a field only when another (choice) field has one of these values.
class ShowIf {
  final String field;
  final List<String> values;
  const ShowIf(this.field, this.values);
}

class CalcChoice {
  final String id;
  final LText label;
  const CalcChoice(this.id, this.label);
}

class CalcField {
  final String id;
  final FieldKind kind;
  final LText label;
  final bool optional;
  final bool integerOnly;
  final String? defaultValue;
  final bool defaultToday;
  final LText? suffix;
  final List<CalcChoice> choices;
  final ShowIf? showIf;

  const CalcField._(
    this.id,
    this.kind,
    this.label, {
    this.optional = false,
    this.integerOnly = false,
    this.defaultValue,
    this.defaultToday = false,
    this.suffix,
    this.choices = const [],
    this.showIf,
  });

  factory CalcField.number(
    String id,
    LText label, {
    bool optional = false,
    bool integer = false,
    String? defaultValue,
    LText? suffix,
    ShowIf? showIf,
  }) =>
      CalcField._(id, FieldKind.number, label,
          optional: optional,
          integerOnly: integer,
          defaultValue: defaultValue,
          suffix: suffix,
          showIf: showIf);

  factory CalcField.text(String id, LText label, {ShowIf? showIf}) =>
      CalcField._(id, FieldKind.text, label, showIf: showIf);

  /// Several numbers separated by commas/spaces/new lines.
  factory CalcField.list(String id, LText label, {bool integer = false}) =>
      CalcField._(id, FieldKind.list, label, integerOnly: integer);

  factory CalcField.choice(
    String id,
    LText label,
    List<CalcChoice> choices, {
    String? defaultChoice,
    ShowIf? showIf,
  }) =>
      CalcField._(id, FieldKind.choice, label,
          choices: choices,
          defaultValue: defaultChoice ?? choices.first.id,
          showIf: showIf);

  factory CalcField.date(
    String id,
    LText label, {
    bool optional = false,
    bool today = false,
    ShowIf? showIf,
  }) =>
      CalcField._(id, FieldKind.date, label,
          optional: optional, defaultToday: today, showIf: showIf);
}

class ResultLine {
  final LText label;
  final String value;

  /// Use when the value contains words (e.g. "5 days") that need translating.
  final LText? valueText;
  final bool highlight;
  const ResultLine(this.label, this.value, {this.highlight = false, this.valueText});

  String valueFor(String languageCode) => valueText?.of(languageCode) ?? value;
}

class CalcOutput {
  final List<ResultLine> lines;
  final LText? error;
  final List<LText> notes;
  const CalcOutput.ok(this.lines, {this.notes = const []}) : error = null;
  const CalcOutput.error(LText this.error)
      : lines = const [],
        notes = const [];
}

/// What the user typed. Built by the screen, read by compute functions.
class CalcValues {
  final Map<String, String> raw;
  final Map<String, DateTime?> dates;
  const CalcValues(this.raw, [this.dates = const {}]);

  String choice(String id) => raw[id] ?? '';
  String text(String id) => (raw[id] ?? '').trim();
  DateTime? date(String id) => dates[id];

  double? number(String id) {
    final s = (raw[id] ?? '').replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    return (v != null && v.isFinite) ? v : null;
  }

  int? integer(String id) {
    final v = number(id);
    if (v == null || v != v.roundToDouble() || v.abs() > 1e12) return null;
    return v.toInt();
  }

  List<double> list(String id) {
    final parts = (raw[id] ?? '').split(RegExp(r'[\s,;]+'));
    final out = <double>[];
    for (final p in parts) {
      if (p.isEmpty) continue;
      final v = double.tryParse(p);
      if (v == null || !v.isFinite) return const [];
      out.add(v);
      if (out.length > 200) break;
    }
    return out;
  }
}

typedef CalcCompute = CalcOutput Function(CalcValues v);

class CalcTool {
  final String id;
  final LText title;
  final LText description;
  final IconData icon;
  final ToolCategory category;
  final List<String> keywords;
  final List<CalcField> fields;
  final CalcCompute compute;
  final LText? note;

  const CalcTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.fields,
    required this.compute,
    this.keywords = const [],
    this.note,
  });

  bool isVisible(CalcField f, CalcValues v) {
    final s = f.showIf;
    return s == null || s.values.contains(v.choice(s.field));
  }

  /// true when every visible required field has a usable value.
  bool inputsReady(CalcValues v) {
    for (final f in fields) {
      if (!isVisible(f, v) || f.optional) continue;
      switch (f.kind) {
        case FieldKind.number:
          if (f.integerOnly ? v.integer(f.id) == null : v.number(f.id) == null) {
            return false;
          }
        case FieldKind.text:
          if (v.text(f.id).isEmpty) return false;
        case FieldKind.list:
          final l = v.list(f.id);
          if (l.isEmpty) return false;
          if (f.integerOnly && l.any((e) => e != e.roundToDouble())) return false;
        case FieldKind.date:
          if (v.date(f.id) == null) return false;
        case FieldKind.choice:
          break;
      }
    }
    return true;
  }

  /// null = not enough input yet. Never throws.
  CalcOutput? run(CalcValues v) {
    if (!inputsReady(v)) return null;
    try {
      return compute(v);
    } catch (_) {
      return CalcOutput.error(t('Could not calculate with these values.', 'इन मानों से गणना नहीं हो सकी।'));
    }
  }
}
