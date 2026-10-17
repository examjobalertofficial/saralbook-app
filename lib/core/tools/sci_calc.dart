import 'dart:math' as math;

class SciCalcException implements Exception {
  final String message;
  const SciCalcException(this.message);
  @override
  String toString() => message;
}

enum _T { num, id, op }

class _Tok {
  final _T type;
  final String text;
  final double value;
  const _Tok(this.type, this.text, [this.value = 0]);
}

/// A small, safe expression calculator for the Scientific Calculator tool.
/// It reads the text itself (no code is ever run), so nothing typed can do harm.
///
/// Supports + - × ÷, powers (^, right to left), brackets (missing closing
/// brackets are added), percent (50% = 0.5), factorial (5!), √ ∛, sin cos tan
/// asin acos atan (degrees or radians), log (base 10), ln, exp, abs, constants
/// pi and e, `Ans` (the last answer) and "2π", "2(3+1)" style short multiplication.
class SciCalc {
  static double evaluate(String text, {bool degrees = true, double ans = 0}) {
    final p = _Parser(_tokenize(text), degrees, ans);
    final v = p.parseAll();
    if (v.isNaN || v.isInfinite) throw const SciCalcException('Math error');
    return v;
  }

  /// Shows a number the way a calculator does: 12 significant digits, no
  /// trailing zeros, exponent form for very large or very small values.
  static String format(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    final r = double.parse(v.toStringAsPrecision(12));
    if (r == 0) return '0';
    final abs = r.abs();
    if (abs >= 1e15 || abs < 1e-9) {
      var s = r.toStringAsExponential(9);
      final parts = s.split('e');
      var m = parts[0];
      if (m.contains('.')) {
        m = m.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      }
      final exp = int.parse(parts[1]);
      s = '${m}E${exp >= 0 ? '' : '-'}${exp.abs()}';
      return s;
    }
    var s = r.toString();
    if (s.contains('e')) s = r.toStringAsFixed(12).replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  static List<_Tok> _tokenize(String input) {
    final s = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('π', 'pi')
        .replaceAll('√', 'sqrt')
        .replaceAll('∛', 'cbrt');
    final out = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ') {
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(c)) {
        var j = i;
        while (j < s.length && RegExp(r'[0-9.]').hasMatch(s[j])) {
          j++;
        }
        final raw = s.substring(i, j);
        final v = double.tryParse(raw.startsWith('.') ? '0$raw' : raw);
        if (v == null) throw const SciCalcException('Bad number');
        out.add(_Tok(_T.num, raw, v));
        i = j;
      } else if (RegExp(r'[a-zA-Z]').hasMatch(c)) {
        var j = i;
        while (j < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[j])) {
          j++;
        }
        out.add(_Tok(_T.id, s.substring(i, j).toLowerCase()));
        i = j;
      } else if ('+-*/^()%!'.contains(c)) {
        out.add(_Tok(_T.op, c));
        i++;
      } else {
        throw SciCalcException('Unknown symbol $c');
      }
    }
    return out;
  }
}

const Set<String> _functions = {
  'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'cbrt', 'log', 'ln', 'exp', 'abs', 'fact',
};

class _Parser {
  _Parser(this._t, this._deg, this._ans);

  final List<_Tok> _t;
  final bool _deg;
  final double _ans;
  int _i = 0;

  _Tok? get _peek => _i < _t.length ? _t[_i] : null;

  bool _isOp(String op) => _peek != null && _peek!.type == _T.op && _peek!.text == op;

  double parseAll() {
    if (_t.isEmpty) throw const SciCalcException('Empty');
    final v = _expr();
    if (_peek != null) throw const SciCalcException('Unexpected symbol');
    return v;
  }

  double _expr() {
    var v = _term();
    while (_isOp('+') || _isOp('-')) {
      final plus = _t[_i++].text == '+';
      final r = _term();
      v = plus ? v + r : v - r;
    }
    return v;
  }

  bool get _startsOperand {
    final p = _peek;
    if (p == null) return false;
    return p.type == _T.num || p.type == _T.id || (p.type == _T.op && p.text == '(');
  }

  double _term() {
    var v = _unary();
    while (true) {
      if (_isOp('*') || _isOp('/')) {
        final mul = _t[_i++].text == '*';
        final r = _unary();
        if (!mul && r == 0) throw const SciCalcException('Cannot divide by zero');
        v = mul ? v * r : v / r;
      } else if (_startsOperand) {
        v *= _unary(); // 2π, 2(3+1)
      } else {
        return v;
      }
    }
  }

  double _unary() {
    if (_isOp('-')) {
      _i++;
      return -_unary();
    }
    if (_isOp('+')) {
      _i++;
      return _unary();
    }
    return _power();
  }

  double _power() {
    final base = _postfix();
    if (_isOp('^')) {
      _i++;
      final exp = _unary(); // right to left, allows 2^-3
      if (base == 0 && exp < 0) throw const SciCalcException('Cannot divide by zero');
      final r = math.pow(base, exp).toDouble();
      if (r.isNaN) throw const SciCalcException('Math error');
      return r;
    }
    return base;
  }

  double _postfix() {
    var v = _primary();
    while (true) {
      if (_isOp('!')) {
        _i++;
        v = _factorial(v);
      } else if (_isOp('%')) {
        _i++;
        v = v / 100;
      } else {
        return v;
      }
    }
  }

  double _factorial(double n) {
    if (n < 0 || n != n.roundToDouble() || n > 170) throw const SciCalcException('Factorial needs 0 to 170');
    var r = 1.0;
    for (var k = 2; k <= n; k++) {
      r *= k;
    }
    return r;
  }

  double _primary() {
    final tok = _peek;
    if (tok == null) throw const SciCalcException('Incomplete');
    if (tok.type == _T.num) {
      _i++;
      return tok.value;
    }
    if (tok.type == _T.op && tok.text == '(') {
      _i++;
      final v = _expr();
      if (_isOp(')')) _i++; // a missing closing bracket is added
      return v;
    }
    if (tok.type == _T.id) {
      _i++;
      switch (tok.text) {
        case 'pi':
          return math.pi;
        case 'e':
          return math.e;
        case 'ans':
          return _ans;
      }
      if (_functions.contains(tok.text)) {
        double arg;
        if (_isOp('(')) {
          _i++;
          arg = _expr();
          if (_isOp(')')) _i++;
        } else {
          arg = _unary();
        }
        return _apply(tok.text, arg);
      }
      throw SciCalcException('Unknown name ${tok.text}');
    }
    throw const SciCalcException('Unexpected symbol');
  }

  /// sin(180°) is 1.2e-16 in floating point; show it as the 0 it really is.
  double _snap(double v) => v.abs() < 1e-12 ? 0 : v;

  double _toRad(double x) => _deg ? x * math.pi / 180 : x;
  double _fromRad(double x) => _deg ? x * 180 / math.pi : x;

  double _apply(String f, double x) {
    switch (f) {
      case 'sin':
        return _snap(math.sin(_toRad(x)));
      case 'cos':
        return _snap(math.cos(_toRad(x)));
      case 'tan':
        final r = _toRad(x);
        if (math.cos(r).abs() < 1e-12) throw const SciCalcException('tan is not defined here');
        return math.tan(r);
      case 'asin':
        if (x < -1 || x > 1) throw const SciCalcException('Needs a value from -1 to 1');
        return _fromRad(math.asin(x));
      case 'acos':
        if (x < -1 || x > 1) throw const SciCalcException('Needs a value from -1 to 1');
        return _fromRad(math.acos(x));
      case 'atan':
        return _fromRad(math.atan(x));
      case 'sqrt':
        if (x < 0) throw const SciCalcException('Square root of a negative number');
        return math.sqrt(x);
      case 'cbrt':
        final r = math.pow(x.abs(), 1 / 3).toDouble();
        final rounded = r.roundToDouble();
        final exact = (rounded * rounded * rounded - x.abs()).abs() < 1e-9 ? rounded : r;
        return x < 0 ? -exact : exact;
      case 'log':
        if (x <= 0) throw const SciCalcException('log needs a positive number');
        final l = math.log(x) / math.ln10;
        final rl = l.roundToDouble();
        return (l - rl).abs() < 1e-12 ? rl : l;
      case 'ln':
        if (x <= 0) throw const SciCalcException('ln needs a positive number');
        return math.log(x);
      case 'exp':
        return math.exp(x);
      case 'abs':
        return x.abs();
      case 'fact':
        return _factorial(x);
    }
    throw SciCalcException('Unknown function $f');
  }
}
