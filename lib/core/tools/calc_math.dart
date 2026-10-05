import 'dart:math' as math;

/// Pure maths/date helpers (no Flutter), fully unit-tested.

/// 12.5 -> "12.5", 12.0 -> "12", 0.333333 -> "0.33"
String fmt(double v, {int maxDecimals = 2}) {
  if (!v.isFinite) return '—';
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}

/// 1234567.5 -> "₹12,34,567.50" (Indian digit grouping)
String fmtInr(double v) {
  if (!v.isFinite) return '—';
  final negative = v < 0;
  final fixed = v.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    grouped = '${chunks.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$grouped.${parts[1]}';
}

int gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final r = x % y;
    x = y;
    y = r;
  }
  return x;
}

BigInt lcmBig(BigInt a, BigInt b) => (a ~/ a.gcd(b)) * b;

// ---------------- dates ----------------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

class YMD {
  final int years;
  final int months;
  final int days;
  const YMD(this.years, this.months, this.days);

  @override
  bool operator ==(Object other) =>
      other is YMD && other.years == years && other.months == months && other.days == days;

  @override
  int get hashCode => Object.hash(years, months, days);

  @override
  String toString() => '${years}y ${months}m ${days}d';
}

/// Calendar difference (like a birthday calculator). [from] must be <= [to].
/// Counts whole months from [from] (day clamped to month length), then days.
YMD ymdBetween(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  DateTime anchor(int months) {
    final total = a.month - 1 + months;
    final y = a.year + total ~/ 12;
    final m = total % 12 + 1;
    return DateTime(y, m, math.min(a.day, daysInMonth(y, m)));
  }

  var months = (b.year - a.year) * 12 + (b.month - a.month);
  if (months < 0) return const YMD(0, 0, 0);
  if (anchor(months).isAfter(b)) months -= 1;
  if (months < 0) return YMD(0, 0, daysBetween(a, b));
  return YMD(months ~/ 12, months % 12, daysBetween(anchor(months), b));
}

int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Same date [years] earlier; 29 Feb becomes 28 Feb in non-leap years.
DateTime subtractYears(DateTime d, int years) {
  final y = d.year - years;
  final day = math.min(d.day, daysInMonth(y, d.month));
  return DateTime(y, d.month, day);
}

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ---------------- expression evaluator ----------------

/// Evaluates things like `2+3*4`, `(2+3)^2`, `10/4`, `2(3+4)`, `12×3÷4`.
/// Returns null for anything invalid (never throws).
double? evaluateExpression(String source) {
  if (source.length > 200) return null;
  final src = source
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(RegExp(r'[\s,]'), '');
  if (src.isEmpty) return null;
  final p = _Parser(src);
  try {
    final v = p.parse();
    return v.isFinite ? v : null;
  } catch (_) {
    return null;
  }
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;
  int depth = 0;

  double parse() {
    final v = _expr();
    if (i != s.length) throw const FormatException('extra');
    return v;
  }

  bool _peek(String c) => i < s.length && s[i] == c;

  double _expr() {
    var v = _term();
    while (_peek('+') || _peek('-')) {
      final op = s[i++];
      final r = _term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double _term() {
    var v = _power();
    while (_peek('*') || _peek('/') || _peek('(')) {
      if (_peek('(')) {
        v *= _power(); // implicit multiplication: 2(3+4)
      } else {
        final op = s[i++];
        final r = _power();
        if (op == '/') {
          if (r == 0) throw const FormatException('div0');
          v /= r;
        } else {
          v *= r;
        }
      }
    }
    return v;
  }

  double _power() {
    final base = _unary();
    if (_peek('^')) {
      i++;
      final exp = _power(); // right-associative
      final r = math.pow(base, exp).toDouble();
      if (!r.isFinite) throw const FormatException('overflow');
      return r;
    }
    return base;
  }

  double _unary() {
    if (_peek('-')) {
      i++;
      return -_unary();
    }
    if (_peek('+')) {
      i++;
      return _unary();
    }
    return _primary();
  }

  double _primary() {
    if (++depth > 60) throw const FormatException('deep');
    try {
      if (_peek('(')) {
        i++;
        final v = _expr();
        if (!_peek(')')) throw const FormatException('paren');
        i++;
        return v;
      }
      final start = i;
      while (i < s.length && (RegExp(r'[0-9.]').hasMatch(s[i]))) {
        i++;
      }
      if (start == i) throw const FormatException('number');
      return double.parse(s.substring(start, i));
    } finally {
      depth--;
    }
  }
}
