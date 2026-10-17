import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/ltext.dart';
import '../../core/tools/sci_calc.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';

enum _Kind { digit, op, fn, clear, equals, mem, mode }

class _Key {
  final String label;
  final String? second; // label when "2nd" is on
  final String insert; // text added to the expression
  final String? secondInsert;
  final _Kind kind;
  const _Key(this.label, this.insert, this.kind, {this.second, this.secondInsert});
}

const List<List<_Key>> _rows = [
  [
    _Key('sin', 'sin(', _Kind.fn, second: 'sin⁻¹', secondInsert: 'asin('),
    _Key('cos', 'cos(', _Kind.fn, second: 'cos⁻¹', secondInsert: 'acos('),
    _Key('tan', 'tan(', _Kind.fn, second: 'tan⁻¹', secondInsert: 'atan('),
    _Key('log', 'log(', _Kind.fn, second: '10ˣ', secondInsert: '10^('),
    _Key('ln', 'ln(', _Kind.fn, second: 'eˣ', secondInsert: 'exp('),
  ],
  [
    _Key('x²', '^2', _Kind.fn, second: 'x³', secondInsert: '^3'),
    _Key('√', '√(', _Kind.fn, second: '∛', secondInsert: '∛('),
    _Key('xʸ', '^', _Kind.fn, second: 'x⁻¹', secondInsert: '^(-1)'),
    _Key('n!', '!', _Kind.fn, second: '|x|', secondInsert: 'abs('),
    _Key('π', 'π', _Kind.fn, second: 'e', secondInsert: 'e'),
  ],
  [
    _Key('MC', 'MC', _Kind.mem),
    _Key('MR', 'MR', _Kind.mem),
    _Key('M+', 'M+', _Kind.mem),
    _Key('M−', 'M-', _Kind.mem),
    _Key('MS', 'MS', _Kind.mem),
  ],
  [
    _Key('AC', 'AC', _Kind.clear),
    _Key('⌫', 'BACK', _Kind.clear),
    _Key('(', '(', _Kind.fn),
    _Key(')', ')', _Kind.fn),
    _Key('÷', '÷', _Kind.op),
  ],
  [
    _Key('7', '7', _Kind.digit),
    _Key('8', '8', _Kind.digit),
    _Key('9', '9', _Kind.digit),
    _Key('%', '%', _Kind.op),
    _Key('×', '×', _Kind.op),
  ],
  [
    _Key('4', '4', _Kind.digit),
    _Key('5', '5', _Kind.digit),
    _Key('6', '6', _Kind.digit),
    _Key('EXP', '×10^', _Kind.op),
    _Key('−', '-', _Kind.op),
  ],
  [
    _Key('1', '1', _Kind.digit),
    _Key('2', '2', _Kind.digit),
    _Key('3', '3', _Kind.digit),
    _Key('Ans', 'Ans', _Kind.fn),
    _Key('+', '+', _Kind.op),
  ],
  [
    _Key('0', '0', _Kind.digit),
    _Key('.', '.', _Kind.digit),
    _Key('(−)', '(-', _Kind.fn),
    _Key('2nd', '2ND', _Kind.mode),
    _Key('=', '=', _Kind.equals),
  ],
];

class _HistoryItem {
  final String expression;
  final String result;
  const _HistoryItem(this.expression, this.result);
}

/// Scientific calculator: trig (degrees / radians), logs, powers, roots,
/// factorial, percent, memory, answer recall and a history list. Works offline.
class ScientificCalculatorScreen extends StatefulWidget {
  const ScientificCalculatorScreen({super.key});

  @override
  State<ScientificCalculatorScreen> createState() => _ScientificCalculatorScreenState();
}

class _ScientificCalculatorScreenState extends State<ScientificCalculatorScreen> {
  String _expr = '';
  double _ans = 0;
  double _memory = 0;
  bool _hasMemory = false;
  bool _degrees = true;
  bool _second = false;
  bool _justEvaluated = false;
  String? _error;
  final List<_HistoryItem> _history = [];

  /// The value being shown: the expression's live result, or null.
  double? get _live {
    if (_expr.isEmpty) return null;
    try {
      return SciCalc.evaluate(_expr, degrees: _degrees, ans: _ans);
    } catch (_) {
      return null;
    }
  }

  void _press(_Key k) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (k.kind) {
        case _Kind.mode:
          _second = !_second;
          return;
        case _Kind.clear:
          _error = null;
          if (k.insert == 'AC') {
            _expr = '';
            _justEvaluated = false;
          } else if (_expr.isNotEmpty) {
            _expr = _expr.substring(0, _expr.length - 1);
          }
          return;
        case _Kind.equals:
          _equals();
          return;
        case _Kind.mem:
          _memoryKey(k.insert);
          return;
        case _Kind.digit:
        case _Kind.op:
        case _Kind.fn:
          break;
      }
      final text = _second && k.secondInsert != null ? k.secondInsert! : k.insert;
      final startsNew = k.kind == _Kind.digit ||
          (k.kind == _Kind.fn && !text.startsWith('^') && text != '!' && text != ')');
      if (_justEvaluated && startsNew) _expr = '';
      _justEvaluated = false;
      _error = null;
      _expr += text;
      if (_second) _second = false;
    });
  }

  void _equals() {
    if (_expr.isEmpty) return;
    try {
      final v = SciCalc.evaluate(_expr, degrees: _degrees, ans: _ans);
      final shown = SciCalc.format(v);
      _history.insert(0, _HistoryItem(_expr, shown));
      if (_history.length > 30) _history.removeLast();
      _ans = double.parse(shown.replaceAll('E', 'e'));
      _expr = shown;
      _justEvaluated = true;
      _error = null;
    } on SciCalcException catch (e) {
      _error = e.message;
    }
  }

  void _memoryKey(String op) {
    final v = _live ?? (_justEvaluated ? _ans : null);
    switch (op) {
      case 'MC':
        _memory = 0;
        _hasMemory = false;
      case 'MR':
        if (_justEvaluated) {
          _expr = '';
          _justEvaluated = false;
        }
        _expr += SciCalc.format(_memory);
      case 'MS':
        if (v != null) {
          _memory = v;
          _hasMemory = true;
        }
      case 'M+':
        if (v != null) {
          _memory += v;
          _hasMemory = true;
        }
      case 'M-':
        if (v != null) {
          _memory -= v;
          _hasMemory = true;
        }
    }
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (_history.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(child: Text(tr(context, t('No calculations yet', 'अभी कोई गणना नहीं')))),
          );
        }
        return ListView(
          shrinkWrap: true,
          children: [
            for (final h in _history)
              ListTile(
                title: Text(h.expression, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('= ${h.result}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                onTap: () {
                  setState(() {
                    _expr = h.result;
                    _justEvaluated = true;
                    _error = null;
                  });
                  Navigator.of(context).pop();
                },
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton.icon(
                onPressed: () {
                  setState(_history.clear);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(tr(context, t('Clear history', 'हिस्ट्री साफ़ करें'))),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _keyColor(_Kind kind, ColorScheme scheme, bool dark) {
    switch (kind) {
      case _Kind.digit:
        return scheme.surfaceContainerHighest;
      case _Kind.op:
        return Color.alphaBlend(const Color(0xFFE8590C).withAlpha(dark ? 70 : 45), scheme.surface);
      case _Kind.fn:
        return Color.alphaBlend(const Color(0xFF7048E8).withAlpha(dark ? 70 : 38), scheme.surface);
      case _Kind.mem:
        return Color.alphaBlend(const Color(0xFF0C8599).withAlpha(dark ? 70 : 38), scheme.surface);
      case _Kind.clear:
        return Color.alphaBlend(const Color(0xFFC92A2A).withAlpha(dark ? 80 : 45), scheme.surface);
      case _Kind.mode:
        return _second ? const Color(0xFF7048E8) : scheme.secondaryContainer;
      case _Kind.equals:
        return const Color(0xFF2F9E44);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final live = _live;
    final preview = _error ?? (live != null && !_justEvaluated ? '= ${SciCalc.format(live)}' : '');
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, t('Scientific Calculator', 'साइंटिफिक कैलकुलेटर')),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: tr(context, t('History', 'हिस्ट्री')),
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistory,
          ),
        ],
      ),
      body: PageBody(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              GestureDetector(
                onLongPress: () {
                  final value = _expr.isEmpty ? '' : _expr;
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(context, t('Copied', 'कॉपी हो गया')))),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: dark
                          ? const [Color(0xFF1B2A4A), Color(0xFF2B1F4D)]
                          : const [Color(0xFF1E5AA8), Color(0xFF7048E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          _Chip(_degrees ? 'DEG' : 'RAD', onTap: () => setState(() => _degrees = !_degrees)),
                          const SizedBox(width: 8),
                          if (_hasMemory) const _Chip('M'),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _expr.isEmpty ? '0' : _expr.replaceAll('*', '×').replaceAll('/', '÷'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _expr.length > 14 ? 24 : 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 22,
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _error != null ? const Color(0xFFFFC9C9) : Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    for (final row in _rows)
                      Expanded(
                        child: Row(
                          children: [
                            for (final k in row)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _KeyButton(
                                    label: _second && k.second != null ? k.second! : k.label,
                                    color: _keyColor(k.kind, scheme, dark),
                                    foreground: k.kind == _Kind.equals || (k.kind == _Kind.mode && _second)
                                        ? Colors.white
                                        : scheme.onSurface,
                                    big: k.kind == _Kind.digit || k.kind == _Kind.equals || k.kind == _Kind.op,
                                    onTap: () => _press(k),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _Chip(this.text, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;
  final bool big;
  final VoidCallback onTap;
  const _KeyButton({
    required this.label,
    required this.color,
    required this.foreground,
    required this.big,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: big ? 22 : 16,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
